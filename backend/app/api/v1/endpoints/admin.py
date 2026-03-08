"""Internal admin endpoints for the admin portal.

Protected by ``X-Admin-Key`` header.  Not exposed to the mobile app.
Intended for the React admin dashboard at admin.moneyguardian.com.
"""

import logging
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.rate_limit import limiter
from app.db.session import get_db
from app.models.tenant import Tenant
from app.models.user import User
from app.schemas.admin import (
    AdminAlertItem,
    AdminSubscriptionItem,
    AdminTenantDetailResponse,
    AdminUserConnectionsResponse,
    AdminUserDetailResponse,
    AnalyticsOverviewResponse,
    CeleryStatusResponse,
    ConnectionAnalyticsResponse,
    ErrorLogResponse,
    PaginatedTenantsResponse,
    PaginatedUsersResponse,
    RevenueAnalyticsResponse,
    SignupAnalyticsResponse,
    SubscriptionAnalyticsResponse,
    SystemHealthDetailResponse,
    TenantStatusUpdate,
    TenantStatusUpdateResponse,
    UserStatusUpdate,
    UserStatusUpdateResponse,
)
from app.services.admin_service import (
    TenantNotFoundError,
    UserNotFoundError,
    get_analytics_overview,
    get_celery_status,
    get_connection_analytics,
    get_error_log,
    get_revenue_analytics,
    get_signup_analytics,
    get_subscription_analytics,
    get_system_health,
    get_tenant_detail,
    get_user_alerts,
    get_user_connections,
    get_user_detail,
    get_user_subscriptions,
    list_tenants,
    list_users,
    update_tenant_status,
    update_user_status,
)

logger = logging.getLogger(__name__)

router = APIRouter()


# ---------------------------------------------------------------------------
# Admin auth dependency
# ---------------------------------------------------------------------------


async def verify_admin_key(
    x_admin_key: str = Header(..., alias="X-Admin-Key"),
) -> str:
    """Verify admin API key from request header."""
    if not settings.admin_api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Admin API not configured",
        )
    if x_admin_key != settings.admin_api_key:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid admin key",
        )
    return x_admin_key


# ---------------------------------------------------------------------------
# Legacy inline schemas (kept for backward compatibility)
# ---------------------------------------------------------------------------


class AdminUserResponse(BaseModel):
    """Admin view of a user (legacy lookup endpoint)."""

    id: str
    email: str
    full_name: str | None
    tenant_id: str
    tier: str
    is_active: bool
    is_email_verified: bool
    created_at: str  # ISO string for legacy compat
    last_login_at: str | None


class TierOverrideRequest(BaseModel):
    """Request to override a tenant's tier."""

    tier: Literal["free", "pro", "enterprise"]
    reason: str = Field(..., min_length=3, max_length=500)


class TierOverrideResponse(BaseModel):
    """Response after tier override."""

    tenant_id: str
    previous_tier: str
    new_tier: str


class SystemStatsResponse(BaseModel):
    """System-wide statistics."""

    total_users: int
    active_users: int
    total_tenants: int
    tier_breakdown: dict[str, int]
    total_subscriptions: int
    total_bank_connections: int
    connected_bank_connections: int


class ConnectionHealthResponse(BaseModel):
    """Bank connection health summary."""

    total_connections: int
    connected: int
    error: int
    requires_reauth: int
    disconnected: int
    pending: int
    error_connections: list[dict[str, str]]


# ---------------------------------------------------------------------------
# Legacy endpoints (kept for backward compatibility)
# ---------------------------------------------------------------------------


