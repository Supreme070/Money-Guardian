"""Money Guardian API - Main application entry point."""

import json
import logging
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from decimal import Decimal

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.logging_config import setup_logging
from app.core.rate_limit import limiter

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Sentry Error Monitoring
# ---------------------------------------------------------------------------
if settings.sentry_dsn:
    try:
        import sentry_sdk

        sentry_sdk.init(
            dsn=settings.sentry_dsn,
            environment=settings.environment,
            release=f"money-guardian-api@{settings.app_version}",
            traces_sample_rate=settings.sentry_traces_sample_rate,
            send_default_pii=False,
        )
        logger.info("Sentry initialized (environment=%s)", settings.environment)
    except ImportError:
        logger.warning("sentry-sdk not installed — error monitoring disabled")


# ---------------------------------------------------------------------------
# JSON Serialization
# ---------------------------------------------------------------------------
class DecimalEncoder(json.JSONEncoder):
    """Custom JSON encoder that converts Decimal to float."""

    def default(self, o: object) -> float | str:
        if isinstance(o, Decimal):
            return float(o)
        return super().default(o)


class CustomJSONResponse(JSONResponse):
    """Custom JSON response that handles Decimal serialization."""

    def render(self, content: object) -> bytes:
        return json.dumps(
            content,
            ensure_ascii=False,
            allow_nan=False,
            indent=None,
            separators=(",", ":"),
            cls=DecimalEncoder,
        ).encode("utf-8")


# ---------------------------------------------------------------------------
# Startup validation
# ---------------------------------------------------------------------------
def _validate_production_settings() -> None:
    """Raise on dangerous defaults in production."""
    if settings.environment == "production":
        if settings.jwt_secret_key in ("CHANGE_ME_IN_PRODUCTION", "LOCAL_DEV_ONLY__CHANGE_IN_PRODUCTION"):
            raise RuntimeError(
                "FATAL: jwt_secret_key must be changed from default in production. "
                "Set the JWT_SECRET_KEY environment variable."
            )
        if not settings.encryption_master_key:
            raise RuntimeError(
                "FATAL: ENCRYPTION_MASTER_KEY must be set in production. "
                "Generate with: python -c \"import secrets; print(secrets.token_urlsafe(32))\""
            )
        if settings.email_provider == "ses" and not settings.aws_access_key_id:
            raise RuntimeError(
                "FATAL: AWS credentials required when EMAIL_PROVIDER=ses. "
                "Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY."
            )
        if settings.cors_origins == ["*"]:
            logger.warning(
                "CORS origins set to wildcard (*) in production. "
                "Consider restricting to your frontend domains."
            )


# ---------------------------------------------------------------------------
# Lifespan
# ---------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Application lifespan handler."""
    setup_logging()
    _validate_production_settings()
    logger.info("Starting %s v%s", settings.app_name, settings.app_version)
    logger.info("Environment: %s", settings.environment)
    yield
    # Clean up Redis connection pools
    from app.core.token_blacklist import close_blacklist_pool
    from app.core.cache import close_cache_pool
    await close_blacklist_pool()
    await close_cache_pool()
    logger.info("Shutting down...")


# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------
app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="Money Guardian API - Protect your money from surprise charges",
    openapi_url=(
        f"{settings.api_v1_prefix}/openapi.json"
        if settings.environment != "production"
        else None  # Hide OpenAPI spec in production
    ),
    docs_url=(
        f"{settings.api_v1_prefix}/docs"
        if settings.environment != "production"
        else None
    ),
    redoc_url=(
        f"{settings.api_v1_prefix}/redoc"
        if settings.environment != "production"
        else None
    ),
    lifespan=lifespan,
    default_response_class=CustomJSONResponse,
)

# Rate limiting
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
    expose_headers=["X-Request-ID"],
    max_age=600,
)

# Request logging middleware (after CORS so it logs actual requests, not preflight)
from app.core.middleware import RequestLoggingMiddleware
app.add_middleware(RequestLoggingMiddleware)

# Include API router
app.include_router(api_router, prefix=settings.api_v1_prefix)


@app.get("/health")
async def health_check() -> dict[str, str]:
    """Liveness probe - returns 200 if the process is alive."""
    return {"status": "healthy", "version": settings.app_version}


@app.get("/health/ready")
async def readiness_check() -> dict[str, str]:
    """Readiness probe - checks DB and Redis connectivity."""
    from fastapi import HTTPException

    errors: list[str] = []

    # Check database
    try:
        from app.db.session import engine
        from sqlalchemy import text
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
    except Exception as e:
        errors.append(f"database: {e}")

    # Check Redis
    try:
        import redis.asyncio as aioredis
        r = aioredis.from_url(str(settings.redis_url), decode_responses=True)
        try:
            await r.ping()
        finally:
            await r.aclose()
    except Exception as e:
        errors.append(f"redis: {e}")

    if errors:
        raise HTTPException(status_code=503, detail={"status": "unhealthy", "errors": errors})

    return {"status": "ready", "version": settings.app_version}
