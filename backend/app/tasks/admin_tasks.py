"""Admin background tasks.

Handles bulk notification dispatch when the target audience exceeds the
inline send threshold.
"""

import logging

from app.core.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(
    name="app.tasks.admin_tasks.send_bulk_notification",
    bind=True,
    max_retries=3,
    default_retry_delay=60,
)
def send_bulk_notification(self, notification_id: str) -> dict[str, int]:  # type: ignore[no-untyped-def]
    """Send a bulk admin notification in background.

    Loads the AdminNotification record, resolves target users, and sends
    push/email in batches. Updates sent_count and failed_count on the record.
    """
    import asyncio

    async def _run() -> dict[str, int]:
        from uuid import UUID

        from sqlalchemy import select

        from app.db.session import async_session_maker
        from app.models.admin_notification import AdminNotification
        from app.models.user import User
        from app.services.email_sender_service import EmailSenderService
        from app.services.notification_service import (
            NotificationPayload,
            NotificationService,
        )

        async with async_session_maker() as db:
            try:
                # Load notification
                result = await db.execute(
                    select(AdminNotification).where(
                        AdminNotification.id == UUID(notification_id)
                    )
                )
                notification = result.scalar_one_or_none()
                if notification is None:
                    logger.error("Notification %s not found", notification_id)
                    return {"sent": 0, "failed": 0}

                user_ids = notification.target_ids or []
                sent = 0
                failed = 0

                notification_svc = NotificationService(db)
                email_svc = EmailSenderService(db)

                for uid_str in user_ids:
                    try:
                        uid = UUID(uid_str)
                        user_result = await db.execute(
                            select(User).where(
                                User.id == uid,
                                User.is_active == True,  # noqa: E712
                            )
                        )
                        user = user_result.scalar_one_or_none()
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
                                logger.exception(
                                    "Email send failed for user %s", uid_str,
                                )

                        if ok:
                            sent += 1
                        else:
                            failed += 1

                    except Exception:
                        logger.exception(
                            "Notification send failed for user %s", uid_str,
                        )
                        failed += 1

                # Update notification record
                notification.sent_count = sent
                notification.failed_count = failed
                notification.status = (
                    "sent" if failed == 0
                    else ("failed" if sent == 0 else "sent")
                )
                db.add(notification)
                await db.commit()

                logger.info(
                    "Bulk notification %s complete: sent=%d failed=%d",
                    notification_id, sent, failed,
                )
                return {"sent": sent, "failed": failed}

            except Exception:
                logger.exception(
                    "Bulk notification %s failed", notification_id,
                )
                # Mark as failed
                try:
                    result = await db.execute(
                        select(AdminNotification).where(
                            AdminNotification.id == UUID(notification_id)
                        )
                    )
                    notification = result.scalar_one_or_none()
                    if notification:
                        notification.status = "failed"
                        db.add(notification)
                        await db.commit()
                except Exception:
                    logger.exception("Failed to update notification status")
                raise

    try:
        return asyncio.get_event_loop().run_until_complete(_run())
    except RuntimeError:
        loop = asyncio.new_event_loop()
        try:
            return loop.run_until_complete(_run())
        finally:
            loop.close()
