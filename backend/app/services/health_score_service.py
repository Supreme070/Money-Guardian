"""Customer health score service.

Computes a 0-100 health score for each user based on engagement signals.
Scores are stored as daily snapshots for trend analysis.

Score components:
- Login recency (0-20)
- Feature engagement (0-20)
- Subscription utilization (0-20)
- Alert responsiveness (0-15)
- Connection health (0-15)
- Tier value (0-10)
"""

import logging
from datetime import date, datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import Date, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.alert import Alert
from app.models.bank_connection import BankConnection
from app.models.customer_health import CustomerHealthSnapshot
from app.models.email_connection import EmailConnection
from app.models.subscription import Subscription
from app.models.user import User

logger = logging.getLogger(__name__)

# Tier limits for subscription utilization scoring
_TIER_SUB_LIMITS: dict[str, int] = {
    "free": 5,
    "pro": 50,
    "enterprise": 200,
}


def _risk_level(score: int) -> str:
    """Map score to risk level."""
    if score > 70:
        return "healthy"
    if score >= 40:
        return "at_risk"
    return "churning"


async def compute_health_score(
    db: AsyncSession,
    user: User,
) -> dict[str, int | float | str]:
    """Compute health score for a single user.

    Returns dict with keys: score, risk_level, factors (nested dict of
    component scores).
    """
    now = datetime.now(timezone.utc)
    factors: dict[str, int | float | str] = {}

    # -----------------------------------------------------------------------
    # 1. Login recency (0-20)
    # -----------------------------------------------------------------------
    login_score = 0
    if user.last_login_at is not None:
        last_login = user.last_login_at
        if last_login.tzinfo is None:
            last_login = last_login.replace(tzinfo=timezone.utc)
        days_since = (now - last_login).days
        if days_since <= 0:
            login_score = 20
        elif days_since >= 10:
            login_score = 0
        else:
            login_score = max(0, 20 - (days_since * 2))
    factors["login_recency"] = login_score

    # -----------------------------------------------------------------------
    # 2. Feature engagement (0-20): subscription count + connection count
    # -----------------------------------------------------------------------
    sub_count_result = await db.execute(
        select(func.count(Subscription.id)).where(
            Subscription.user_id == user.id,
            Subscription.deleted_at.is_(None),
            Subscription.is_active == True,  # noqa: E712
        )
    )
    sub_count: int = sub_count_result.scalar() or 0

    conn_count_result = await db.execute(
        select(func.count(BankConnection.id)).where(
            BankConnection.user_id == user.id,
            BankConnection.deleted_at.is_(None),
        )
    )
    conn_count: int = conn_count_result.scalar() or 0

    email_conn_result = await db.execute(
        select(func.count(EmailConnection.id)).where(
            EmailConnection.user_id == user.id,
            EmailConnection.deleted_at.is_(None),
        )
    )
    email_conn_count: int = email_conn_result.scalar() or 0

    total_connections = conn_count + email_conn_count
    # Score: up to 10 for subs (capped at 5+), up to 10 for connections (capped at 2+)
    engagement_sub = min(10, sub_count * 2)
    engagement_conn = min(10, total_connections * 5)
    engagement_score = engagement_sub + engagement_conn
    factors["feature_engagement"] = engagement_score

    # -----------------------------------------------------------------------
    # 3. Subscription utilization (0-20): active subs vs tier max
    # -----------------------------------------------------------------------
    tier_max = _TIER_SUB_LIMITS.get(user.subscription_tier, 5)
    utilization = sub_count / tier_max if tier_max > 0 else 0.0
    utilization_score = min(20, int(utilization * 20))
    factors["subscription_utilization"] = utilization_score

    # -----------------------------------------------------------------------
    # 4. Alert responsiveness (0-15): ratio of read/dismissed alerts
    # -----------------------------------------------------------------------
    total_alerts_result = await db.execute(
        select(func.count(Alert.id)).where(
            Alert.user_id == user.id,
        )
    )
    total_alerts: int = total_alerts_result.scalar() or 0

    responded_alerts_result = await db.execute(
        select(func.count(Alert.id)).where(
            Alert.user_id == user.id,
            (Alert.is_read == True) | (Alert.is_dismissed == True),  # noqa: E712
        )
    )
    responded_alerts: int = responded_alerts_result.scalar() or 0

    if total_alerts > 0:
        alert_ratio = responded_alerts / total_alerts
        alert_score = int(alert_ratio * 15)
    else:
        # No alerts = neutral (give half credit)
        alert_score = 8
    factors["alert_responsiveness"] = alert_score

    # -----------------------------------------------------------------------
    # 5. Connection health (0-15): percentage of connections in "connected"
    # -----------------------------------------------------------------------
    connected_bank_result = await db.execute(
        select(func.count(BankConnection.id)).where(
            BankConnection.user_id == user.id,
            BankConnection.deleted_at.is_(None),
            BankConnection.status == "connected",
        )
    )
    connected_bank: int = connected_bank_result.scalar() or 0

    connected_email_result = await db.execute(
        select(func.count(EmailConnection.id)).where(
            EmailConnection.user_id == user.id,
            EmailConnection.deleted_at.is_(None),
            EmailConnection.status == "connected",
        )
    )
    connected_email: int = connected_email_result.scalar() or 0

    total_conns = conn_count + email_conn_count
    connected_conns = connected_bank + connected_email
    if total_conns > 0:
        connection_ratio = connected_conns / total_conns
        connection_score = int(connection_ratio * 15)
    else:
        # No connections = neutral
        connection_score = 5
    factors["connection_health"] = connection_score

    # -----------------------------------------------------------------------
    # 6. Tier value (0-10)
    # -----------------------------------------------------------------------
    tier_scores: dict[str, int] = {
        "free": 2,
        "pro": 6,
        "enterprise": 10,
    }
    tier_score = tier_scores.get(user.subscription_tier, 2)
    factors["tier_value"] = tier_score

    # -----------------------------------------------------------------------
    # Total
    # -----------------------------------------------------------------------
    total = (
        login_score
        + engagement_score
        + utilization_score
        + alert_score
        + connection_score
        + tier_score
    )
    total = max(0, min(100, total))

    factors["score"] = total
    factors["risk_level"] = _risk_level(total)

    return factors


