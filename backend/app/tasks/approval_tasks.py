"""Celery tasks for approval workflow maintenance."""

import logging

from app.core.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="app.tasks.approval_tasks.expire_stale_approvals")
def expire_stale_approvals() -> dict[str, int]:
    """Find pending approvals past their expires_at and mark them expired.

    Runs every hour via Celery beat.
    """
    import asyncio
    from datetime import datetime, timezone

    from sqlalchemy import select, update

    from app.db.session import async_session_maker
    from app.models.approval_request import ApprovalRequest

    async def _expire() -> int:
        async with async_session_maker() as db:
            now = datetime.now(timezone.utc)

            # Find and update expired approvals
            stmt = (
                update(ApprovalRequest)
                .where(
                    ApprovalRequest.status == "pending",
                    ApprovalRequest.expires_at < now,
                )
                .values(status="expired")
                .returning(ApprovalRequest.id)
            )
            result = await db.execute(stmt)
            expired_ids = result.scalars().all()
            await db.commit()

            if expired_ids:
                logger.info(
                    "Expired %d stale approval requests: %s",
                    len(expired_ids),
                    [str(aid) for aid in expired_ids],
                )

            return len(expired_ids)

    loop = asyncio.new_event_loop()
    try:
        count = loop.run_until_complete(_expire())
    finally:
        loop.close()

    return {"expired_count": count}
