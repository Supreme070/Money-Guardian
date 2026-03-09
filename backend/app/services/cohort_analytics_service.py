"""Cohort analytics service for retention, funnel, and retention curves.

Provides advanced analytics queries for the admin portal:
- Cohort retention matrix (monthly cohorts)
- Conversion funnel (signup -> onboard -> bank -> pro)
- Retention curves (D1, D7, D14, D30, D60, D90)
"""

import logging
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import Date, and_, cast, extract, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.bank_connection import BankConnection
from app.models.email_connection import EmailConnection
from app.models.tenant import Tenant
from app.models.user import User

logger = logging.getLogger(__name__)


async def get_cohort_retention(
    db: AsyncSession,
    months: int = 6,
) -> list[dict[str, str | int | float]]:
    """Compute monthly cohort retention.

    Groups users by signup month, then checks how many were active
    (last_login_at) in each subsequent month.

    Returns list of {cohort_month, month_offset, retention_rate, user_count}.
    """
    now = datetime.now(timezone.utc)
    results: list[dict[str, str | int | float]] = []

    for month_back in range(months, 0, -1):
        # Compute cohort start/end
        cohort_year = now.year
        cohort_month_num = now.month - month_back
        while cohort_month_num <= 0:
            cohort_month_num += 12
            cohort_year -= 1

        cohort_start = datetime(
            cohort_year, cohort_month_num, 1, tzinfo=timezone.utc,
        )
        if cohort_month_num == 12:
            cohort_end = datetime(
                cohort_year + 1, 1, 1, tzinfo=timezone.utc,
            )
        else:
            cohort_end = datetime(
                cohort_year, cohort_month_num + 1, 1, tzinfo=timezone.utc,
            )

        cohort_label = cohort_start.strftime("%Y-%m")

        # Get users who signed up in this cohort
        cohort_users_result = await db.execute(
            select(User.id, User.last_login_at).where(
                User.created_at >= cohort_start,
                User.created_at < cohort_end,
                User.is_active == True,  # noqa: E712
            )
        )
        cohort_users = cohort_users_result.all()
        cohort_size = len(cohort_users)

        if cohort_size == 0:
            continue

        # Month 0 is always 100%
        results.append({
            "cohort_month": cohort_label,
            "month_offset": 0,
            "retention_rate": 100.0,
            "user_count": cohort_size,
        })

        # Check retention for each subsequent month
        for offset in range(1, month_back + 1):
            check_month_num = cohort_month_num + offset
            check_year = cohort_year
            while check_month_num > 12:
                check_month_num -= 12
                check_year += 1

            check_start = datetime(
                check_year, check_month_num, 1, tzinfo=timezone.utc,
            )
            if check_month_num == 12:
                check_end = datetime(
                    check_year + 1, 1, 1, tzinfo=timezone.utc,
                )
            else:
                check_end = datetime(
                    check_year, check_month_num + 1, 1, tzinfo=timezone.utc,
                )

            # Don't check future months
            if check_start > now:
                break

            # Count users who logged in during the check month
            retained = 0
            for user_id, last_login in cohort_users:
                if last_login is not None:
                    login_dt = last_login
                    if login_dt.tzinfo is None:
                        login_dt = login_dt.replace(tzinfo=timezone.utc)
                    if check_start <= login_dt < check_end:
                        retained += 1

            rate = (retained / cohort_size) * 100.0 if cohort_size > 0 else 0.0

            results.append({
                "cohort_month": cohort_label,
                "month_offset": offset,
                "retention_rate": round(rate, 1),
                "user_count": retained,
            })

    return results


