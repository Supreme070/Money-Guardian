"""Background tasks for sending push notifications.

Scheduled tasks that check for upcoming charges, overdraft risks,
and other alert conditions, then send push notifications via FCM.

Every notification also creates an Alert record in the database
so users can see their notification history in-app.
"""

import asyncio
import logging
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from uuid import UUID

import redis.asyncio as aioredis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from app.core.celery_app import celery_app
from app.core.config import settings
from app.models.alert import Alert
from app.models.subscription import Subscription
from app.models.user import User
from app.models.bank_account import BankAccount
from app.services.notification_service import NotificationService, NotificationPayload

logger = logging.getLogger(__name__)

# Deduplication key prefix and TTL (24 hours)
_DEDUP_PREFIX = "mg:notif_dedup:"
_DEDUP_TTL = 86400  # 24 hours


async def _is_already_notified(dedup_key: str) -> bool:
    """Check if a notification was already sent (dedup via Redis)."""
    try:
        r = aioredis.from_url(str(settings.redis_url), decode_responses=True)
        try:
            exists = await r.exists(f"{_DEDUP_PREFIX}{dedup_key}")
            if exists:
                return True
            await r.setex(f"{_DEDUP_PREFIX}{dedup_key}", _DEDUP_TTL, "1")
            return False
        finally:
            await r.aclose()
    except Exception as e:
        logger.warning("Dedup check failed for key=%s: %s", dedup_key, e)
        # Fail open: allow notification if Redis is down
        return False


def _get_async_session() -> AsyncSession:
    """Create an async session for background tasks."""
    engine = create_async_engine(
        str(settings.database_url),
        pool_pre_ping=True,
        pool_size=5,
        max_overflow=0,
    )
    session_factory = sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    return session_factory()


async def _create_alert(
    db: AsyncSession,
    tenant_id: UUID,
    user_id: UUID,
    alert_type: str,
    severity: str,
    title: str,
    message: str,
    amount: Decimal | None = None,
    subscription_id: UUID | None = None,
    alert_date: datetime | None = None,
) -> Alert:
    """Create an Alert record in the database for every notification sent."""
    alert = Alert(
        tenant_id=tenant_id,
        user_id=user_id,
        subscription_id=subscription_id,
        alert_type=alert_type,
        severity=severity,
        title=title,
        message=message,
        amount=amount,
        alert_date=alert_date or datetime.now(timezone.utc),
        is_read=False,
        is_dismissed=False,
        push_sent=True,
    )
    db.add(alert)
    await db.flush()
    return alert


@celery_app.task(
    name="app.tasks.notification_tasks.send_upcoming_charge_notifications",
    bind=True,
    max_retries=2,
    default_retry_delay=300,
)
def send_upcoming_charge_notifications(self) -> dict[str, int]:
    """
    Check for subscriptions charging in the next 1-3 days and notify users.

    Runs daily. Sends notifications for:
    - Charges happening today (day 0)
    - Charges happening tomorrow (day 1)
    - Charges in 3 days (day 3)
    """
    return asyncio.run(_send_upcoming_charge_notifications_async())


def _user_wants_notification(user: User, notification_type: str) -> bool:
    """Check if user has enabled this notification type in granular preferences.

    Falls back to True if the preference key is missing (opt-out model).
    Also checks the global push_notifications_enabled toggle.
    """
    if not user.push_notifications_enabled:
        return False

    prefs: dict[str, bool] = user.notification_preferences or {}
    return prefs.get(notification_type, True)


async def _send_upcoming_charge_notifications_async() -> dict[str, int]:
    """Async implementation of upcoming charge notifications."""
    db = _get_async_session()
    sent_count = 0

    try:
        notification_service = NotificationService(db)
        today = date.today()
        notify_dates = [today, today + timedelta(days=1), today + timedelta(days=3)]

        for target_date in notify_dates:
            days_until = (target_date - today).days

            # Find subscriptions billing on this date
            # Uses is_active (bool column) - NOT "status" which doesn't exist
            result = await db.execute(
                select(Subscription).where(
                    Subscription.next_billing_date == target_date,
                    Subscription.is_active == True,
                    Subscription.is_paused == False,
                    Subscription.deleted_at.is_(None),
                )
            )
            subscriptions = result.scalars().all()

            for sub in subscriptions:
                # Load the user to check granular notification preferences
                user_result = await db.execute(
                    select(User).where(User.id == sub.user_id)
                )
                user = user_result.scalar_one_or_none()
                if user is None or not _user_wants_notification(user, "upcoming_charges"):
                    continue

                # Dedup: skip if already notified for this subscription + date
                dedup_key = f"upcoming:{sub.id}:{target_date.isoformat()}"
                if await _is_already_notified(dedup_key):
                    continue

                # Determine severity based on timing
                severity = "critical" if days_until == 0 else "warning" if days_until == 1 else "info"

                # Build notification message
                if days_until == 0:
                    body = f"${float(sub.amount):.2f} will be charged today"
                elif days_until == 1:
                    body = f"${float(sub.amount):.2f} will be charged tomorrow"
                else:
                    body = f"${float(sub.amount):.2f} will be charged in {days_until} days"

                title = f"Upcoming: {sub.name}"

                # Create Alert record FIRST so we have a real alert_id
                alert = await _create_alert(
                    db=db,
                    tenant_id=sub.tenant_id,
                    user_id=sub.user_id,
                    alert_type="upcoming_charge",
                    severity=severity,
                    title=title,
                    message=body,
                    amount=sub.amount,
                    subscription_id=sub.id,
                    alert_date=datetime.combine(target_date, datetime.min.time(), tzinfo=timezone.utc),
                )

                # Send push notification with real alert_id
                success = await notification_service.send_subscription_reminder(
                    user_id=sub.user_id,
                    tenant_id=sub.tenant_id,
                    subscription_name=sub.name,
                    amount=float(sub.amount),
                    days_until=days_until,
                    subscription_id=str(sub.id),
                )

                if not success:
                    # Push failed - still keep the alert but mark push_sent=False
                    alert.push_sent = False

                sent_count += 1

        await db.commit()
        logger.info("Sent %d upcoming charge notifications", sent_count)
    except Exception as e:
        await db.rollback()
        logger.error("Error sending upcoming charge notifications: %s", e)
        raise
    finally:
        await db.close()

    return {"sent": sent_count}


