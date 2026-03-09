"""Celery tasks for data export operations."""

import logging
from datetime import datetime, timezone
from uuid import UUID

from app.core.celery_app import celery_app

logger = logging.getLogger(__name__)


def _get_sync_session():
    """Create a synchronous database session for Celery tasks."""
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker

    from app.core.config import settings

    sync_url = str(settings.database_url).replace(
        "postgresql+asyncpg://", "postgresql+psycopg2://",
    )
    engine = create_engine(sync_url)
    session_factory = sessionmaker(bind=engine)
    return session_factory()


@celery_app.task(
    name="app.tasks.export_tasks.export_data",
    bind=True,
    max_retries=1,
)
def export_data(
    self,
    operation_id: str,
    export_type: str,
    filters: dict[str, str] | None = None,
) -> dict[str, str]:
    """Execute a data export and store the result path in the operation.

    Uses asyncio.run() to call async export service methods from within
    the synchronous Celery worker context.
    """
    import asyncio

    from app.models.bulk_operation import BulkOperation
    from app.services.admin_export_service import (
        export_audit_log_csv,
        export_subscriptions_csv,
        export_users_csv,
    )

    db_sync = _get_sync_session()
    try:
        op = db_sync.query(BulkOperation).filter(
            BulkOperation.id == UUID(operation_id),
        ).one_or_none()

        if not op or op.status == "cancelled":
            return {"status": "skipped", "reason": "not found or cancelled"}

        op.status = "running"
        op.started_at = datetime.now(timezone.utc)
        db_sync.commit()

        # Run async export in event loop
        async def _run_export() -> str:
            from app.db.session import async_session_maker

            async with async_session_maker() as db:
                if export_type == "users":
                    return await export_users_csv(db, filters=filters)
                elif export_type == "subscriptions":
                    return await export_subscriptions_csv(db, filters=filters)
                elif export_type == "audit_log":
                    return await export_audit_log_csv(db, filters=filters)
                else:
                    raise ValueError(f"Unknown export type: {export_type}")

        filepath = asyncio.run(_run_export())

        op.status = "completed"
        op.completed_at = datetime.now(timezone.utc)
        op.processed_count = 1
        op.result_url = filepath
        db_sync.commit()

        logger.info(
            "Export complete: op=%s type=%s path=%s",
            operation_id, export_type, filepath,
        )
        return {"status": "completed", "path": filepath}

    except Exception as exc:
        logger.exception("Export task failed: op=%s", operation_id)
        try:
            if op:
                op.status = "failed"
                op.error_message = str(exc)[:2000]
                op.completed_at = datetime.now(timezone.utc)
                db_sync.commit()
        except Exception:
            logger.exception("Failed to mark export operation as failed")
        raise
    finally:
        db_sync.close()
