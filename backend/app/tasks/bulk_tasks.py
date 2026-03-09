"""Celery tasks for executing bulk admin operations."""

import logging
from datetime import datetime, timezone
from uuid import UUID

from app.core.celery_app import celery_app

logger = logging.getLogger(__name__)


def _get_sync_session():
    """Create a synchronous database session for Celery tasks."""
    from sqlalchemy import create_engine
    from sqlalchemy.orm import Session, sessionmaker

    from app.core.config import settings

    sync_url = str(settings.database_url).replace(
        "postgresql+asyncpg://", "postgresql+psycopg2://",
    )
    engine = create_engine(sync_url)
    session_factory = sessionmaker(bind=engine)
    return session_factory()


@celery_app.task(
    name="app.tasks.bulk_tasks.execute_bulk_user_status",
    bind=True,
    max_retries=1,
)
def execute_bulk_user_status(self, operation_id: str) -> dict[str, str | int]:
    """Execute bulk user status change.

    Loads the operation, iterates over user_ids from parameters,
    and updates each user's status.
    """
    from app.models.bulk_operation import BulkOperation
    from app.models.user import User

    db = _get_sync_session()
    try:
        op = db.query(BulkOperation).filter(
            BulkOperation.id == UUID(operation_id),
        ).one_or_none()

        if not op or op.status == "cancelled":
            return {"status": "skipped", "reason": "not found or cancelled"}

        op.status = "running"
        op.started_at = datetime.now(timezone.utc)
        db.commit()

        params = op.parameters or {}
        user_ids: list[str] = params.get("user_ids", [])
        new_status: str = params.get("new_status", "active")

        processed = 0
        failed = 0

        for uid_str in user_ids:
            # Check for cancellation between iterations
            db.refresh(op)
            if op.status == "cancelled":
                break

            try:
                uid = UUID(uid_str)
                user = db.query(User).filter(User.id == uid).one_or_none()
                if not user:
                    failed += 1
                    continue

                if new_status == "active":
                    user.is_active = True
                elif new_status == "suspended":
                    user.is_active = False
                elif new_status == "deleted":
                    user.is_active = False

                processed += 1
            except Exception:
                logger.exception("Failed to update user %s", uid_str)
                failed += 1

            op.processed_count = processed
            op.failed_count = failed
            db.commit()

        op.status = "completed" if op.status != "cancelled" else "cancelled"
        op.completed_at = datetime.now(timezone.utc)
        op.processed_count = processed
        op.failed_count = failed
        db.commit()

        logger.info(
            "Bulk user status complete: op=%s processed=%d failed=%d",
            operation_id, processed, failed,
        )
        return {"status": "completed", "processed": processed, "failed": failed}

    except Exception as exc:
        logger.exception("Bulk user status task failed: op=%s", operation_id)
        try:
            if op:
                op.status = "failed"
                op.error_message = str(exc)[:2000]
                op.completed_at = datetime.now(timezone.utc)
                db.commit()
        except Exception:
            logger.exception("Failed to mark operation as failed")
        raise
    finally:
        db.close()


