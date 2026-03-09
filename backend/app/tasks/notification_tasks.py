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
_EMAIL_DEDUP_PREFIX = "mg:email_dedup:"
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
    """Check if user has enabled this notification type for push.

    Falls back to True if the preference key is missing (opt-out model).
    Also checks the global push_notifications_enabled toggle.
    """
    if not user.push_notifications_enabled:
        return False

    prefs: dict[str, bool] = user.notification_preferences or {}
    return prefs.get(notification_type, True)


def _user_wants_email_notification(user: User, notification_type: str) -> bool:
    """Check if user should receive email notifications.

    Checks: email_notifications_enabled (user pref), email_suppressed (system),
    is_verified, and granular notification_preferences.
    """
    if not user.email_notifications_enabled:
        return False
    if getattr(user, "email_suppressed", False):
        return False
    if not user.is_verified:
        return False

    prefs: dict[str, bool] = user.notification_preferences or {}
    return prefs.get(notification_type, True)


async def _is_email_already_sent(dedup_key: str) -> bool:
    """Check if an email was already sent (separate dedup from push)."""
    try:
        r = aioredis.from_url(str(settings.redis_url), decode_responses=True)
        try:
            exists = await r.exists(f"{_EMAIL_DEDUP_PREFIX}{dedup_key}")
            if exists:
                return True
            await r.setex(f"{_EMAIL_DEDUP_PREFIX}{dedup_key}", _DEDUP_TTL, "1")
            return False
        finally:
            await r.aclose()
    except Exception as e:
        logger.warning("Email dedup check failed for key=%s: %s", dedup_key, e)
        return False


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

                # Send email notification (separate dedup from push)
                if _user_wants_email_notification(user, "upcoming_charges"):
                    email_dedup_key = f"email:upcoming:{sub.id}:{target_date.isoformat()}"
                    if not await _is_email_already_sent(email_dedup_key):
                        try:
                            from app.services.email_template_service import EmailTemplateService
                            from app.services.email_sender_service import EmailSenderService

                            content = EmailTemplateService.render_upcoming_charge(
                                subscription_name=sub.name,
                                amount=float(sub.amount),
                                billing_date=target_date.isoformat(),
                                days_until=days_until,
                            )
                            email_sent = await EmailSenderService._send_email(
                                user.email, content.subject, content.plain_body, content.html_body
                            )
                            if email_sent:
                                alert.email_sent = True
                        except Exception as email_err:
                            logger.warning("Failed to send upcoming charge email to %s: %s", user.email, email_err)

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

                # Send email notification (separate dedup from push)
                if _user_wants_email_notification(user, "overdraft_warnings"):
                    email_dedup_key = f"email:overdraft:{user.id}:{date.today().isoformat()}"
                    if not await _is_email_already_sent(email_dedup_key):
                        try:
                            from app.services.email_template_service import EmailTemplateService
                            from app.services.email_sender_service import EmailSenderService

                            subs_list = [
                                {"name": s.name, "amount": f"{float(s.amount):.2f}"}
                                for s in upcoming_subs[:5]
                            ]
                            content = EmailTemplateService.render_overdraft_warning(
                                total_balance=total_balance,
                                upcoming_total=upcoming_total,
                                shortfall=shortfall,
                                subscriptions_list=subs_list,
                            )
                            email_sent = await EmailSenderService._send_email(
                                user.email, content.subject, content.plain_body, content.html_body
                            )
                            if email_sent:
                                alert.email_sent = True
                        except Exception as email_err:
                            logger.warning("Failed to send overdraft email to %s: %s", user.email, email_err)

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


# ---------------------------------------------------------------------------
# Tier 2 Tasks (Pro only)
# ---------------------------------------------------------------------------

@celery_app.task(
    name="app.tasks.notification_tasks.send_price_increase_notifications",
    bind=True,
    max_retries=2,
    default_retry_delay=300,
)
def send_price_increase_notifications(self) -> dict[str, int]:
    """Notify Pro users about detected price increases. Runs daily."""
    return asyncio.run(_send_price_increase_notifications_async())


