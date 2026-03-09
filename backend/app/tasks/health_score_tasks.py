"""Celery tasks for daily health score computation."""

import logging

from app.core.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(
    name="app.tasks.health_score_tasks.compute_daily_health_scores",
    bind=True,
    max_retries=2,
    default_retry_delay=300,
)
def compute_daily_health_scores(self) -> dict[str, int]:  # type: ignore[no-untyped-def]
    """Compute health scores for all active users.

    Scheduled daily at 3:00 AM UTC via Celery beat.
    """
    import asyncio

    async def _run() -> dict[str, int]:
        from app.db.session import async_session_maker
        from app.services.health_score_service import compute_all_scores

        async with async_session_maker() as db:
            try:
                count = await compute_all_scores(db)
                await db.commit()
                logger.info(
                    "Daily health scores computed: %d users scored", count,
                )
                return {"users_scored": count}
            except Exception:
                await db.rollback()
                logger.exception("Failed to compute daily health scores")
                raise

    try:
        return asyncio.get_event_loop().run_until_complete(_run())
    except RuntimeError:
        loop = asyncio.new_event_loop()
        try:
            return loop.run_until_complete(_run())
        finally:
            loop.close()
