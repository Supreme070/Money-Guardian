"""Money Guardian API - Main application entry point."""

import json
import logging
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from decimal import Decimal

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from app.api.v1.router import api_router
from app.core.config import settings

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Rate Limiter
# ---------------------------------------------------------------------------
limiter = Limiter(
    key_func=get_remote_address,
    default_limits=[f"{settings.rate_limit_per_minute}/minute"],
    storage_uri=str(settings.redis_url),
)


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
        if settings.jwt_secret_key == "CHANGE_ME_IN_PRODUCTION":
            raise RuntimeError(
                "FATAL: jwt_secret_key must be changed from default in production. "
                "Set the JWT_SECRET_KEY environment variable."
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
    _validate_production_settings()
    logger.info("Starting %s v%s", settings.app_name, settings.app_version)
    logger.info("Environment: %s", settings.environment)
    yield
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

# Include API router
app.include_router(api_router, prefix=settings.api_v1_prefix)


@app.get("/health")
async def health_check() -> dict[str, str]:
    """Health check endpoint."""
    return {"status": "healthy", "version": settings.app_version}