@router.get("/users/lookup", response_model=AdminUserResponse)
@limiter.limit("5/minute")
async def admin_lookup_user(
    request: Request,
    email: str,
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> AdminUserResponse:
    """Look up a user by email address."""
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    tenant_result = await db.execute(
        select(Tenant).where(Tenant.id == user.tenant_id)
    )
    tenant = tenant_result.scalar_one_or_none()

    return AdminUserResponse(
        id=str(user.id),
        email=user.email,
        full_name=user.full_name,
        tenant_id=str(user.tenant_id),
        tier=tenant.tier if tenant else "free",
        is_active=user.is_active,
        is_email_verified=user.is_verified,
        created_at=user.created_at.isoformat(),
        last_login_at=user.last_login_at.isoformat() if user.last_login_at else None,
    )


@router.post("/tenants/{tenant_id}/tier", response_model=TierOverrideResponse)
@limiter.limit("5/minute")
async def admin_override_tier(
    request: Request,
    tenant_id: UUID,
    body: TierOverrideRequest = ...,
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> TierOverrideResponse:
    """Override a tenant's subscription tier."""
    result = await db.execute(select(Tenant).where(Tenant.id == tenant_id))
    tenant = result.scalar_one_or_none()

    if not tenant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tenant not found",
        )

    previous_tier = tenant.tier
    tenant.tier = body.tier
    db.add(tenant)
    await db.commit()

    logger.info(
        "Admin tier override: tenant=%s from=%s to=%s reason=%s",
        tenant_id, previous_tier, body.tier, body.reason,
    )

    return TierOverrideResponse(
        tenant_id=str(tenant_id),
        previous_tier=previous_tier,
        new_tier=body.tier,
    )


@router.get("/stats", response_model=SystemStatsResponse)
@limiter.limit("5/minute")
async def admin_system_stats(
    request: Request,
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> SystemStatsResponse:
    """Get system-wide statistics (legacy)."""
    from sqlalchemy import func

    from app.models.bank_connection import BankConnection
    from app.models.subscription import Subscription

    total_users = (await db.execute(select(func.count(User.id)))).scalar() or 0
    active_users = (await db.execute(
        select(func.count(User.id)).where(User.is_active == True)  # noqa: E712
    )).scalar() or 0
    total_tenants = (await db.execute(select(func.count(Tenant.id)))).scalar() or 0

    tier_rows = await db.execute(
        select(Tenant.tier, func.count(Tenant.id)).group_by(Tenant.tier)
    )
    tier_breakdown: dict[str, int] = {row[0]: row[1] for row in tier_rows.all()}

    total_subs = (await db.execute(
        select(func.count(Subscription.id)).where(Subscription.deleted_at.is_(None))
    )).scalar() or 0

    total_bank = (await db.execute(
        select(func.count(BankConnection.id)).where(BankConnection.deleted_at.is_(None))
    )).scalar() or 0

    connected_bank = (await db.execute(
        select(func.count(BankConnection.id)).where(
            BankConnection.deleted_at.is_(None),
            BankConnection.status == "connected",
        )
    )).scalar() or 0

    return SystemStatsResponse(
        total_users=total_users,
        active_users=active_users,
        total_tenants=total_tenants,
        tier_breakdown=tier_breakdown,
        total_subscriptions=total_subs,
        total_bank_connections=total_bank,
        connected_bank_connections=connected_bank,
    )


@router.get("/connections/health", response_model=ConnectionHealthResponse)
@limiter.limit("5/minute")
async def admin_connection_health(
    request: Request,
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> ConnectionHealthResponse:
    """Get bank connection health overview (legacy)."""
    from app.models.bank_connection import BankConnection

    active_conns = await db.execute(
        select(BankConnection).where(BankConnection.deleted_at.is_(None))
    )
    connections = active_conns.scalars().all()

    status_counts: dict[str, int] = {
        "connected": 0, "error": 0, "requires_reauth": 0,
        "disconnected": 0, "pending": 0,
    }
    error_list: list[dict[str, str]] = []

    for conn in connections:
        conn_status = conn.status or "pending"
        if conn_status in status_counts:
            status_counts[conn_status] += 1
        else:
            status_counts["pending"] += 1

        if conn_status in ("error", "requires_reauth"):
            error_list.append({
                "connection_id": str(conn.id),
                "tenant_id": str(conn.tenant_id),
                "institution": conn.institution_name or "Unknown",
                "status": conn_status,
                "error_code": conn.error_code or "",
                "error_message": conn.error_message or "",
            })

    return ConnectionHealthResponse(
        total_connections=len(connections),
        connected=status_counts["connected"],
        error=status_counts["error"],
        requires_reauth=status_counts["requires_reauth"],
        disconnected=status_counts["disconnected"],
        pending=status_counts["pending"],
        error_connections=error_list,
    )


# ===========================================================================
# NEW ADMIN PORTAL ENDPOINTS
# ===========================================================================


# ---------------------------------------------------------------------------
# User Management
# ---------------------------------------------------------------------------


@router.get("/users", response_model=PaginatedUsersResponse)
@limiter.limit("5/minute")
async def admin_list_users(
    request: Request,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    search: str | None = Query(default=None, max_length=255),
    tier: str | None = Query(default=None),
    is_active: bool | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> PaginatedUsersResponse:
    """Paginated user list with search and filters."""
    return await list_users(
        db, page=page, page_size=page_size,
        search=search, tier_filter=tier, status_filter=is_active,
    )


@router.get("/users/{user_id}", response_model=AdminUserDetailResponse)
@limiter.limit("5/minute")
async def admin_get_user(
    request: Request,
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> AdminUserDetailResponse:
    """Full user detail view."""
    try:
        return await get_user_detail(db, user_id)
    except UserNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )


@router.put("/users/{user_id}/status", response_model=UserStatusUpdateResponse)
@limiter.limit("5/minute")
async def admin_update_user_status(
    request: Request,
    user_id: UUID,
    body: UserStatusUpdate = ...,
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> UserStatusUpdateResponse:
    """Activate or deactivate a user."""
    try:
        return await update_user_status(db, user_id, body)
    except UserNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )


@router.get("/users/{user_id}/subscriptions", response_model=list[AdminSubscriptionItem])
@limiter.limit("5/minute")
async def admin_get_user_subscriptions(
    request: Request,
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> list[AdminSubscriptionItem]:
    """Get all subscriptions for a specific user."""
    return await get_user_subscriptions(db, user_id)


@router.get("/users/{user_id}/alerts", response_model=list[AdminAlertItem])
@limiter.limit("5/minute")
async def admin_get_user_alerts(
    request: Request,
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> list[AdminAlertItem]:
    """Get all alerts for a specific user."""
    return await get_user_alerts(db, user_id)


@router.get("/users/{user_id}/connections", response_model=AdminUserConnectionsResponse)
@limiter.limit("5/minute")
async def admin_get_user_connections(
    request: Request,
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> AdminUserConnectionsResponse:
    """Get bank + email connections for a specific user."""
    return await get_user_connections(db, user_id)


# ---------------------------------------------------------------------------
# Tenant Management
# ---------------------------------------------------------------------------


@router.get("/tenants", response_model=PaginatedTenantsResponse)
@limiter.limit("5/minute")
async def admin_list_tenants(
    request: Request,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    tier: str | None = Query(default=None),
    tenant_status: str | None = Query(default=None, alias="status"),
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> PaginatedTenantsResponse:
    """Paginated tenant list with filters."""
    return await list_tenants(
        db, page=page, page_size=page_size,
        tier_filter=tier, status_filter=tenant_status,
    )


@router.get("/tenants/{tenant_id}", response_model=AdminTenantDetailResponse)
@limiter.limit("5/minute")
async def admin_get_tenant(
    request: Request,
    tenant_id: UUID,
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> AdminTenantDetailResponse:
    """Full tenant detail view."""
    try:
        return await get_tenant_detail(db, tenant_id)
    except TenantNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tenant not found",
        )


@router.put("/tenants/{tenant_id}/status", response_model=TenantStatusUpdateResponse)
@limiter.limit("5/minute")
async def admin_update_tenant_status(
    request: Request,
    tenant_id: UUID,
    body: TenantStatusUpdate = ...,
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> TenantStatusUpdateResponse:
    """Change tenant status (active/suspended/deleted)."""
    try:
        return await update_tenant_status(db, tenant_id, body)
    except TenantNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tenant not found",
        )


# ---------------------------------------------------------------------------
# Analytics
# ---------------------------------------------------------------------------


@router.get("/analytics/overview", response_model=AnalyticsOverviewResponse)
@limiter.limit("5/minute")
async def admin_analytics_overview(
    request: Request,
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> AnalyticsOverviewResponse:
    """High-level platform metrics for the dashboard."""
    return await get_analytics_overview(db)


@router.get("/analytics/signups", response_model=SignupAnalyticsResponse)
@limiter.limit("5/minute")
async def admin_analytics_signups(
    request: Request,
    period: str = Query(default="daily"),
    days: int = Query(default=30, ge=7, le=365),
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> SignupAnalyticsResponse:
    """Signup trends over time."""
    return await get_signup_analytics(db, period=period, days=days)


@router.get("/analytics/subscriptions", response_model=SubscriptionAnalyticsResponse)
@limiter.limit("5/minute")
async def admin_analytics_subscriptions(
    request: Request,
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> SubscriptionAnalyticsResponse:
    """Platform-wide subscription analytics."""
    return await get_subscription_analytics(db)


@router.get("/analytics/connections", response_model=ConnectionAnalyticsResponse)
@limiter.limit("5/minute")
async def admin_analytics_connections(
    request: Request,
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> ConnectionAnalyticsResponse:
    """Bank + email connection analytics."""
    return await get_connection_analytics(db)


@router.get("/analytics/revenue", response_model=RevenueAnalyticsResponse)
@limiter.limit("5/minute")
async def admin_analytics_revenue(
    request: Request,
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> RevenueAnalyticsResponse:
    """Revenue and tier analytics."""
    return await get_revenue_analytics(db)


# ---------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------


@router.get("/monitoring/health", response_model=SystemHealthDetailResponse)
@limiter.limit("5/minute")
async def admin_monitoring_health(
    request: Request,
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> SystemHealthDetailResponse:
    """Detailed system health (DB, Redis, Celery)."""
    return await get_system_health(db)


@router.get("/monitoring/errors", response_model=ErrorLogResponse)
@limiter.limit("5/minute")
async def admin_monitoring_errors(
    request: Request,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    entity_type: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> ErrorLogResponse:
    """Recent failed bank/email connections."""
    return await get_error_log(
        db, page=page, page_size=page_size, entity_type=entity_type,
    )


@router.get("/monitoring/celery", response_model=CeleryStatusResponse)
@limiter.limit("5/minute")
async def admin_monitoring_celery(
    request: Request,
    _admin: str = Depends(verify_admin_key),
) -> CeleryStatusResponse:
    """Celery task queue status."""
    return await get_celery_status()
