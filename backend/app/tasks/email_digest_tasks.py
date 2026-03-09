"""Weekly email digest task.

Sends a branded weekly summary email to opt-in users every Monday at 8 AM UTC.
Digest is OPT-IN (default off) — "Silence is a feature."
"""

import asyncio
import logging
from datetime import date, timedelta
from decimal import Decimal

import redis.asyncio as aioredis
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from app.core.celery_app import celery_app
from app.core.config import settings
from app.models.bank_account import BankAccount
from app.models.subscription import Subscription
from app.models.user import User

logger = logging.getLogger(__name__)

_EMAIL_DEDUP_PREFIX = "mg:email_dedup:"
_DEDUP_TTL = 86400 * 7  # 7 days


def _get_async_session() -> AsyncSession:
    engine = create_async_engine(str(settings.database_url), pool_pre_ping=True, pool_size=5, max_overflow=0)
    factory = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    return factory()


@celery_app.task(
    name="app.tasks.email_digest_tasks.send_weekly_digest",
    bind=True,
    max_retries=2,
    default_retry_delay=600,
)
def send_weekly_digest(self) -> dict[str, int]:
    """Send weekly digest email to opt-in users. Runs Monday 8 AM UTC."""
    return asyncio.run(_send_weekly_digest_async())


async def _send_weekly_digest_async() -> dict[str, int]:
    db = _get_async_session()
    sent_count = 0

    try:
        today = date.today()
        week_number = today.isocalendar()[1]
        week_end = today + timedelta(days=7)

        # Get all active, verified users
        result = await db.execute(
            select(User).where(
                User.is_active == True,
                User.is_verified == True,
                User.email_notifications_enabled == True,
            )
        )
        users = result.scalars().all()

        for user in users:
            # Weekly digest is OPT-IN (default False)
            prefs: dict[str, bool] = user.notification_preferences or {}
            if not prefs.get("weekly_digest", False):
                continue

            # Skip suppressed users
            if getattr(user, "email_suppressed", False):
                continue

            # Dedup: one digest per user per week
            dedup_key = f"digest:{user.id}:{week_number}"
            try:
                r = aioredis.from_url(str(settings.redis_url), decode_responses=True)
                try:
                    if await r.exists(f"{_EMAIL_DEDUP_PREFIX}{dedup_key}"):
                        continue
                    await r.setex(f"{_EMAIL_DEDUP_PREFIX}{dedup_key}", _DEDUP_TTL, "1")
                finally:
                    await r.aclose()
            except Exception:
                pass

            # Get upcoming subscriptions for next 7 days
            sub_result = await db.execute(
                select(Subscription).where(
                    Subscription.user_id == user.id,
                    Subscription.tenant_id == user.tenant_id,
                    Subscription.next_billing_date >= today,
                    Subscription.next_billing_date <= week_end,
                    Subscription.is_active == True,
                    Subscription.is_paused == False,
                    Subscription.deleted_at.is_(None),
                )
            )
            upcoming_subs = sub_result.scalars().all()

            # Get total active subscriptions and monthly total
            all_subs_result = await db.execute(
                select(Subscription).where(
                    Subscription.user_id == user.id,
                    Subscription.tenant_id == user.tenant_id,
                    Subscription.is_active == True,
                    Subscription.deleted_at.is_(None),
                )
            )
            all_subs = all_subs_result.scalars().all()
            monthly_total = sum(float(s.amount) for s in all_subs)
            subscription_count = len(all_subs)

            # Get balance for safe-to-spend
            balance_result = await db.execute(
                select(BankAccount).where(
                    BankAccount.user_id == user.id,
                    BankAccount.tenant_id == user.tenant_id,
                    BankAccount.is_active == True,
                    BankAccount.include_in_pulse == True,
                )
            )
            accounts = balance_result.scalars().all()
            total_balance = sum(
                float(acc.available_balance or acc.current_balance or 0)
                for acc in accounts
            )

            upcoming_total = sum(float(s.amount) for s in upcoming_subs)
            safe_to_spend = max(0, total_balance - upcoming_total)

            # Determine pulse status
            if total_balance <= 0:
                pulse_status = "FREEZE"
            elif upcoming_total > total_balance:
                pulse_status = "FREEZE"
            elif upcoming_total > total_balance * 0.7:
                pulse_status = "CAUTION"
            else:
                pulse_status = "SAFE"

            charges_list = [
                {
                    "name": s.name,
                    "amount": f"{float(s.amount):.2f}",
                    "date": s.next_billing_date.isoformat(),
                }
                for s in upcoming_subs[:7]
            ]

            try:
                from app.services.email_template_service import EmailTemplateService
                from app.services.email_sender_service import EmailSenderService

                content = EmailTemplateService.render_weekly_digest(
                    pulse_status=pulse_status,
                    safe_to_spend=safe_to_spend,
                    upcoming_charges_list=charges_list,
                    monthly_total=monthly_total,
                    subscription_count=subscription_count,
                )
                if await EmailSenderService._send_email(
                    user.email, content.subject, content.plain_body, content.html_body
                ):
                    sent_count += 1
            except Exception as e:
                logger.warning("Failed to send weekly digest to %s: %s", user.email, e)

        logger.info("Sent %d weekly digest emails", sent_count)
    except Exception as e:
        logger.error("Error sending weekly digests: %s", e)
        raise
    finally:
        await db.close()

    return {"sent": sent_count}
