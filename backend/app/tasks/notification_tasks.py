"""Background tasks for sending push notifications.

Scheduled tasks that check for upcoming charges, overdraft risks,
and other alert conditions, then send push notifications via FCM.
"""

import logging
from datetime import date, timedelta
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from app.core.celery_app import celery_app
from app.core.config import settings
from app.models.subscription import Subscription
from app.models.user import User
from app.models.bank_account import BankAccount
from app.services.notification_service import NotificationService, NotificationPayload

logger = logging.getLogger(__name__)


def _get_sync_session() -> AsyncSession:
    """Create an async session for background tasks."""
    engine = create_async_engine(str(settings.database_url))
    session_factory = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    return session_factory()


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
    import asyncio
    return asyncio.get_event_loop().run_until_complete(
        _send_upcoming_charge_notifications_async()
    )


async def _send_upcoming_charge_notifications_async() -> dict[str, int]:
    """Async implementation of upcoming charge notifications."""
    db = _get_sync_session()
    sent_count = 0

    try:
        notification_service = NotificationService(db)
        today = date.today()
        notify_dates = [today, today + timedelta(days=1), today + timedelta(days=3)]

        for target_date in notify_dates:
            days_until = (target_date - today).days

            # Find subscriptions billing on this date
            result = await db.execute(
                select(Subscription).where(
                    Subscription.next_billing_date == target_date,
                    Subscription.status == "active",
                    Subscription.is_paused == False,
                )
            )
            subscriptions = result.scalars().all()

            for sub in subscriptions:
                success = await notification_service.send_subscription_reminder(
                    user_id=sub.user_id,
                    tenant_id=sub.tenant_id,
                    subscription_name=sub.name,
                    amount=float(sub.amount),
                    days_until=days_until,
                    subscription_id=str(sub.id),
                )
                if success:
                    sent_count += 1

        logger.info("Sent %d upcoming charge notifications", sent_count)
    except Exception as e:
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
    import asyncio
    return asyncio.get_event_loop().run_until_complete(
        _send_overdraft_warnings_async()
    )


async def _send_overdraft_warnings_async() -> dict[str, int]:
    """Async implementation of overdraft warning notifications."""
    db = _get_sync_session()
    sent_count = 0

    try:
        notification_service = NotificationService(db)
        today = date.today()
        week_from_now = today + timedelta(days=7)

        # Get all active users with bank accounts
        result = await db.execute(
            select(User).where(
                User.is_active == True,
                User.push_notifications_enabled == True,
                User.fcm_token.isnot(None),
            )
        )
        users = result.scalars().all()

        for user in users:
            # Get total available balance
            balance_result = await db.execute(
                select(BankAccount).where(
                    BankAccount.user_id == user.id,
                    BankAccount.is_active == True,
                    BankAccount.include_in_pulse == True,
                )
            )
            accounts = balance_result.scalars().all()
            total_balance = sum(
                float(acc.available_balance or acc.current_balance or 0)
                for acc in accounts
            )

            if total_balance <= 0:
                continue

            # Get upcoming charges for next 7 days
            sub_result = await db.execute(
                select(Subscription).where(
                    Subscription.user_id == user.id,
                    Subscription.tenant_id == user.tenant_id,
                    Subscription.next_billing_date >= today,
                    Subscription.next_billing_date <= week_from_now,
                    Subscription.status == "active",
                    Subscription.is_paused == False,
                )
            )
            upcoming_subs = sub_result.scalars().all()
            upcoming_total = sum(float(s.amount) for s in upcoming_subs)

            if upcoming_total > total_balance:
                success = await notification_service.send_overdraft_warning(
                    user_id=user.id,
                    tenant_id=user.tenant_id,
                    current_balance=total_balance,
                    upcoming_charges=upcoming_total,
                    alert_id="",  # Generated alert ID would go here
                )
                if success:
                    sent_count += 1

        logger.info("Sent %d overdraft warning notifications", sent_count)
    except Exception as e:
        logger.error("Error sending overdraft warnings: %s", e)
        raise
    finally:
        await db.close()

    return {"sent": sent_count}
