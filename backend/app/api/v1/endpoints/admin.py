"""Internal admin endpoints for the admin portal.

Protected by admin JWT auth (with legacy X-Admin-Key fallback).
Not exposed to the mobile app.
Intended for the React admin dashboard at admin.moneyguardian.co.
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
from app.models.admin_user import AdminUser
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
from app.schemas.admin_health import (
    CohortResponse,
    FunnelResponse,
    HealthScoreListResponse,
    HealthScoreResponse,
    RetentionResponse,
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
from app.services import audit_service
from app.schemas.admin_approvals import (
    ApprovalCreateRequest,
    ApprovalListResponse,
    ApprovalResponse,
    ApprovalReviewRequest,
)
from app.schemas.admin_search import SearchRequest, SearchResponse
from app.schemas.admin_webhooks import (
    WebhookEventListResponse,
    WebhookEventResponse,
    WebhookStatsResponse,
)
from app.services.rbac_service import require_permission
from app.api.v1.endpoints.admin_auth import get_current_admin

logger = logging.getLogger(__name__)

router = APIRouter()


# ---------------------------------------------------------------------------
# Admin auth dependency (new RBAC + legacy fallback)
# ---------------------------------------------------------------------------

# get_current_admin is imported from admin_auth.py and supports both
# JWT Bearer tokens and legacy X-Admin-Key header.
# require_permission() wraps get_current_admin with role checks.


async def verify_admin_key(
    x_admin_key: str = Header(..., alias="X-Admin-Key"),
) -> str:
    """Legacy admin key verification — kept for backward compatibility.

    New endpoints should use ``require_permission()`` instead.
    """
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
    admin: AdminUser = Depends(require_permission("tenants.modify")),
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

    ip = request.client.host if request.client else ""
    ua = request.headers.get("User-Agent", "")[:500]
    await audit_service.log_action(
        db,
        admin_user_id=admin.id,
        action="tenant.tier_override",
        entity_type="tenant",
        entity_id=tenant_id,
        details={
            "previous_tier": previous_tier,
            "new_tier": body.tier,
            "reason": body.reason,
        },
        ip_address=ip,
        user_agent=ua,
    )
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
    admin: AdminUser = Depends(require_permission("users.view")),
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
    admin: AdminUser = Depends(require_permission("users.view")),
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
    admin: AdminUser = Depends(require_permission("users.modify")),
) -> UserStatusUpdateResponse:
    """Activate or deactivate a user."""
    try:
        result = await update_user_status(db, user_id, body)
        ip = request.client.host if request.client else ""
        ua = request.headers.get("User-Agent", "")[:500]
        await audit_service.log_action(
            db,
            admin_user_id=admin.id,
            action="user.status_change",
            entity_type="user",
            entity_id=user_id,
            details={"is_active": body.is_active, "reason": body.reason},
            ip_address=ip,
            user_agent=ua,
        )
        return result
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
    admin: AdminUser = Depends(require_permission("users.view")),
) -> list[AdminSubscriptionItem]:
    """Get all subscriptions for a specific user."""
    return await get_user_subscriptions(db, user_id)


@router.get("/users/{user_id}/alerts", response_model=list[AdminAlertItem])
@limiter.limit("5/minute")
async def admin_get_user_alerts(
    request: Request,
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("users.view")),
) -> list[AdminAlertItem]:
    """Get all alerts for a specific user."""
    return await get_user_alerts(db, user_id)


@router.get("/users/{user_id}/connections", response_model=AdminUserConnectionsResponse)
@limiter.limit("5/minute")
async def admin_get_user_connections(
    request: Request,
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("users.view")),
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
    admin: AdminUser = Depends(require_permission("tenants.view")),
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
    admin: AdminUser = Depends(require_permission("tenants.view")),
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
    admin: AdminUser = Depends(require_permission("tenants.modify")),
) -> TenantStatusUpdateResponse:
    """Change tenant status (active/suspended/deleted)."""
    try:
        result = await update_tenant_status(db, tenant_id, body)
        ip = request.client.host if request.client else ""
        ua = request.headers.get("User-Agent", "")[:500]
        await audit_service.log_action(
            db,
            admin_user_id=admin.id,
            action="tenant.status_change",
            entity_type="tenant",
            entity_id=tenant_id,
            details={"status": body.status, "reason": body.reason},
            ip_address=ip,
            user_agent=ua,
        )
        return result
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
    admin: AdminUser = Depends(require_permission("analytics.view")),
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
    admin: AdminUser = Depends(require_permission("analytics.view")),
) -> SignupAnalyticsResponse:
    """Signup trends over time."""
    return await get_signup_analytics(db, period=period, days=days)


@router.get("/analytics/subscriptions", response_model=SubscriptionAnalyticsResponse)
@limiter.limit("5/minute")
async def admin_analytics_subscriptions(
    request: Request,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("analytics.view")),
) -> SubscriptionAnalyticsResponse:
    """Platform-wide subscription analytics."""
    return await get_subscription_analytics(db)


@router.get("/analytics/connections", response_model=ConnectionAnalyticsResponse)
@limiter.limit("5/minute")
async def admin_analytics_connections(
    request: Request,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("analytics.view")),
) -> ConnectionAnalyticsResponse:
    """Bank + email connection analytics."""
    return await get_connection_analytics(db)


@router.get("/analytics/revenue", response_model=RevenueAnalyticsResponse)
@limiter.limit("5/minute")
async def admin_analytics_revenue(
    request: Request,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("analytics.view")),
) -> RevenueAnalyticsResponse:
    """Revenue and tier analytics."""
    return await get_revenue_analytics(db)


# ---------------------------------------------------------------------------
# Health Scores
# ---------------------------------------------------------------------------


@router.get("/health-scores", response_model=HealthScoreListResponse)
@limiter.limit("5/minute")
async def admin_list_health_scores(
    request: Request,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    risk_level: str | None = Query(default=None),
    min_score: int | None = Query(default=None, ge=0, le=100),
    max_score: int | None = Query(default=None, ge=0, le=100),
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("analytics.view")),
) -> HealthScoreListResponse:
    """List customer health scores with filters."""
    from app.services.health_score_service import get_health_scores

    snapshots, total = await get_health_scores(
        db,
        page=page,
        page_size=page_size,
        risk_level=risk_level,
        min_score=min_score,
        max_score=max_score,
    )
    return HealthScoreListResponse(
        scores=[HealthScoreResponse.model_validate(s) for s in snapshots],
        total_count=total,
    )


@router.get("/health-scores/{user_id}", response_model=list[HealthScoreResponse])
@limiter.limit("5/minute")
async def admin_user_health_history(
    request: Request,
    user_id: UUID,
    days: int = Query(default=90, ge=1, le=365),
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("analytics.view")),
) -> list[HealthScoreResponse]:
    """Get health score history for a specific user."""
    from app.services.health_score_service import get_user_health_history

    snapshots = await get_user_health_history(db, user_id, days=days)
    return [HealthScoreResponse.model_validate(s) for s in snapshots]


# ---------------------------------------------------------------------------
# Advanced Analytics (Cohorts, Funnel, Retention)
# ---------------------------------------------------------------------------


@router.get("/analytics/cohorts", response_model=CohortResponse)
@limiter.limit("5/minute")
async def admin_analytics_cohorts(
    request: Request,
    months: int = Query(default=6, ge=1, le=24),
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("analytics.view")),
) -> CohortResponse:
    """Monthly cohort retention data."""
    from app.services.cohort_analytics_service import get_cohort_retention
    from app.schemas.admin_health import CohortData

    raw = await get_cohort_retention(db, months=months)
    return CohortResponse(
        cohorts=[
            CohortData(
                cohort_month=str(c["cohort_month"]),
                month_offset=int(c["month_offset"]),
                retention_rate=float(c["retention_rate"]),
                user_count=int(c["user_count"]),
            )
            for c in raw
        ],
    )


@router.get("/analytics/funnel", response_model=FunnelResponse)
@limiter.limit("5/minute")
async def admin_analytics_funnel(
    request: Request,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("analytics.view")),
) -> FunnelResponse:
    """Conversion funnel: Signup -> Onboard -> Bank -> Pro."""
    from app.services.cohort_analytics_service import get_conversion_funnel
    from app.schemas.admin_health import FunnelStep

    raw = await get_conversion_funnel(db)
    steps = [
        FunnelStep(
            name=str(s["name"]),
            count=int(s["count"]),
            conversion_rate=float(s["conversion_rate"]),
        )
        for s in raw
    ]
    total_started = steps[0].count if steps else 0
    return FunnelResponse(steps=steps, total_started=total_started)


@router.get("/analytics/retention", response_model=RetentionResponse)
@limiter.limit("5/minute")
async def admin_analytics_retention(
    request: Request,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("analytics.view")),
) -> RetentionResponse:
    """D1/D7/D14/D30/D60/D90 retention curves."""
    from app.services.cohort_analytics_service import get_retention_curves
    from app.schemas.admin_health import RetentionPoint

    raw = await get_retention_curves(db)
    return RetentionResponse(
        points=[
            RetentionPoint(
                day=int(p["day"]),
                retention_rate=float(p["retention_rate"]),
                user_count=int(p["user_count"]),
            )
            for p in raw
        ],
    )


# ---------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------


@router.get("/monitoring/health", response_model=SystemHealthDetailResponse)
@limiter.limit("5/minute")
async def admin_monitoring_health(
    request: Request,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(get_current_admin),
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
    admin: AdminUser = Depends(get_current_admin),
) -> ErrorLogResponse:
    """Recent failed bank/email connections."""
    return await get_error_log(
        db, page=page, page_size=page_size, entity_type=entity_type,
    )


@router.get("/monitoring/celery", response_model=CeleryStatusResponse)
@limiter.limit("5/minute")
async def admin_monitoring_celery(
    request: Request,
    admin: AdminUser = Depends(get_current_admin),
) -> CeleryStatusResponse:
    """Celery task queue status."""
    return await get_celery_status()


# ---------------------------------------------------------------------------
# Impersonation (super_admin only)
# ---------------------------------------------------------------------------


class ImpersonationResponse(BaseModel):
    """Response from user impersonation."""

    access_token: str
    user_email: str
    user_name: str
    expires_in: int


@router.post("/users/{user_id}/impersonate", response_model=ImpersonationResponse)
@limiter.limit("5/minute")
async def admin_impersonate_user(
    request: Request,
    user_id: UUID,
    admin: AdminUser = Depends(require_permission("impersonate")),
    db: AsyncSession = Depends(get_db),
) -> ImpersonationResponse:
    """Generate a short-lived impersonation token for a user.

    Only super_admins can impersonate. The token is valid for 15 minutes
    and includes ``token_type: "impersonation"`` to distinguish it from
    normal access tokens.
    """
    from app.services.admin_impersonation_service import (
        UserNotFoundError as ImpersonationUserNotFoundError,
        create_impersonation_token,
    )

    ip = request.client.host if request.client else ""
    ua = request.headers.get("User-Agent", "")[:500]

    try:
        result = await create_impersonation_token(
            db, admin=admin, user_id=str(user_id),
            ip_address=ip, user_agent=ua,
        )
    except ImpersonationUserNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found or inactive",
        )

    await db.commit()

    return ImpersonationResponse(
        access_token=str(result["access_token"]),
        user_email=str(result["user_email"]),
        user_name=str(result["user_name"]),
        expires_in=int(result["expires_in"]),
    )


# ---------------------------------------------------------------------------
# Unified Search
# ---------------------------------------------------------------------------


@router.post("/search")
@limiter.limit("10/minute")
async def admin_search(
    request: Request,
    body: SearchRequest,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(get_current_admin),
) -> SearchResponse:
    """Unified search across users, tenants, subscriptions, audit logs."""
    from app.services import admin_search_service

    results = await admin_search_service.search(
        db, query=body.query, entity_types=body.entity_types,
    )
    return SearchResponse(results=results, total_count=len(results))


# ---------------------------------------------------------------------------
# Approval Workflows
# ---------------------------------------------------------------------------


@router.get("/approvals", response_model=ApprovalListResponse)
@limiter.limit("5/minute")
async def admin_list_approvals(
    request: Request,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    approval_status: str | None = Query(default=None, alias="status"),
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("approvals.manage")),
) -> ApprovalListResponse:
    """List approval requests with optional status filter."""
    from app.services import approval_service

    approvals, total_count, pending_count = await approval_service.list_approvals(
        db, status_filter=approval_status, page=page, page_size=page_size,
    )
    return ApprovalListResponse(
        requests=[
            ApprovalResponse(
                id=a.id,
                requester_id=a.requester_id,
                requester_email=a.requester.email,
                requester_name=a.requester.full_name,
                approver_id=a.approver_id,
                action=a.action,
                entity_type=a.entity_type,
                entity_id=a.entity_id,
                parameters=a.parameters,
                status=a.status,
                reason=a.reason,
                review_note=a.review_note,
                expires_at=a.expires_at,
                reviewed_at=a.reviewed_at,
                executed_at=a.executed_at,
                created_at=a.created_at,
                updated_at=a.updated_at,
            )
            for a in approvals
        ],
        total_count=total_count,
        pending_count=pending_count,
    )


@router.get("/approvals/{approval_id}")
@limiter.limit("5/minute")
async def admin_get_approval(
    request: Request,
    approval_id: UUID,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("approvals.manage")),
) -> ApprovalResponse:
    """Get approval request detail."""
    from app.services.approval_service import ApprovalNotFoundError, get_approval

    try:
        approval = await get_approval(db, approval_id)
    except ApprovalNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Approval request not found",
        )

    return ApprovalResponse(
        id=approval.id,
        requester_id=approval.requester_id,
        requester_email=approval.requester.email,
        requester_name=approval.requester.full_name,
        approver_id=approval.approver_id,
        action=approval.action,
        entity_type=approval.entity_type,
        entity_id=approval.entity_id,
        parameters=approval.parameters,
        status=approval.status,
        reason=approval.reason,
        review_note=approval.review_note,
        expires_at=approval.expires_at,
        reviewed_at=approval.reviewed_at,
        executed_at=approval.executed_at,
        created_at=approval.created_at,
        updated_at=approval.updated_at,
    )


@router.post("/approvals", status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
async def admin_create_approval(
    request: Request,
    body: ApprovalCreateRequest,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(get_current_admin),
) -> ApprovalResponse:
    """Create an approval request for a sensitive action."""
    from app.services import approval_service

    ip = request.client.host if request.client else ""
    ua = request.headers.get("User-Agent", "")[:500]

    approval = await approval_service.create_approval(
        db, requester=admin, request=body,
    )
    await audit_service.log_action(
        db,
        admin_user_id=admin.id,
        action="approval.create",
        entity_type="approval_request",
        entity_id=approval.id,
        details={"requested_action": body.action, "entity_type": body.entity_type},
        ip_address=ip,
        user_agent=ua,
    )

    return ApprovalResponse(
        id=approval.id,
        requester_id=approval.requester_id,
        requester_email=approval.requester.email,
        requester_name=approval.requester.full_name,
        approver_id=approval.approver_id,
        action=approval.action,
        entity_type=approval.entity_type,
        entity_id=approval.entity_id,
        parameters=approval.parameters,
        status=approval.status,
        reason=approval.reason,
        review_note=approval.review_note,
        expires_at=approval.expires_at,
        reviewed_at=approval.reviewed_at,
        executed_at=approval.executed_at,
        created_at=approval.created_at,
        updated_at=approval.updated_at,
    )


@router.post("/approvals/{approval_id}/review")
@limiter.limit("5/minute")
async def admin_review_approval(
    request: Request,
    approval_id: UUID,
    body: ApprovalReviewRequest,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("approvals.manage")),
) -> ApprovalResponse:
    """Approve or reject an approval request (super_admin only)."""
    from app.services.approval_service import (
        ApprovalNotFoundError,
        ApprovalStateError,
        review_approval,
    )

    ip = request.client.host if request.client else ""
    ua = request.headers.get("User-Agent", "")[:500]

    try:
        approval = await review_approval(
            db, approver=admin, approval_id=approval_id, review_request=body,
        )
    except ApprovalNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Approval request not found",
        )
    except ApprovalStateError as e:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(e),
        )

    await audit_service.log_action(
        db,
        admin_user_id=admin.id,
        action=f"approval.{body.status}",
        entity_type="approval_request",
        entity_id=approval_id,
        details={"review_note": body.review_note},
        ip_address=ip,
        user_agent=ua,
    )

    return ApprovalResponse(
        id=approval.id,
        requester_id=approval.requester_id,
        requester_email=approval.requester.email,
        requester_name=approval.requester.full_name,
        approver_id=approval.approver_id,
        action=approval.action,
        entity_type=approval.entity_type,
        entity_id=approval.entity_id,
        parameters=approval.parameters,
        status=approval.status,
        reason=approval.reason,
        review_note=approval.review_note,
        expires_at=approval.expires_at,
        reviewed_at=approval.reviewed_at,
        executed_at=approval.executed_at,
        created_at=approval.created_at,
        updated_at=approval.updated_at,
    )


@router.post("/approvals/{approval_id}/execute")
@limiter.limit("5/minute")
async def admin_execute_approval(
    request: Request,
    approval_id: UUID,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("approvals.manage")),
) -> ApprovalResponse:
    """Execute a previously approved action."""
    from app.services.approval_service import (
        ApprovalNotFoundError,
        ApprovalStateError,
        execute_approval,
    )

    ip = request.client.host if request.client else ""
    ua = request.headers.get("User-Agent", "")[:500]

    try:
        approval = await execute_approval(db, approval_id=approval_id)
    except ApprovalNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Approval request not found",
        )
    except ApprovalStateError as e:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(e),
        )

    await audit_service.log_action(
        db,
        admin_user_id=admin.id,
        action="approval.execute",
        entity_type="approval_request",
        entity_id=approval_id,
        details={"executed_action": approval.action},
        ip_address=ip,
        user_agent=ua,
    )

    return ApprovalResponse(
        id=approval.id,
        requester_id=approval.requester_id,
        requester_email=approval.requester.email,
        requester_name=approval.requester.full_name,
        approver_id=approval.approver_id,
        action=approval.action,
        entity_type=approval.entity_type,
        entity_id=approval.entity_id,
        parameters=approval.parameters,
        status=approval.status,
        reason=approval.reason,
        review_note=approval.review_note,
        expires_at=approval.expires_at,
        reviewed_at=approval.reviewed_at,
        executed_at=approval.executed_at,
        created_at=approval.created_at,
        updated_at=approval.updated_at,
    )


# ---------------------------------------------------------------------------
# Webhook Event Dashboard
# ---------------------------------------------------------------------------


@router.get("/webhooks")
@limiter.limit("5/minute")
async def admin_list_webhooks(
    request: Request,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    provider: str | None = Query(default=None),
    event_type: str | None = Query(default=None),
    webhook_status: str | None = Query(default=None, alias="status"),
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("analytics.view")),
) -> WebhookEventListResponse:
    """List webhook events with filters."""
    from app.services import webhook_log_service

    events, total_count = await webhook_log_service.list_webhook_events(
        db, provider=provider, event_type=event_type, status=webhook_status,
        page=page, page_size=page_size,
    )
    return WebhookEventListResponse(
        events=[
            WebhookEventResponse(
                id=e.id,
                provider=e.provider,
                event_type=e.event_type,
                event_id=e.event_id,
                payload_hash=e.payload_hash,
                status=e.status,
                processing_time_ms=e.processing_time_ms,
                error_message=e.error_message,
                created_at=e.created_at,
            )
            for e in events
        ],
        total_count=total_count,
    )


@router.get("/webhooks/stats")
@limiter.limit("5/minute")
async def admin_webhook_stats(
    request: Request,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("analytics.view")),
) -> WebhookStatsResponse:
    """Aggregate webhook statistics."""
    from app.services import webhook_log_service

    stats = await webhook_log_service.get_webhook_stats(db)
    return WebhookStatsResponse(
        total_events=int(stats["total_events"]),
        by_provider=stats["by_provider"],
        by_status=stats["by_status"],
        avg_processing_time_ms=float(stats["avg_processing_time_ms"]),
    )


@router.get("/webhooks/{webhook_id}")
@limiter.limit("5/minute")
async def admin_get_webhook(
    request: Request,
    webhook_id: UUID,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("analytics.view")),
) -> WebhookEventResponse:
    """Get webhook event detail."""
    from app.services import webhook_log_service

    event = await webhook_log_service.get_webhook_event(db, webhook_id)
    if not event:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Webhook event not found",
        )

    return WebhookEventResponse(
        id=event.id,
        provider=event.provider,
        event_type=event.event_type,
        event_id=event.event_id,
        payload_hash=event.payload_hash,
        status=event.status,
        processing_time_ms=event.processing_time_ms,
        error_message=event.error_message,
        created_at=event.created_at,
    )