async def compute_all_scores(db: AsyncSession) -> int:
    """Compute health scores for all active users and store snapshots.

    Returns the number of scores computed.
    """
    today = date.today()
    count = 0

    result = await db.execute(
        select(User).where(User.is_active == True)  # noqa: E712
    )
    users = result.scalars().all()

    for user in users:
        try:
            factors = await compute_health_score(db, user)
            score = int(factors["score"])
            risk = str(factors["risk_level"])

            # Upsert: delete existing snapshot for today, then insert
            existing = await db.execute(
                select(CustomerHealthSnapshot).where(
                    CustomerHealthSnapshot.user_id == user.id,
                    CustomerHealthSnapshot.snapshot_date == today,
                )
            )
            old = existing.scalar_one_or_none()
            if old is not None:
                await db.delete(old)
                await db.flush()

            snapshot = CustomerHealthSnapshot(
                user_id=user.id,
                tenant_id=user.tenant_id,
                score=score,
                risk_level=risk,
                factors=factors,
                snapshot_date=today,
            )
            db.add(snapshot)
            count += 1

        except Exception:
            logger.exception(
                "Failed to compute health score for user %s", user.id,
            )
            continue

    await db.flush()
    logger.info("Computed health scores for %d users", count)
    return count


async def get_health_scores(
    db: AsyncSession,
    *,
    page: int = 1,
    page_size: int = 20,
    risk_level: str | None = None,
    min_score: int | None = None,
    max_score: int | None = None,
) -> tuple[list[CustomerHealthSnapshot], int]:
    """Get paginated health scores (latest snapshot per user).

    Returns (snapshots, total_count).
    """
    # Get the latest snapshot date
    latest_date_result = await db.execute(
        select(func.max(CustomerHealthSnapshot.snapshot_date))
    )
    latest_date = latest_date_result.scalar()
    if latest_date is None:
        return [], 0

    query = select(CustomerHealthSnapshot).where(
        CustomerHealthSnapshot.snapshot_date == latest_date,
    )
    count_query = select(func.count(CustomerHealthSnapshot.id)).where(
        CustomerHealthSnapshot.snapshot_date == latest_date,
    )

    if risk_level is not None:
        query = query.where(CustomerHealthSnapshot.risk_level == risk_level)
        count_query = count_query.where(
            CustomerHealthSnapshot.risk_level == risk_level,
        )
    if min_score is not None:
        query = query.where(CustomerHealthSnapshot.score >= min_score)
        count_query = count_query.where(
            CustomerHealthSnapshot.score >= min_score,
        )
    if max_score is not None:
        query = query.where(CustomerHealthSnapshot.score <= max_score)
        count_query = count_query.where(
            CustomerHealthSnapshot.score <= max_score,
        )

    total: int = (await db.execute(count_query)).scalar() or 0

    offset = (page - 1) * page_size
    query = query.order_by(
        CustomerHealthSnapshot.score.asc(),
    ).offset(offset).limit(page_size)

    result = await db.execute(query)
    snapshots = list(result.scalars().all())

    return snapshots, total


async def get_user_health_history(
    db: AsyncSession,
    user_id: UUID,
    days: int = 90,
) -> list[CustomerHealthSnapshot]:
    """Get health score history for a specific user."""
    cutoff = date.today() - timedelta(days=days)

    result = await db.execute(
        select(CustomerHealthSnapshot).where(
            CustomerHealthSnapshot.user_id == user_id,
            CustomerHealthSnapshot.snapshot_date >= cutoff,
        ).order_by(CustomerHealthSnapshot.snapshot_date.desc())
    )
    return list(result.scalars().all())