async def get_conversion_funnel(
    db: AsyncSession,
) -> list[dict[str, str | int | float]]:
    """Compute conversion funnel.

    Steps:
    1. Signed Up (all users)
    2. Onboarded (has any bank or email connection)
    3. Connected Bank (has a bank connection)
    4. Subscribed Pro (subscription_tier != 'free')

    Returns list of {name, count, conversion_rate}.
    """
    # Step 1: Total sign-ups
    total_result = await db.execute(
        select(func.count(User.id))
    )
    total_signups: int = total_result.scalar() or 0

    if total_signups == 0:
        return [
            {"name": "Signed Up", "count": 0, "conversion_rate": 0.0},
            {"name": "Onboarded", "count": 0, "conversion_rate": 0.0},
            {"name": "Connected Bank", "count": 0, "conversion_rate": 0.0},
            {"name": "Subscribed Pro", "count": 0, "conversion_rate": 0.0},
        ]

    # Step 2: Onboarded (has any connection - bank or email)
    users_with_bank = select(BankConnection.user_id).where(
        BankConnection.deleted_at.is_(None),
    ).distinct()
    users_with_email = select(EmailConnection.user_id).where(
        EmailConnection.deleted_at.is_(None),
    ).distinct()

    onboarded_result = await db.execute(
        select(func.count(User.id.distinct())).where(
            (User.id.in_(users_with_bank)) | (User.id.in_(users_with_email))
        )
    )
    onboarded: int = onboarded_result.scalar() or 0

    # Step 3: Connected Bank
    bank_connected_result = await db.execute(
        select(func.count(User.id.distinct())).where(
            User.id.in_(users_with_bank)
        )
    )
    bank_connected: int = bank_connected_result.scalar() or 0

    # Step 4: Subscribed Pro
    pro_result = await db.execute(
        select(func.count(User.id)).where(
            User.subscription_tier != "free",
        )
    )
    pro_subscribed: int = pro_result.scalar() or 0

    steps = [
        {"name": "Signed Up", "count": total_signups, "conversion_rate": 100.0},
        {
            "name": "Onboarded",
            "count": onboarded,
            "conversion_rate": round(
                (onboarded / total_signups) * 100.0, 1,
            ),
        },
        {
            "name": "Connected Bank",
            "count": bank_connected,
            "conversion_rate": round(
                (bank_connected / onboarded) * 100.0, 1,
            ) if onboarded > 0 else 0.0,
        },
        {
            "name": "Subscribed Pro",
            "count": pro_subscribed,
            "conversion_rate": round(
                (pro_subscribed / bank_connected) * 100.0, 1,
            ) if bank_connected > 0 else 0.0,
        },
    ]

    return steps


async def get_retention_curves(
    db: AsyncSession,
) -> list[dict[str, int | float]]:
    """Compute D1, D7, D14, D30, D60, D90 retention.

    For each checkpoint, counts how many users who signed up at least
    N days ago have a last_login_at >= (created_at + N days).

    Returns list of {day, retention_rate, user_count}.
    """
    now = datetime.now(timezone.utc)
    checkpoints = [1, 7, 14, 30, 60, 90]
    results: list[dict[str, int | float]] = []

    for day_n in checkpoints:
        cutoff = now - timedelta(days=day_n)

        # Users who signed up at least N days ago
        eligible_result = await db.execute(
            select(User.id, User.created_at, User.last_login_at).where(
                User.created_at <= cutoff,
                User.is_active == True,  # noqa: E712
            )
        )
        eligible_users = eligible_result.all()
        eligible_count = len(eligible_users)

        if eligible_count == 0:
            results.append({
                "day": day_n,
                "retention_rate": 0.0,
                "user_count": 0,
            })
            continue

        retained = 0
        for user_id, created_at, last_login_at in eligible_users:
            if last_login_at is None:
                continue
            created_dt = created_at
            login_dt = last_login_at
            if created_dt.tzinfo is None:
                created_dt = created_dt.replace(tzinfo=timezone.utc)
            if login_dt.tzinfo is None:
                login_dt = login_dt.replace(tzinfo=timezone.utc)

            threshold = created_dt + timedelta(days=day_n)
            if login_dt >= threshold:
                retained += 1

        rate = (retained / eligible_count) * 100.0
        results.append({
            "day": day_n,
            "retention_rate": round(rate, 1),
            "user_count": retained,
        })

    return results
