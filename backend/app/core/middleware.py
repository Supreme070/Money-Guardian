"""Request logging middleware for Money Guardian.

Logs every HTTP request with structured fields:
request_id, method, path, status_code, duration_ms, user_id, tenant_id.
Adds X-Request-ID header to responses.
"""

import logging
import time
from uuid import uuid4

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

import structlog

logger = logging.getLogger(__name__)

# Paths to exclude from access logs (reduce noise)
_EXCLUDED_PATHS = frozenset({"/health", "/health/ready"})


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """ASGI middleware that logs requests and adds request_id context."""

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        request_id = str(uuid4())
        start_time = time.perf_counter()

        # Bind request_id to structlog context for all logs during this request
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(request_id=request_id)

        response = await call_next(request)

        # Add request_id to response headers
        response.headers["X-Request-ID"] = request_id

        # Skip logging for health check endpoints
        if request.url.path not in _EXCLUDED_PATHS:
            duration_ms = round((time.perf_counter() - start_time) * 1000, 2)

            # Extract user info from request state if available
            user_id = getattr(request.state, "user_id", None) if hasattr(request, "state") else None
            tenant_id = getattr(request.state, "tenant_id", None) if hasattr(request, "state") else None

            logger.info(
                "HTTP %s %s → %d (%.1fms)",
                request.method,
                request.url.path,
                response.status_code,
                duration_ms,
                extra={
                    "request_id": request_id,
                    "method": request.method,
                    "path": request.url.path,
                    "status_code": response.status_code,
                    "duration_ms": duration_ms,
                    "user_id": str(user_id) if user_id else None,
                    "tenant_id": str(tenant_id) if tenant_id else None,
                    "client_ip": request.client.host if request.client else None,
                },
            )

        return response