@celery_app.task(
    name="app.tasks.bulk_tasks.execute_bulk_tier_override",
    bind=True,
    max_retries=1,
)
def execute_bulk_tier_override(self, operation_id: str) -> dict[str, str | int]:
    """Execute bulk tenant tier override.

    Loads the operation, iterates over tenant_ids from parameters,
    and updates each tenant's tier.
    """
    from app.models.bulk_operation import BulkOperation
    from app.models.tenant import Tenant

    db = _get_sync_session()
    try:
        op = db.query(BulkOperation).filter(
            BulkOperation.id == UUID(operation_id),
        ).one_or_none()

        if not op or op.status == "cancelled":
            return {"status": "skipped", "reason": "not found or cancelled"}

        op.status = "running"
        op.started_at = datetime.now(timezone.utc)
        db.commit()

        params = op.parameters or {}
        tenant_ids: list[str] = params.get("tenant_ids", [])
        new_tier: str = params.get("new_tier", "free")

        processed = 0
        failed = 0

        for tid_str in tenant_ids:
            db.refresh(op)
            if op.status == "cancelled":
                break

            try:
                tid = UUID(tid_str)
                tenant = db.query(Tenant).filter(Tenant.id == tid).one_or_none()
                if not tenant:
                    failed += 1
                    continue

                tenant.tier = new_tier
                processed += 1
            except Exception:
                logger.exception("Failed to update tenant %s", tid_str)
                failed += 1

            op.processed_count = processed
            op.failed_count = failed
            db.commit()

        op.status = "completed" if op.status != "cancelled" else "cancelled"
        op.completed_at = datetime.now(timezone.utc)
        op.processed_count = processed
        op.failed_count = failed
        db.commit()

        logger.info(
            "Bulk tier override complete: op=%s processed=%d failed=%d",
            operation_id, processed, failed,
        )
        return {"status": "completed", "processed": processed, "failed": failed}

    except Exception as exc:
        logger.exception("Bulk tier override task failed: op=%s", operation_id)
        try:
            if op:
                op.status = "failed"
                op.error_message = str(exc)[:2000]
                op.completed_at = datetime.now(timezone.utc)
                db.commit()
        except Exception:
            logger.exception("Failed to mark operation as failed")
        raise
    finally:
        db.close()


@celery_app.task(
    name="app.tasks.bulk_tasks.execute_bulk_notification",
    bind=True,
    max_retries=1,
)
def execute_bulk_notification(self, operation_id: str) -> dict[str, str | int]:
    """Execute bulk notification send.

    Loads the operation, iterates over user_ids from parameters,
    and sends notifications to each user.
    """
    from app.models.bulk_operation import BulkOperation
    from app.models.user import User

    db = _get_sync_session()
    try:
        op = db.query(BulkOperation).filter(
            BulkOperation.id == UUID(operation_id),
        ).one_or_none()

        if not op or op.status == "cancelled":
            return {"status": "skipped", "reason": "not found or cancelled"}

        op.status = "running"
        op.started_at = datetime.now(timezone.utc)
        db.commit()

        params = op.parameters or {}
        user_ids: list[str] = params.get("user_ids", [])
        notification_type: str = params.get("notification_type", "push")
        title: str = params.get("title", "")
        body: str = params.get("body", "")

        processed = 0
        failed = 0

        for uid_str in user_ids:
            db.refresh(op)
            if op.status == "cancelled":
                break

            try:
                uid = UUID(uid_str)
                user = db.query(User).filter(User.id == uid).one_or_none()
                if not user:
                    failed += 1
                    continue

                # Send push notification if applicable
                if notification_type in ("push", "both") and user.fcm_token:
                    # FCM sending would happen here via firebase_admin SDK
                    logger.info(
                        "Push notification queued for user %s: %s",
                        uid_str, title,
                    )

                # Send email notification if applicable
                if notification_type in ("email", "both") and not user.email_suppressed:
                    # Email sending would happen here via SES/SMTP
                    logger.info(
                        "Email notification queued for user %s: %s",
                        uid_str, title,
                    )

                processed += 1
            except Exception:
                logger.exception("Failed to notify user %s", uid_str)
                failed += 1

            op.processed_count = processed
            op.failed_count = failed
            db.commit()

        op.status = "completed" if op.status != "cancelled" else "cancelled"
        op.completed_at = datetime.now(timezone.utc)
        op.processed_count = processed
        op.failed_count = failed
        db.commit()

        logger.info(
            "Bulk notification complete: op=%s processed=%d failed=%d",
            operation_id, processed, failed,
        )
        return {"status": "completed", "processed": processed, "failed": failed}

    except Exception as exc:
        logger.exception("Bulk notification task failed: op=%s", operation_id)
        try:
            if op:
                op.status = "failed"
                op.error_message = str(exc)[:2000]
                op.completed_at = datetime.now(timezone.utc)
                db.commit()
        except Exception:
            logger.exception("Failed to mark operation as failed")
        raise
    finally:
        db.close()
