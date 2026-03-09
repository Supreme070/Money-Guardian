"""Admin SSE (Server-Sent Events) endpoints for live dashboard updates.

Provides real-time streaming of dashboard stats and system monitoring
metrics via SSE.
"""

import logging

from fastapi import APIRouter, Depends
from starlette.responses import StreamingResponse

from app.api.v1.endpoints.admin_auth import get_current_admin
from app.models.admin_user import AdminUser
from app.services.admin_sse_service import dashboard_stream, monitoring_stream

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/dashboard")
async def sse_dashboard(
    admin: AdminUser = Depends(get_current_admin),
) -> StreamingResponse:
    """Live dashboard stream via SSE.

    Streams:
    - Initial stats snapshot (total users, signups today, active subs, MRR)
    - Real-time events from Redis pub/sub
    - Periodic stats refresh every 30 seconds
    """
    return StreamingResponse(
        dashboard_stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # Disable nginx buffering
        },
    )


@router.get("/monitoring")
async def sse_monitoring(
    admin: AdminUser = Depends(get_current_admin),
) -> StreamingResponse:
    """Live system monitoring stream via SSE.

    Streams system health metrics (DB, Redis status) every 10 seconds.
    """
    return StreamingResponse(
        monitoring_stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )
