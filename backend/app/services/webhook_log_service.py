"""Webhook event logging and dashboard service.

Logs inbound webhook events from Stripe, Plaid, and SES for the
admin webhook dashboard.
"""

import logging
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.webhook_event import WebhookEvent

logger = logging.getLogger(__name__)


async def log_webhook_event(
    db: AsyncSession,
    *,
    provider: str,
    event_type: str,
    event_id: str,
    payload_hash: str | None = None,
    status: str = "received",
    processing_time_ms: int | None = None,
    error_message: str | None = None,
) -> WebhookEvent:
    """Create a webhook event log entry."""
    event = WebhookEvent(
        provider=provider,
        event_type=event_type,
        event_id=event_id,
        payload_hash=payload_hash,
        status=status,
        processing_time_ms=processing_time_ms,
        error_message=error_message,
    )
    db.add(event)
    await db.flush()

    logger.info(
        "Webhook event logged: provider=%s type=%s event_id=%s status=%s",
        provider, event_type, event_id, status,
    )
    return event


async def list_webhook_events(
    db: AsyncSession,
    *,
    provider: str | None = None,
    event_type: str | None = None,
    status: str | None = None,
    page: int = 1,
    page_size: int = 50,
) -> tuple[list[WebhookEvent], int]:
    """List webhook events with optional filters.

    Returns (events, total_count).
    """
    query = select(WebhookEvent).order_by(WebhookEvent.created_at.desc())
    count_query = select(func.count(WebhookEvent.id))

    if provider:
        query = query.where(WebhookEvent.provider == provider)
        count_query = count_query.where(WebhookEvent.provider == provider)
    if event_type:
        query = query.where(WebhookEvent.event_type == event_type)
        count_query = count_query.where(WebhookEvent.event_type == event_type)
    if status:
        query = query.where(WebhookEvent.status == status)
        count_query = count_query.where(WebhookEvent.status == status)

    total_count = (await db.execute(count_query)).scalar() or 0

    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)

    result = await db.execute(query)
    events = list(result.scalars().all())

    return events, total_count


async def get_webhook_stats(db: AsyncSession) -> dict[str, int | float | dict[str, int]]:
    """Aggregate webhook statistics for the dashboard.

    Returns total_events, by_provider, by_status, avg_processing_time_ms.
    """
    total_events = (
        await db.execute(select(func.count(WebhookEvent.id)))
    ).scalar() or 0

    # By provider
    provider_rows = await db.execute(
        select(WebhookEvent.provider, func.count(WebhookEvent.id))
        .group_by(WebhookEvent.provider)
    )
    by_provider: dict[str, int] = {
        row[0]: row[1] for row in provider_rows.all()
    }

    # By status
    status_rows = await db.execute(
        select(WebhookEvent.status, func.count(WebhookEvent.id))
        .group_by(WebhookEvent.status)
    )
    by_status: dict[str, int] = {
        row[0]: row[1] for row in status_rows.all()
    }

    # Average processing time (only for events that have it)
    avg_result = await db.execute(
        select(func.avg(WebhookEvent.processing_time_ms)).where(
            WebhookEvent.processing_time_ms.isnot(None)
        )
    )
    avg_processing_time_ms = float(avg_result.scalar() or 0.0)

    return {
        "total_events": total_events,
        "by_provider": by_provider,
        "by_status": by_status,
        "avg_processing_time_ms": round(avg_processing_time_ms, 2),
    }


async def get_webhook_event(
    db: AsyncSession,
    event_id: UUID,
) -> WebhookEvent | None:
    """Get a single webhook event by ID."""
    result = await db.execute(
        select(WebhookEvent).where(WebhookEvent.id == event_id)
    )
    return result.scalar_one_or_none()
