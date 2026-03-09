"""Admin notification service.

Handles sending bulk push/email notifications from the admin portal.
Small batches (<= 100 users) are sent inline; larger batches are
dispatched to a Celery background task.
"""

import logging
from uuid import UUID, uuid4

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.admin_notification import AdminNotification
from app.models.admin_user import AdminUser
from app.models.user import User
from app.schemas.admin_notifications import NotificationResponse, SendNotificationRequest
from app.services.notification_service import NotificationPayload, NotificationService
from app.services.email_sender_service import EmailSenderService

logger = logging.getLogger(__name__)

# Threshold above which we defer to Celery
INLINE_SEND_LIMIT = 100


async def _resolve_target_user_ids(
    db: AsyncSession,
    request: SendNotificationRequest,
) -> list[str]:
    """Resolve the final list of user ID strings based on target_type."""
    if request.target_type == "user":
        return request.target_ids or []

    query = select(User.id).where(User.is_active == True)  # noqa: E712

    if request.target_type == "tier":
        if request.target_tier:
            query = query.where(User.subscription_tier == request.target_tier)

    result = await db.execute(query)
    return [str(uid) for uid in result.scalars().all()]


async def _send_inline(
    db: AsyncSession,
    notification: AdminNotification,
    user_ids: list[str],
) -> None:
    """Send notifications inline (for small batches)."""
    sent = 0
    failed = 0

    notification_svc = NotificationService(db)
    email_svc = EmailSenderService(db)

    for uid_str in user_ids:
        uid = UUID(uid_str)
        try:
            # Look up user for tenant_id and email
            result = await db.execute(
                select(User).where(User.id == uid, User.is_active == True)  # noqa: E712
            )
            user = result.scalar_one_or_none()
            if user is None:
                failed += 1
                continue

            ok = False

            if notification.notification_type in ("push", "both"):
                payload = NotificationPayload(
                    title=notification.title,
                    body=notification.body,
                    notification_type="general",
                )
                push_ok = await notification_svc.send_to_user(
                    user_id=uid,
                    tenant_id=user.tenant_id,
                    payload=payload,
                )
                if push_ok:
                    ok = True

            if notification.notification_type in ("email", "both"):
                try:
                    email_ok = await email_svc.send_raw_email(
                        to_email=user.email,
                        subject=notification.title,
                        body_text=notification.body,
                    )
                    if email_ok:
                        ok = True
                except Exception:
                    logger.exception("Failed to send admin email to %s", user.email)

            if ok:
                sent += 1
            else:
                failed += 1

        except Exception:
            logger.exception("Failed to send admin notification to user %s", uid_str)
            failed += 1

    notification.sent_count = sent
    notification.failed_count = failed
    notification.status = "sent" if failed == 0 else ("failed" if sent == 0 else "sent")
    db.add(notification)
    await db.flush()


async def send_notification(
    db: AsyncSession,
    admin: AdminUser,
    request: SendNotificationRequest,
) -> AdminNotification:
    """Create and dispatch an admin notification.

    For <= INLINE_SEND_LIMIT targets, sends inline.
    For larger batches, enqueues a Celery task and returns immediately.
    """
    user_ids = await _resolve_target_user_ids(db, request)

    notification = AdminNotification(
        id=uuid4(),
        admin_user_id=admin.id,
        notification_type=request.notification_type,
        target_type=request.target_type,
        target_ids=user_ids,
        target_tier=request.target_tier,
        title=request.title,
        body=request.body,
        sent_count=0,
        failed_count=0,
        status="pending",
    )
    db.add(notification)
    await db.flush()

    if len(user_ids) <= INLINE_SEND_LIMIT:
        await _send_inline(db, notification, user_ids)
    else:
        # Dispatch to Celery for background processing
        notification.status = "sending"
        db.add(notification)
        await db.flush()

        from app.tasks.admin_tasks import send_bulk_notification
        send_bulk_notification.delay(str(notification.id))

    return notification


async def list_notifications(
    db: AsyncSession,
    *,
    page: int = 1,
    page_size: int = 50,
) -> tuple[list[AdminNotification], int]:
    """List admin notifications with pagination."""
    count_query = select(func.count(AdminNotification.id))
    total_count: int = (await db.execute(count_query)).scalar() or 0

    query = (
        select(AdminNotification)
        .order_by(AdminNotification.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    result = await db.execute(query)
    notifications = list(result.scalars().all())

    return notifications, total_count


async def get_notification(
    db: AsyncSession,
    notification_id: UUID,
) -> AdminNotification | None:
    """Get a single admin notification by ID."""
    result = await db.execute(
        select(AdminNotification).where(AdminNotification.id == notification_id)
    )
    return result.scalar_one_or_none()
