"""Server-Sent Events service for admin live dashboard.

Uses Redis pub/sub to broadcast events across multiple API instances.
"""

import asyncio
import json
import logging
from collections.abc import AsyncGenerator
from datetime import datetime, timezone

import redis.asyncio as aioredis
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.db.session import async_session_maker
from app.models.subscription import Subscription
from app.models.tenant import Tenant
from app.models.user import User

logger = logging.getLogger(__name__)

ADMIN_EVENTS_CHANNEL = "mg:admin:events"


def _get_redis() -> aioredis.Redis:
    """Create a Redis client for pub/sub."""
    return aioredis.from_url(str(settings.redis_url), decode_responses=True)


async def publish_event(event_type: str, data: dict[str, str | int | bool | None]) -> None:
    """Publish an event to the admin SSE channel.

    Call this from any service to push real-time updates to connected
    admin dashboard clients.
    """
    redis = _get_redis()
    try:
        payload = json.dumps({
            "event_type": event_type,
            "data": data,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })
        await redis.publish(ADMIN_EVENTS_CHANNEL, payload)
    except Exception:
        logger.exception("Failed to publish SSE event: %s", event_type)
    finally:
        await redis.aclose()


async def _get_dashboard_stats() -> dict[str, int | float]:
    """Query current dashboard statistics."""
    async with async_session_maker() as db:
        total_users = (
            await db.execute(select(func.count(User.id)))
        ).scalar() or 0

        from datetime import date

        today = date.today()
        signups_today = (
            await db.execute(
                select(func.count(User.id)).where(
                    func.date(User.created_at) == today,
                )
            )
        ).scalar() or 0

        active_subs = (
            await db.execute(
                select(func.count(Subscription.id)).where(
                    Subscription.is_active == True,  # noqa: E712
                    Subscription.deleted_at.is_(None),
                )
            )
        ).scalar() or 0

        # MRR estimate: sum of monthly-equivalent amounts for active subs
        from sqlalchemy import case
        from decimal import Decimal

        mrr_result = await db.execute(
            select(
                func.coalesce(
                    func.sum(
                        case(
                            (Subscription.billing_cycle == "weekly", Subscription.amount * 4),
                            (Subscription.billing_cycle == "monthly", Subscription.amount),
                            (Subscription.billing_cycle == "quarterly", Subscription.amount / 3),
                            (Subscription.billing_cycle == "yearly", Subscription.amount / 12),
                            else_=Subscription.amount,
                        )
                    ),
                    Decimal("0"),
                )
            ).where(
                Subscription.is_active == True,  # noqa: E712
                Subscription.deleted_at.is_(None),
            )
        )
        mrr_estimate = float(mrr_result.scalar() or 0)

    return {
        "total_users": total_users,
        "signups_today": signups_today,
        "active_subscriptions": active_subs,
        "mrr_estimate": round(mrr_estimate, 2),
    }


async def _get_system_metrics() -> dict[str, str | int | float | bool]:
    """Query system health metrics."""
    metrics: dict[str, str | int | float | bool] = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    # Check database connectivity
    try:
        async with async_session_maker() as db:
            await db.execute(select(func.count(User.id)))
        metrics["db_status"] = "healthy"
    except Exception:
        metrics["db_status"] = "unhealthy"

    # Check Redis connectivity
    redis = _get_redis()
    try:
        await redis.ping()
        metrics["redis_status"] = "healthy"
    except Exception:
        metrics["redis_status"] = "unhealthy"
    finally:
        await redis.aclose()

    return metrics


async def dashboard_stream() -> AsyncGenerator[str, None]:
    """Async generator yielding SSE events for the admin dashboard.

    1. Sends initial stats snapshot
    2. Subscribes to Redis pub/sub for real-time events
    3. Periodically refreshes stats every 30 seconds
    """
    # Yield initial stats
    try:
        stats = await _get_dashboard_stats()
        yield f"data: {json.dumps({'event_type': 'stats', 'data': stats})}\n\n"
    except Exception:
        logger.exception("Failed to get initial dashboard stats")
        yield f"data: {json.dumps({'event_type': 'error', 'data': {'message': 'Failed to load stats'}})}\n\n"

    redis = _get_redis()
    pubsub = redis.pubsub()
    try:
        await pubsub.subscribe(ADMIN_EVENTS_CHANNEL)

        last_refresh = asyncio.get_event_loop().time()
        refresh_interval = 30.0  # seconds

        while True:
            # Check for pub/sub messages (non-blocking with short timeout)
            message = await pubsub.get_message(
                ignore_subscribe_messages=True, timeout=1.0,
            )
            if message and message["type"] == "message":
                yield f"data: {message['data']}\n\n"

            # Periodic stats refresh
            now = asyncio.get_event_loop().time()
            if now - last_refresh >= refresh_interval:
                try:
                    stats = await _get_dashboard_stats()
                    yield f"data: {json.dumps({'event_type': 'stats', 'data': stats})}\n\n"
                except Exception:
                    logger.exception("Failed to refresh dashboard stats")
                last_refresh = now

    except asyncio.CancelledError:
        pass
    except Exception:
        logger.exception("Dashboard SSE stream error")
    finally:
        await pubsub.unsubscribe(ADMIN_EVENTS_CHANNEL)
        await pubsub.aclose()
        await redis.aclose()


async def monitoring_stream() -> AsyncGenerator[str, None]:
    """Async generator yielding SSE events for system monitoring.

    Yields system health metrics every 10 seconds.
    """
    try:
        while True:
            try:
                metrics = await _get_system_metrics()
                yield f"data: {json.dumps({'event_type': 'system_health', 'data': metrics})}\n\n"
            except Exception:
                logger.exception("Failed to get system metrics")
                yield f"data: {json.dumps({'event_type': 'error', 'data': {'message': 'Metrics unavailable'}})}\n\n"

            await asyncio.sleep(10)
    except asyncio.CancelledError:
        pass