@celery_app.task(
    name="app.tasks.notification_tasks.send_overdraft_warnings",
    bind=True,
    max_retries=2,
    default_retry_delay=300,
)
def send_overdraft_warnings(self) -> dict[str, int]:
    """
    Check if upcoming charges will exceed available balance.

    Runs daily. Compares next 7 days of charges against current balance.
    """
    return asyncio.run(_send_overdraft_warnings_async())


async def _send_overdraft_warnings_async() -> dict[str, int]:
    """Async implementation of overdraft warning notifications."""
    db = _get_async_session()
    sent_count = 0

    try:
        notification_service = NotificationService(db)
        today = date.today()
        week_from_now = today + timedelta(days=7)

        # Get all active users with push notifications enabled
        result = await db.execute(
            select(User).where(
                User.is_active == True,
                User.push_notifications_enabled == True,
                User.fcm_token.isnot(None),
            )
        )
        users = result.scalars().all()

        for user in users:
            # Check granular preference for overdraft warnings
            if not _user_wants_notification(user, "overdraft_warnings"):
                continue

            # Get total available balance from bank accounts
            balance_result = await db.execute(
                select(BankAccount).where(
                    BankAccount.user_id == user.id,
                    BankAccount.tenant_id == user.tenant_id,
                    BankAccount.is_active == True,
                    BankAccount.include_in_pulse == True,
                )
            )
            accounts = balance_result.scalars().all()

            if not accounts:
                continue

            total_balance = sum(
                float(acc.available_balance or acc.current_balance or 0)
                for acc in accounts
            )

            if total_balance <= 0:
                continue

            # Get upcoming charges for next 7 days
            # Uses is_active (bool column) - NOT "status" which doesn't exist
            sub_result = await db.execute(
                select(Subscription).where(
                    Subscription.user_id == user.id,
                    Subscription.tenant_id == user.tenant_id,
                    Subscription.next_billing_date >= today,
                    Subscription.next_billing_date <= week_from_now,
                    Subscription.is_active == True,
                    Subscription.is_paused == False,
                    Subscription.deleted_at.is_(None),
                )
            )
            upcoming_subs = sub_result.scalars().all()
            upcoming_total = sum(float(s.amount) for s in upcoming_subs)

            if upcoming_total > total_balance:
                # Dedup: skip if already warned this user today
                dedup_key = f"overdraft:{user.id}:{date.today().isoformat()}"
                if await _is_already_notified(dedup_key):
                    continue

                shortfall = upcoming_total - total_balance
                title = "Overdraft Risk Detected"
                body = (
                    f"Upcoming charges (${upcoming_total:.2f}) exceed your balance "
                    f"(${total_balance:.2f}). You may need ${shortfall:.2f} more."
                )

                # Create Alert record FIRST
                alert = await _create_alert(
                    db=db,
                    tenant_id=user.tenant_id,
                    user_id=user.id,
                    alert_type="overdraft_warning",
                    severity="critical",
                    title=title,
                    message=body,
                    amount=Decimal(str(shortfall)).quantize(Decimal("0.01")),
                )

                # Send push notification with real alert_id
                success = await notification_service.send_overdraft_warning(
                    user_id=user.id,
                    tenant_id=user.tenant_id,
                    current_balance=total_balance,
                    upcoming_charges=upcoming_total,
                    alert_id=str(alert.id),
                )

                if not success:
                    alert.push_sent = False

                sent_count += 1

        await db.commit()
        logger.info("Sent %d overdraft warning notifications", sent_count)
    except Exception as e:
        await db.rollback()
        logger.error("Error sending overdraft warnings: %s", e)
        raise
    finally:
        await db.close()

    return {"sent": sent_count}
