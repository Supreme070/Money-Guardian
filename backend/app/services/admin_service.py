"""Admin service for analytics, user management, and monitoring.

Cross-tenant queries are intentional here — admin endpoints need
platform-wide visibility.  Protected by X-Admin-Key at the API layer.
"""

import logging
import time
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.cache import _get_redis
from app.core.config import settings
from app.models.alert import Alert
from app.models.bank_connection import BankConnection
from app.models.email_connection import EmailConnection
from app.models.subscription import Subscription
from app.models.tenant import Tenant
from app.models.user import User
from app.schemas.admin import (
    AdminAlertItem,
    AdminBankConnectionItem,
    AdminEmailConnectionItem,
    AdminSubscriptionItem,
    AdminTenantDetailResponse,
    AdminTenantListItem,
    AdminUserConnectionsResponse,
    AdminUserDetailResponse,
    AdminUserListItem,
    AnalyticsOverviewResponse,
    CeleryStatusResponse,
    CeleryTaskInfo,
    ConnectionAnalyticsResponse,
    ErrorLogEntry,
    ErrorLogResponse,
    PaginatedTenantsResponse,
    PaginatedUsersResponse,
    PaginationMeta,
    ProviderStat,
    RevenueAnalyticsResponse,
    ServiceStatus,
    SignupAnalyticsResponse,
    SignupDataPoint,
    SubscriptionAnalyticsResponse,
    SystemHealthDetailResponse,
    TenantStatusUpdate,
    TenantStatusUpdateResponse,
    TopMerchant,
    UserStatusUpdate,
    UserStatusUpdateResponse,
)

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _pagination_meta(page: int, page_size: int, total: int) -> PaginationMeta:
    return PaginationMeta(
        page=page,
        page_size=page_size,
        total_count=total,
        total_pages=max(1, (total + page_size - 1) // page_size),
    )


def _normalize_to_monthly(amount: Decimal, cycle: str) -> Decimal:
    """Convert any billing cycle amount to its monthly equivalent."""
    multipliers: dict[str, Decimal] = {
        "weekly": Decimal("4.33"),
        "monthly": Decimal("1"),
        "quarterly": Decimal("1") / Decimal("3"),
        "yearly": Decimal("1") / Decimal("12"),
    }
    return amount * multipliers.get(cycle, Decimal("1"))


# ---------------------------------------------------------------------------
# User Management
# ---------------------------------------------------------------------------


async def list_users(
    db: AsyncSession,
    *,
    page: int = 1,
    page_size: int = 20,
    search: str | None = None,
    tier_filter: str | None = None,
    status_filter: bool | None = None,
) -> PaginatedUsersResponse:
    """Paginated user list with optional search and filters."""

    # Base query with tenant join for tier
    base = (
        select(
            User.id,
            User.email,
            User.full_name,
            User.tenant_id,
            Tenant.tier,
            User.is_active,
            User.is_verified,
            User.created_at,
            User.last_login_at,
        )
        .join(Tenant, User.tenant_id == Tenant.id)
    )

    if search:
        pattern = f"%{search}%"
        base = base.where(
            (User.email.ilike(pattern)) | (User.full_name.ilike(pattern))
        )
    if tier_filter:
        base = base.where(Tenant.tier == tier_filter)
    if status_filter is not None:
        base = base.where(User.is_active == status_filter)

    # Count
    count_q = select(func.count()).select_from(base.subquery())
    total = (await db.execute(count_q)).scalar() or 0

    # Paginated rows
    rows = (
        await db.execute(
            base.order_by(User.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
    ).all()

    # Batch-fetch subscription/connection counts for these users
    user_ids = [r.id for r in rows]
    sub_counts = await _count_by_user(db, Subscription, user_ids)
    conn_counts = await _count_connections_by_user(db, user_ids)

    users = [
        AdminUserListItem(
            id=r.id,
            email=r.email,
            full_name=r.full_name,
            tenant_id=r.tenant_id,
            tier=r.tier,
            is_active=r.is_active,
            is_verified=r.is_verified,
            subscription_count=sub_counts.get(r.id, 0),
            connection_count=conn_counts.get(r.id, 0),
            created_at=r.created_at,
            last_login_at=r.last_login_at,
        )
        for r in rows
    ]

    return PaginatedUsersResponse(
        users=users,
        pagination=_pagination_meta(page, page_size, total),
    )


async def get_user_detail(db: AsyncSession, user_id: UUID) -> AdminUserDetailResponse:
    """Full user detail."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise UserNotFoundError(user_id)

    tenant_result = await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    tenant = tenant_result.scalar_one_or_none()

    # Counts
    sub_count = (
        await db.execute(
            select(func.count(Subscription.id)).where(
                Subscription.user_id == user_id,
                Subscription.deleted_at.is_(None),
            )
        )
    ).scalar() or 0

    bank_count = (
        await db.execute(
            select(func.count(BankConnection.id)).where(
                BankConnection.user_id == user_id,
                BankConnection.deleted_at.is_(None),
            )
        )
    ).scalar() or 0

    email_count = (
        await db.execute(
            select(func.count(EmailConnection.id)).where(
                EmailConnection.user_id == user_id,
                EmailConnection.deleted_at.is_(None),
            )
        )
    ).scalar() or 0

    alert_count = (
        await db.execute(
            select(func.count(Alert.id)).where(Alert.user_id == user_id)
        )
    ).scalar() or 0

    unread_count = (
        await db.execute(
            select(func.count(Alert.id)).where(
                Alert.user_id == user_id,
                Alert.is_read == False,  # noqa: E712
                Alert.is_dismissed == False,  # noqa: E712
            )
        )
    ).scalar() or 0

    return AdminUserDetailResponse(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        tenant_id=user.tenant_id,
        tier=tenant.tier if tenant else "free",
        is_active=user.is_active,
        is_verified=user.is_verified,
        push_notifications_enabled=user.push_notifications_enabled,
        email_notifications_enabled=user.email_notifications_enabled,
        subscription_tier=user.subscription_tier,
        subscription_expires_at=user.subscription_expires_at,
        onboarding_completed=user.onboarding_completed,
        created_at=user.created_at,
        updated_at=user.updated_at,
        last_login_at=user.last_login_at,
        subscription_count=sub_count,
        bank_connection_count=bank_count,
        email_connection_count=email_count,
        alert_count=alert_count,
        unread_alert_count=unread_count,
    )


async def update_user_status(
    db: AsyncSession, user_id: UUID, request: UserStatusUpdate
) -> UserStatusUpdateResponse:
    """Activate or deactivate a user."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise UserNotFoundError(user_id)

    user.is_active = request.is_active
    db.add(user)
    await db.commit()

    logger.info(
        "Admin user status update: user=%s active=%s reason=%s",
        user_id, request.is_active, request.reason,
    )

    return UserStatusUpdateResponse(
        user_id=user_id,
        is_active=request.is_active,
        reason=request.reason,
    )


async def get_user_subscriptions(
    db: AsyncSession, user_id: UUID
) -> list[AdminSubscriptionItem]:
    """Get all subscriptions for a user (admin cross-tenant view)."""
    result = await db.execute(
        select(Subscription)
        .where(Subscription.user_id == user_id, Subscription.deleted_at.is_(None))
        .order_by(Subscription.created_at.desc())
    )
    subs = result.scalars().all()
    return [
        AdminSubscriptionItem(
            id=s.id,
            name=s.name,
            amount=float(s.amount),
            currency=s.currency,
            billing_cycle=s.billing_cycle,
            is_active=s.is_active,
            is_paused=s.is_paused,
            ai_flag=s.ai_flag or "none",
            source=s.source or "manual",
            next_billing_date=s.next_billing_date,
            created_at=s.created_at,
        )
        for s in subs
    ]


async def get_user_alerts(
    db: AsyncSession, user_id: UUID
) -> list[AdminAlertItem]:
    """Get all alerts for a user (admin cross-tenant view)."""
    result = await db.execute(
        select(Alert)
        .where(Alert.user_id == user_id)
        .order_by(Alert.created_at.desc())
        .limit(100)
    )
    alerts = result.scalars().all()
    return [
        AdminAlertItem(
            id=a.id,
            alert_type=a.alert_type,
            severity=a.severity,
            title=a.title,
            message=a.message,
            amount=float(a.amount) if a.amount else None,
            is_read=a.is_read,
            is_dismissed=a.is_dismissed,
            created_at=a.created_at,
        )
        for a in alerts
    ]


async def get_user_connections(
    db: AsyncSession, user_id: UUID
) -> AdminUserConnectionsResponse:
    """Get bank + email connections for a user."""
    bank_result = await db.execute(
        select(BankConnection)
        .where(BankConnection.user_id == user_id, BankConnection.deleted_at.is_(None))
        .order_by(BankConnection.created_at.desc())
    )
    bank_conns = bank_result.scalars().all()

    email_result = await db.execute(
        select(EmailConnection)
        .where(EmailConnection.user_id == user_id, EmailConnection.deleted_at.is_(None))
        .order_by(EmailConnection.created_at.desc())
    )
    email_conns = email_result.scalars().all()

    return AdminUserConnectionsResponse(
        bank_connections=[
            AdminBankConnectionItem(
                id=bc.id,
                provider=bc.provider,
                institution_name=bc.institution_name or "Unknown",
                status=bc.status or "pending",
                error_code=bc.error_code,
                error_message=bc.error_message,
                last_sync_at=bc.last_sync_at,
                account_count=len(bc.accounts) if hasattr(bc, "accounts") and bc.accounts else 0,
                created_at=bc.created_at,
            )
            for bc in bank_conns
        ],
        email_connections=[
            AdminEmailConnectionItem(
                id=ec.id,
                provider=ec.provider,
                email_address=ec.email_address,
                status=ec.status or "pending",
                error_message=ec.error_message,
                last_scan_at=ec.last_scan_at,
                scanned_email_count=len(ec.scanned_emails) if hasattr(ec, "scanned_emails") and ec.scanned_emails else 0,
                created_at=ec.created_at,
            )
            for ec in email_conns
        ],
    )


# ---------------------------------------------------------------------------
# Tenant Management
# ---------------------------------------------------------------------------


async def list_tenants(
    db: AsyncSession,
    *,
    page: int = 1,
    page_size: int = 20,
    tier_filter: str | None = None,
    status_filter: str | None = None,
) -> PaginatedTenantsResponse:
    """Paginated tenant list."""
    base = select(Tenant)
    if tier_filter:
        base = base.where(Tenant.tier == tier_filter)
    if status_filter:
        base = base.where(Tenant.status == status_filter)

    count_q = select(func.count()).select_from(base.subquery())
    total = (await db.execute(count_q)).scalar() or 0

    rows = (
        await db.execute(
            base.order_by(Tenant.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
    ).scalars().all()

    tenant_ids = [t.id for t in rows]

    # Batch counts
    user_counts = await _count_by_tenant(db, User, tenant_ids)
    sub_counts = await _count_by_tenant(db, Subscription, tenant_ids, soft_delete=True)

    tenants = [
        AdminTenantListItem(
            id=t.id,
            name=t.name,
            tier=t.tier,
            status=t.status,
            user_count=user_counts.get(t.id, 0),
            subscription_count=sub_counts.get(t.id, 0),
            created_at=t.created_at,
        )
        for t in rows
    ]

    return PaginatedTenantsResponse(
        tenants=tenants,
        pagination=_pagination_meta(page, page_size, total),
    )


async def get_tenant_detail(db: AsyncSession, tenant_id: UUID) -> AdminTenantDetailResponse:
    """Full tenant detail."""
    result = await db.execute(select(Tenant).where(Tenant.id == tenant_id))
    tenant = result.scalar_one_or_none()
    if not tenant:
        raise TenantNotFoundError(tenant_id)

    user_count = (await db.execute(
        select(func.count(User.id)).where(User.tenant_id == tenant_id)
    )).scalar() or 0

    sub_count = (await db.execute(
        select(func.count(Subscription.id)).where(
            Subscription.tenant_id == tenant_id,
            Subscription.deleted_at.is_(None),
        )
    )).scalar() or 0

    bank_count = (await db.execute(
        select(func.count(BankConnection.id)).where(
            BankConnection.tenant_id == tenant_id,
            BankConnection.deleted_at.is_(None),
        )
    )).scalar() or 0

    email_count = (await db.execute(
        select(func.count(EmailConnection.id)).where(
            EmailConnection.tenant_id == tenant_id,
            EmailConnection.deleted_at.is_(None),
        )
    )).scalar() or 0

    return AdminTenantDetailResponse(
        id=tenant.id,
        name=tenant.name,
        tier=tenant.tier,
        status=tenant.status,
        stripe_customer_id=tenant.stripe_customer_id,
        user_count=user_count,
        subscription_count=sub_count,
        bank_connection_count=bank_count,
        email_connection_count=email_count,
        created_at=tenant.created_at,
        updated_at=tenant.updated_at,
    )


async def update_tenant_status(
    db: AsyncSession, tenant_id: UUID, request: TenantStatusUpdate
) -> TenantStatusUpdateResponse:
    """Change tenant status."""
    result = await db.execute(select(Tenant).where(Tenant.id == tenant_id))
    tenant = result.scalar_one_or_none()
    if not tenant:
        raise TenantNotFoundError(tenant_id)

    previous = tenant.status
    tenant.status = request.status
    db.add(tenant)
    await db.commit()

    logger.info(
        "Admin tenant status update: tenant=%s from=%s to=%s reason=%s",
        tenant_id, previous, request.status, request.reason,
    )

    return TenantStatusUpdateResponse(
        tenant_id=tenant_id,
        previous_status=previous,
        new_status=request.status,
        reason=request.reason,
    )


# ---------------------------------------------------------------------------
# Analytics
# ---------------------------------------------------------------------------


async def get_analytics_overview(db: AsyncSession) -> AnalyticsOverviewResponse:
    """High-level platform metrics."""
    now = datetime.now(timezone.utc)
    thirty_days_ago = now - timedelta(days=30)
    seven_days_ago = now - timedelta(days=7)

    total_users = (await db.execute(select(func.count(User.id)))).scalar() or 0
    active_30d = (await db.execute(
        select(func.count(User.id)).where(
            User.is_active == True,  # noqa: E712
            User.last_login_at >= thirty_days_ago,
        )
    )).scalar() or 0

    new_7d = (await db.execute(
        select(func.count(User.id)).where(User.created_at >= seven_days_ago)
    )).scalar() or 0

    new_30d = (await db.execute(
        select(func.count(User.id)).where(User.created_at >= thirty_days_ago)
    )).scalar() or 0

    # Tier counts via tenant
    tier_rows = (await db.execute(
        select(Tenant.tier, func.count(User.id))
        .join(User, User.tenant_id == Tenant.id)
        .group_by(Tenant.tier)
    )).all()
    tier_map: dict[str, int] = {r[0]: r[1] for r in tier_rows}

    pro_users = tier_map.get("pro", 0)
    enterprise_users = tier_map.get("enterprise", 0)
    free_users = tier_map.get("free", 0)
    paid_users = pro_users + enterprise_users
    conversion_rate = (paid_users / total_users * 100) if total_users > 0 else 0.0

    total_subs = (await db.execute(
        select(func.count(Subscription.id)).where(Subscription.deleted_at.is_(None))
    )).scalar() or 0

    total_bank = (await db.execute(
        select(func.count(BankConnection.id)).where(BankConnection.deleted_at.is_(None))
    )).scalar() or 0

    total_email = (await db.execute(
        select(func.count(EmailConnection.id)).where(EmailConnection.deleted_at.is_(None))
    )).scalar() or 0

    # Monthly tracked value
    sub_rows = (await db.execute(
        select(Subscription.amount, Subscription.billing_cycle).where(
            Subscription.deleted_at.is_(None),
            Subscription.is_active == True,  # noqa: E712
        )
    )).all()
    monthly_total = sum(
        float(_normalize_to_monthly(Decimal(str(r.amount)), r.billing_cycle))
        for r in sub_rows
    )

    return AnalyticsOverviewResponse(
        total_users=total_users,
        active_users_30d=active_30d,
        new_signups_7d=new_7d,
        new_signups_30d=new_30d,
        pro_users=pro_users,
        enterprise_users=enterprise_users,
        free_users=free_users,
        conversion_rate=round(conversion_rate, 2),
        total_subscriptions=total_subs,
        total_bank_connections=total_bank,
        total_email_connections=total_email,
        monthly_tracked_value=round(monthly_total, 2),
    )


async def get_signup_analytics(
    db: AsyncSession, period: str = "daily", days: int = 30
) -> SignupAnalyticsResponse:
    """Signup trends aggregated by day/week/month."""
    since = datetime.now(timezone.utc) - timedelta(days=days)

    # Fetch individual user creation dates and aggregate in Python
    # (avoids cast(Date) which is not portable across SQLite/PostgreSQL)
    user_rows = (await db.execute(
        select(User.created_at)
        .where(User.created_at >= since)
        .order_by(User.created_at)
    )).all()

    day_counts: dict[date, int] = {}
    for (created_at,) in user_rows:
        day = created_at.date() if hasattr(created_at, "date") else created_at
        day_counts[day] = day_counts.get(day, 0) + 1

    data_points = [
        SignupDataPoint(date=d, count=c)
        for d, c in sorted(day_counts.items())
    ]
    total = sum(dp.count for dp in data_points)

    return SignupAnalyticsResponse(
        period=period if period in ("daily", "weekly", "monthly") else "daily",
        data_points=data_points,
        total=total,
    )


async def get_subscription_analytics(db: AsyncSession) -> SubscriptionAnalyticsResponse:
    """Platform-wide subscription analytics."""
    active_subs = (await db.execute(
        select(Subscription).where(
            Subscription.deleted_at.is_(None),
            Subscription.is_active == True,  # noqa: E712
        )
    )).scalars().all()

    total_tracked = len(active_subs)
    total_users_with_subs = len(set(s.user_id for s in active_subs))
    avg_per_user = (total_tracked / total_users_with_subs) if total_users_with_subs > 0 else 0.0

    monthly_total = sum(
        float(_normalize_to_monthly(s.amount, s.billing_cycle)) for s in active_subs
    )
    yearly_total = monthly_total * 12

    # Top merchants
    merchant_map: dict[str, list[Subscription]] = {}
    for s in active_subs:
        merchant_map.setdefault(s.name, []).append(s)

    top_merchants = sorted(
        [
            TopMerchant(
                name=name,
                count=len(subs),
                total_monthly_value=round(
                    sum(float(_normalize_to_monthly(s.amount, s.billing_cycle)) for s in subs),
                    2,
                ),
            )
            for name, subs in merchant_map.items()
        ],
        key=lambda m: m.count,
        reverse=True,
    )[:20]

    # Flag distribution
    flag_dist: dict[str, int] = {}
    for s in active_subs:
        flag = s.ai_flag or "none"
        flag_dist[flag] = flag_dist.get(flag, 0) + 1

    # Source distribution
    source_dist: dict[str, int] = {}
    for s in active_subs:
        source = s.source or "manual"
        source_dist[source] = source_dist.get(source, 0) + 1

    return SubscriptionAnalyticsResponse(
        total_tracked=total_tracked,
        avg_per_user=round(avg_per_user, 2),
        total_monthly_value=round(monthly_total, 2),
        total_yearly_value=round(yearly_total, 2),
        top_merchants=top_merchants,
        flag_distribution=flag_dist,
        source_distribution=source_dist,
    )


async def get_connection_analytics(db: AsyncSession) -> ConnectionAnalyticsResponse:
    """Connection success rates by provider."""
    # Bank connections
    bank_rows = (await db.execute(
        select(
            BankConnection.provider,
            BankConnection.status,
            func.count(BankConnection.id).label("cnt"),
        )
        .where(BankConnection.deleted_at.is_(None))
        .group_by(BankConnection.provider, BankConnection.status)
    )).all()

    bank_providers = _aggregate_provider_stats(bank_rows)

    # Email connections
    email_rows = (await db.execute(
        select(
            EmailConnection.provider,
            EmailConnection.status,
            func.count(EmailConnection.id).label("cnt"),
        )
        .where(EmailConnection.deleted_at.is_(None))
        .group_by(EmailConnection.provider, EmailConnection.status)
    )).all()

    email_providers = _aggregate_provider_stats(email_rows)

    bank_total = sum(p.total for p in bank_providers)
    bank_connected = sum(p.connected for p in bank_providers)
    email_total = sum(p.total for p in email_providers)
    email_connected = sum(p.connected for p in email_providers)

    return ConnectionAnalyticsResponse(
        bank_providers=bank_providers,
        email_providers=email_providers,
        bank_success_rate=round(bank_connected / bank_total * 100, 2) if bank_total > 0 else 0.0,
        email_success_rate=round(email_connected / email_total * 100, 2) if email_total > 0 else 0.0,
    )


async def get_revenue_analytics(db: AsyncSession) -> RevenueAnalyticsResponse:
    """Revenue and tier analytics."""
    tier_rows = (await db.execute(
        select(Tenant.tier, func.count(User.id))
        .join(User, User.tenant_id == Tenant.id)
        .group_by(Tenant.tier)
    )).all()
    tier_breakdown = {r[0]: r[1] for r in tier_rows}

    total_paid = tier_breakdown.get("pro", 0) + tier_breakdown.get("enterprise", 0)

    # Churn: users whose subscription_tier was downgraded in last 30 days
    # (approximated by users on free tier who were created more than 30 days ago
    # and have subscription_expires_at in the last 30 days)
    thirty_days_ago = datetime.now(timezone.utc) - timedelta(days=30)
    churn_count = (await db.execute(
        select(func.count(User.id)).where(
            User.subscription_tier == "free",
            User.subscription_expires_at.isnot(None),
            User.subscription_expires_at >= thirty_days_ago,
        )
    )).scalar() or 0

    return RevenueAnalyticsResponse(
        tier_breakdown=tier_breakdown,
        total_paid_users=total_paid,
        churn_count_30d=churn_count,
    )


# ---------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------


async def get_system_health(db: AsyncSession) -> SystemHealthDetailResponse:
    """Check DB + Redis health with latency measurements."""
    services: list[ServiceStatus] = []

    # Database check
    try:
        start = time.monotonic()
        await db.execute(select(func.count(User.id)))
        db_latency = (time.monotonic() - start) * 1000
        services.append(ServiceStatus(
            name="PostgreSQL",
            status="healthy",
            latency_ms=round(db_latency, 2),
            error=None,
        ))
    except Exception as e:
        services.append(ServiceStatus(
            name="PostgreSQL",
            status="unhealthy",
            latency_ms=None,
            error=str(e),
        ))

    # Redis check
    try:
        redis = _get_redis()
        start = time.monotonic()
        await redis.ping()
        redis_latency = (time.monotonic() - start) * 1000
        services.append(ServiceStatus(
            name="Redis",
            status="healthy",
            latency_ms=round(redis_latency, 2),
            error=None,
        ))
    except Exception as e:
        services.append(ServiceStatus(
            name="Redis",
            status="unhealthy",
            latency_ms=None,
            error=str(e),
        ))

    unhealthy = [s for s in services if s.status == "unhealthy"]
    if len(unhealthy) == len(services):
        overall = "unhealthy"
    elif unhealthy:
        overall = "degraded"
    else:
        overall = "healthy"

    return SystemHealthDetailResponse(
        services=services,
        overall_status=overall,
    )


async def get_error_log(
    db: AsyncSession,
    *,
    page: int = 1,
    page_size: int = 20,
    entity_type: str | None = None,
) -> ErrorLogResponse:
    """Recent failed bank/email connections."""
    entries: list[ErrorLogEntry] = []

    # Bank connection errors
    if entity_type is None or entity_type == "bank_connection":
        bank_q = (
            select(BankConnection)
            .where(
                BankConnection.deleted_at.is_(None),
                BankConnection.status.in_(["error", "requires_reauth"]),
            )
            .order_by(BankConnection.updated_at.desc())
        )
        bank_errors = (await db.execute(bank_q)).scalars().all()

        for bc in bank_errors:
            entries.append(ErrorLogEntry(
                id=bc.id,
                entity_type="bank_connection",
                entity_id=bc.id,
                tenant_id=bc.tenant_id,
                provider=bc.provider,
                institution_or_email=bc.institution_name or "Unknown",
                error_code=bc.error_code,
                error_message=bc.error_message,
                status=bc.status or "error",
                last_attempt_at=bc.last_sync_at,
                created_at=bc.created_at,
            ))

    # Email connection errors
    if entity_type is None or entity_type == "email_connection":
        email_q = (
            select(EmailConnection)
            .where(
                EmailConnection.deleted_at.is_(None),
                EmailConnection.status.in_(["error", "requires_reauth"]),
            )
            .order_by(EmailConnection.updated_at.desc())
        )
        email_errors = (await db.execute(email_q)).scalars().all()

        for ec in email_errors:
            entries.append(ErrorLogEntry(
                id=ec.id,
                entity_type="email_connection",
                entity_id=ec.id,
                tenant_id=ec.tenant_id,
                provider=ec.provider,
                institution_or_email=ec.email_address,
                error_code=None,
                error_message=ec.error_message,
                status=ec.status or "error",
                last_attempt_at=ec.last_scan_at,
                created_at=ec.created_at,
            ))

    # Sort all entries by created_at desc
    entries.sort(key=lambda e: e.created_at, reverse=True)

    total = len(entries)
    start = (page - 1) * page_size
    end = start + page_size
    paginated = entries[start:end]

    return ErrorLogResponse(
        errors=paginated,
        pagination=_pagination_meta(page, page_size, total),
    )


async def get_celery_status() -> CeleryStatusResponse:
    """Return Celery scheduled task metadata (static config, not live state)."""
    tasks = [
        CeleryTaskInfo(
            name="sync_all_bank_transactions",
            schedule="every 4 hours",
            last_run=None,
            description="Sync transactions from all connected bank accounts via Plaid/Mono/Stitch",
        ),
        CeleryTaskInfo(
            name="sync_all_bank_balances",
            schedule="every 1 hour",
            last_run=None,
            description="Refresh account balances for Daily Pulse calculations",
        ),
        CeleryTaskInfo(
            name="scan_all_emails",
            schedule="every 24 hours",
            last_run=None,
            description="Scan connected email accounts for subscription receipts",
        ),
        CeleryTaskInfo(
            name="send_upcoming_charge_notifications",
            schedule="every 6 hours",
            last_run=None,
            description="Send push/email alerts for upcoming subscription charges",
        ),
        CeleryTaskInfo(
            name="check_overdraft_risk",
            schedule="every 12 hours",
            last_run=None,
            description="Analyze balances vs upcoming charges for overdraft warnings",
        ),
    ]

    return CeleryStatusResponse(scheduled_tasks=tasks)


# ---------------------------------------------------------------------------
# Batch query helpers
# ---------------------------------------------------------------------------


async def _count_by_user(
    db: AsyncSession, model: type, user_ids: list[UUID]
) -> dict[UUID, int]:
    """Count rows per user_id for a model with soft-delete."""
    if not user_ids:
        return {}
    q = (
        select(model.user_id, func.count(model.id))
        .where(model.user_id.in_(user_ids))
    )
    if hasattr(model, "deleted_at"):
        q = q.where(model.deleted_at.is_(None))
    q = q.group_by(model.user_id)
    rows = (await db.execute(q)).all()
    return {r[0]: r[1] for r in rows}


async def _count_connections_by_user(
    db: AsyncSession, user_ids: list[UUID]
) -> dict[UUID, int]:
    """Count bank + email connections per user."""
    if not user_ids:
        return {}

    bank_q = (
        select(BankConnection.user_id, func.count(BankConnection.id))
        .where(BankConnection.user_id.in_(user_ids), BankConnection.deleted_at.is_(None))
        .group_by(BankConnection.user_id)
    )
    bank_rows = (await db.execute(bank_q)).all()

    email_q = (
        select(EmailConnection.user_id, func.count(EmailConnection.id))
        .where(EmailConnection.user_id.in_(user_ids), EmailConnection.deleted_at.is_(None))
        .group_by(EmailConnection.user_id)
    )
    email_rows = (await db.execute(email_q)).all()

    result: dict[UUID, int] = {}
    for uid, cnt in bank_rows:
        result[uid] = result.get(uid, 0) + cnt
    for uid, cnt in email_rows:
        result[uid] = result.get(uid, 0) + cnt
    return result


async def _count_by_tenant(
    db: AsyncSession,
    model: type,
    tenant_ids: list[UUID],
    *,
    soft_delete: bool = False,
) -> dict[UUID, int]:
    """Count rows per tenant_id."""
    if not tenant_ids:
        return {}
    q = (
        select(model.tenant_id, func.count(model.id))
        .where(model.tenant_id.in_(tenant_ids))
    )
    if soft_delete and hasattr(model, "deleted_at"):
        q = q.where(model.deleted_at.is_(None))
    q = q.group_by(model.tenant_id)
    rows = (await db.execute(q)).all()
    return {r[0]: r[1] for r in rows}


def _aggregate_provider_stats(
    rows: list[tuple[str, str, int]],
) -> list[ProviderStat]:
    """Aggregate provider/status/count rows into ProviderStat list."""
    provider_map: dict[str, dict[str, int]] = {}
    for provider, conn_status, count in rows:
        if provider not in provider_map:
            provider_map[provider] = {"total": 0, "connected": 0, "error": 0, "requires_reauth": 0}
        provider_map[provider]["total"] += count
        if conn_status == "connected":
            provider_map[provider]["connected"] += count
        elif conn_status == "error":
            provider_map[provider]["error"] += count
        elif conn_status == "requires_reauth":
            provider_map[provider]["requires_reauth"] += count

    return [
        ProviderStat(
            provider=provider,
            total=stats["total"],
            connected=stats["connected"],
            error=stats["error"],
            requires_reauth=stats["requires_reauth"],
        )
        for provider, stats in sorted(provider_map.items())
    ]


# ---------------------------------------------------------------------------
# Exceptions
# ---------------------------------------------------------------------------


class UserNotFoundError(Exception):
    def __init__(self, user_id: UUID) -> None:
        super().__init__(f"User {user_id} not found")
        self.user_id = user_id


class TenantNotFoundError(Exception):
    def __init__(self, tenant_id: UUID) -> None:
        super().__init__(f"Tenant {tenant_id} not found")
        self.tenant_id = tenant_id