async def _send_price_increase_notifications_async() -> dict[str, int]:
    """Async implementation of price increase notifications."""
    db = _get_async_session()
    sent_count = 0

    try:
        notification_service = NotificationService(db)

        result = await db.execute(
            select(Subscription).where(
                Subscription.ai_flag == "price_increase",
                Subscription.is_active == True,
                Subscription.deleted_at.is_(None),
            )
        )
        subscriptions = result.scalars().all()

        for sub in subscriptions:
            user_result = await db.execute(select(User).where(User.id == sub.user_id))
            user = user_result.scalar_one_or_none()
            if user is None or user.subscription_tier != "pro":
                continue

            dedup_key = f"price_increase:{sub.id}"
            if await _is_already_notified(dedup_key):
                continue

            old_amount = float(sub.previous_amount) if sub.previous_amount else 0
            new_amount = float(sub.amount)
            percent_change = ((new_amount - old_amount) / old_amount * 100) if old_amount > 0 else 0

            title = f"Price Increase: {sub.name}"
            body = f"{sub.name} increased from ${old_amount:.2f} to ${new_amount:.2f} (+{percent_change:.0f}%)"

            alert = await _create_alert(
                db=db,
                tenant_id=sub.tenant_id,
                user_id=sub.user_id,
                alert_type="price_increase",
                severity="warning",
                title=title,
                message=body,
                amount=sub.amount,
                subscription_id=sub.id,
            )

            if _user_wants_notification(user, "price_increases"):
                success = await notification_service.send_price_increase_alert(
                    user_id=user.id,
                    tenant_id=user.tenant_id,
                    subscription_name=sub.name,
                    old_price=old_amount,
                    new_price=new_amount,
                    subscription_id=str(sub.id),
                )
                if not success:
                    alert.push_sent = False

            if _user_wants_email_notification(user, "price_increases"):
                email_dedup_key = f"email:price_increase:{sub.id}"
                if not await _is_email_already_sent(email_dedup_key):
                    try:
                        from app.services.email_template_service import EmailTemplateService
                        from app.services.email_sender_service import EmailSenderService

                        content = EmailTemplateService.render_price_increase(
                            subscription_name=sub.name,
                            old_amount=old_amount,
                            new_amount=new_amount,
                            percent_change=percent_change,
                        )
                        if await EmailSenderService._send_email(
                            user.email, content.subject, content.plain_body, content.html_body
                        ):
                            alert.email_sent = True
                    except Exception as e:
                        logger.warning("Failed to send price increase email: %s", e)

            sent_count += 1

        await db.commit()
        logger.info("Sent %d price increase notifications", sent_count)
    except Exception as e:
        await db.rollback()
        logger.error("Error sending price increase notifications: %s", e)
        raise
    finally:
        await db.close()

    return {"sent": sent_count}


@celery_app.task(
    name="app.tasks.notification_tasks.send_trial_ending_notifications",
    bind=True,
    max_retries=2,
    default_retry_delay=300,
)
def send_trial_ending_notifications(self) -> dict[str, int]:
    """Notify Pro users about trials ending within 3 days. Runs every 12h."""
    return asyncio.run(_send_trial_ending_notifications_async())


async def _send_trial_ending_notifications_async() -> dict[str, int]:
    """Async implementation of trial ending notifications."""
    db = _get_async_session()
    sent_count = 0

    try:
        notification_service = NotificationService(db)
        today = date.today()
        three_days = today + timedelta(days=3)

        result = await db.execute(
            select(Subscription).where(
                Subscription.trial_end_date.isnot(None),
                Subscription.trial_end_date >= today,
                Subscription.trial_end_date <= three_days,
                Subscription.is_active == True,
                Subscription.deleted_at.is_(None),
            )
        )
        subscriptions = result.scalars().all()

        for sub in subscriptions:
            user_result = await db.execute(select(User).where(User.id == sub.user_id))
            user = user_result.scalar_one_or_none()
            if user is None or user.subscription_tier != "pro":
                continue

            dedup_key = f"trial_ending:{sub.id}"
            if await _is_already_notified(dedup_key):
                continue

            trial_end = sub.trial_end_date.isoformat() if sub.trial_end_date else "soon"
            amount = float(sub.amount)

            title = f"Trial Ending: {sub.name}"
            body = f"{sub.name} trial ends {trial_end}. ${amount:.2f}/mo after trial."

            alert = await _create_alert(
                db=db,
                tenant_id=sub.tenant_id,
                user_id=sub.user_id,
                alert_type="trial_ending",
                severity="warning",
                title=title,
                message=body,
                amount=sub.amount,
                subscription_id=sub.id,
            )

            if _user_wants_notification(user, "trial_endings"):
                days_left = (sub.trial_end_date - today).days if sub.trial_end_date else 0
                success = await notification_service.send_trial_ending_reminder(
                    user_id=user.id,
                    tenant_id=user.tenant_id,
                    subscription_name=sub.name,
                    days_until=days_left,
                    amount_after_trial=amount,
                    subscription_id=str(sub.id),
                )
                if not success:
                    alert.push_sent = False

            if _user_wants_email_notification(user, "trial_endings"):
                email_dedup_key = f"email:trial_ending:{sub.id}"
                if not await _is_email_already_sent(email_dedup_key):
                    try:
                        from app.services.email_template_service import EmailTemplateService
                        from app.services.email_sender_service import EmailSenderService

                        content = EmailTemplateService.render_trial_ending(
                            subscription_name=sub.name,
                            trial_end_date=trial_end,
                            amount_after_trial=amount,
                        )
                        if await EmailSenderService._send_email(
                            user.email, content.subject, content.plain_body, content.html_body
                        ):
                            alert.email_sent = True
                    except Exception as e:
                        logger.warning("Failed to send trial ending email: %s", e)

            sent_count += 1

        await db.commit()
        logger.info("Sent %d trial ending notifications", sent_count)
    except Exception as e:
        await db.rollback()
        logger.error("Error sending trial ending notifications: %s", e)
        raise
    finally:
        await db.close()

    return {"sent": sent_count}


@celery_app.task(
    name="app.tasks.notification_tasks.send_forgotten_subscription_notifications",
    bind=True,
    max_retries=2,
    default_retry_delay=300,
)
def send_forgotten_subscription_notifications(self) -> dict[str, int]:
    """Notify Pro users about unused/forgotten subscriptions. Runs weekly."""
    return asyncio.run(_send_forgotten_subscription_notifications_async())


async def _send_forgotten_subscription_notifications_async() -> dict[str, int]:
    """Async implementation of forgotten subscription notifications."""
    db = _get_async_session()
    sent_count = 0

    try:
        notification_service = NotificationService(db)

        result = await db.execute(
            select(Subscription).where(
                Subscription.ai_flag.in_(["unused", "forgotten"]),
                Subscription.is_active == True,
                Subscription.deleted_at.is_(None),
            )
        )
        subscriptions = result.scalars().all()

        for sub in subscriptions:
            user_result = await db.execute(select(User).where(User.id == sub.user_id))
            user = user_result.scalar_one_or_none()
            if user is None or user.subscription_tier != "pro":
                continue

            dedup_key = f"forgotten:{sub.id}:{date.today().isocalendar()[1]}"
            if await _is_already_notified(dedup_key):
                continue

            amount = float(sub.amount)
            last_activity = sub.last_usage_detected.date().isoformat() if sub.last_usage_detected else "unknown"
            days_inactive = (date.today() - sub.last_usage_detected.date()).days if sub.last_usage_detected else 90

            title = f"Still using {sub.name}?"
            body = f"{sub.name} (${amount:.2f}/mo) — no activity for {days_inactive} days."

            alert = await _create_alert(
                db=db,
                tenant_id=sub.tenant_id,
                user_id=sub.user_id,
                alert_type="unused_subscription",
                severity="info",
                title=title,
                message=body,
                amount=sub.amount,
                subscription_id=sub.id,
            )

            if _user_wants_notification(user, "forgotten_subscriptions"):
                payload = NotificationPayload(
                    title=title,
                    body=body,
                    notification_type="unused_subscription",
                    subscription_id=str(sub.id),
                )
                success = await notification_service.send_to_user(
                    user_id=user.id,
                    tenant_id=user.tenant_id,
                    payload=payload,
                )
                if not success:
                    alert.push_sent = False

            if _user_wants_email_notification(user, "forgotten_subscriptions"):
                email_dedup_key = f"email:forgotten:{sub.id}:{date.today().isocalendar()[1]}"
                if not await _is_email_already_sent(email_dedup_key):
                    try:
                        from app.services.email_template_service import EmailTemplateService
                        from app.services.email_sender_service import EmailSenderService

                        content = EmailTemplateService.render_forgotten_subscription(
                            subscription_name=sub.name,
                            amount=amount,
                            last_activity_date=last_activity,
                            days_inactive=days_inactive,
                        )
                        if await EmailSenderService._send_email(
                            user.email, content.subject, content.plain_body, content.html_body
                        ):
                            alert.email_sent = True
                    except Exception as e:
                        logger.warning("Failed to send forgotten subscription email: %s", e)

            sent_count += 1

        await db.commit()
        logger.info("Sent %d forgotten subscription notifications", sent_count)
    except Exception as e:
        await db.rollback()
        logger.error("Error sending forgotten subscription notifications: %s", e)
        raise
    finally:
        await db.close()

    return {"sent": sent_count}
