"""Admin-specific schemas for the internal admin portal.

Strict Pydantic models — no ``Any`` or ``dict[str, Any]``.
All responses are purpose-built for the React admin dashboard.
"""

from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


# ---------------------------------------------------------------------------
# Shared config
# ---------------------------------------------------------------------------

_ADMIN_CONFIG = ConfigDict(
    from_attributes=True,
    str_strip_whitespace=True,
    strict=True,
    ser_json_inf_nan="constants",
)


# ---------------------------------------------------------------------------
# Pagination
# ---------------------------------------------------------------------------


class PaginationParams(BaseModel):
    """Shared pagination input."""

    model_config = _ADMIN_CONFIG

    page: int = Field(default=1, ge=1)
    page_size: int = Field(default=20, ge=1, le=100)

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.page_size


class PaginationMeta(BaseModel):
    """Pagination metadata returned in list responses."""

    model_config = _ADMIN_CONFIG

    page: int
    page_size: int
    total_count: int
    total_pages: int


# ---------------------------------------------------------------------------
# User Management
# ---------------------------------------------------------------------------


class AdminUserListItem(BaseModel):
    """Compact user row for list views."""

    model_config = _ADMIN_CONFIG

    id: UUID
    email: str
    full_name: str | None
    tenant_id: UUID
    tier: str
    is_active: bool
    is_verified: bool
    subscription_count: int
    connection_count: int
    created_at: datetime
    last_login_at: datetime | None


class PaginatedUsersResponse(BaseModel):
    """Paginated list of users."""

    model_config = _ADMIN_CONFIG

    users: list[AdminUserListItem]
    pagination: PaginationMeta


class AdminUserDetailResponse(BaseModel):
    """Full user detail for admin panel."""

    model_config = _ADMIN_CONFIG

    id: UUID
    email: str
    full_name: str | None
    tenant_id: UUID
    tier: str
    is_active: bool
    is_verified: bool
    push_notifications_enabled: bool
    email_notifications_enabled: bool
    subscription_tier: str
    subscription_expires_at: datetime | None
    onboarding_completed: bool
    created_at: datetime
    updated_at: datetime
    last_login_at: datetime | None
    subscription_count: int
    bank_connection_count: int
    email_connection_count: int
    alert_count: int
    unread_alert_count: int


class UserStatusUpdate(BaseModel):
    """Request to activate/deactivate a user."""

    model_config = _ADMIN_CONFIG

    is_active: bool
    reason: str = Field(..., min_length=3, max_length=500)


class UserStatusUpdateResponse(BaseModel):
    """Response after user status change."""

    model_config = _ADMIN_CONFIG

    user_id: UUID
    is_active: bool
    reason: str


# User's subscriptions / alerts / connections (admin cross-tenant views)


class AdminSubscriptionItem(BaseModel):
    """Subscription item for admin views."""

    model_config = _ADMIN_CONFIG

    id: UUID
    name: str
    amount: float
    currency: str
    billing_cycle: str
    is_active: bool
    is_paused: bool
    ai_flag: str
    source: str
    next_billing_date: date | None
    created_at: datetime


class AdminAlertItem(BaseModel):
    """Alert item for admin views."""

    model_config = _ADMIN_CONFIG

    id: UUID
    alert_type: str
    severity: str
    title: str
    message: str
    amount: float | None
    is_read: bool
    is_dismissed: bool
    created_at: datetime


class AdminBankConnectionItem(BaseModel):
    """Bank connection for admin views."""

    model_config = _ADMIN_CONFIG

    id: UUID
    provider: str
    institution_name: str
    status: str
    error_code: str | None
    error_message: str | None
    last_sync_at: datetime | None
    account_count: int
    created_at: datetime


class AdminEmailConnectionItem(BaseModel):
    """Email connection for admin views."""

    model_config = _ADMIN_CONFIG

    id: UUID
    provider: str
    email_address: str
    status: str
    error_message: str | None
    last_scan_at: datetime | None
    scanned_email_count: int
    created_at: datetime


class AdminUserConnectionsResponse(BaseModel):
    """Combined bank + email connections for a user."""

    model_config = _ADMIN_CONFIG

    bank_connections: list[AdminBankConnectionItem]
    email_connections: list[AdminEmailConnectionItem]


# ---------------------------------------------------------------------------
# Tenant Management
# ---------------------------------------------------------------------------


class AdminTenantListItem(BaseModel):
    """Compact tenant row for list views."""

    model_config = _ADMIN_CONFIG

    id: UUID
    name: str
    tier: str
    status: str
    user_count: int
    subscription_count: int
    created_at: datetime


class PaginatedTenantsResponse(BaseModel):
    """Paginated list of tenants."""

    model_config = _ADMIN_CONFIG

    tenants: list[AdminTenantListItem]
    pagination: PaginationMeta


class AdminTenantDetailResponse(BaseModel):
    """Full tenant detail for admin panel."""

    model_config = _ADMIN_CONFIG

    id: UUID
    name: str
    tier: str
    status: str
    stripe_customer_id: str | None
    user_count: int
    subscription_count: int
    bank_connection_count: int
    email_connection_count: int
    created_at: datetime
    updated_at: datetime


class TenantStatusUpdate(BaseModel):
    """Request to change tenant status."""

    model_config = _ADMIN_CONFIG

    status: Literal["active", "suspended", "deleted"]
    reason: str = Field(..., min_length=3, max_length=500)


class TenantStatusUpdateResponse(BaseModel):
    """Response after tenant status change."""

    model_config = _ADMIN_CONFIG

    tenant_id: UUID
    previous_status: str
    new_status: str
    reason: str


# ---------------------------------------------------------------------------
# Analytics
# ---------------------------------------------------------------------------


class AnalyticsOverviewResponse(BaseModel):
    """High-level platform metrics for the dashboard."""

    model_config = _ADMIN_CONFIG

    total_users: int
    active_users_30d: int
    new_signups_7d: int
    new_signups_30d: int
    pro_users: int
    enterprise_users: int
    free_users: int
    conversion_rate: float  # free → paid %
    total_subscriptions: int
    total_bank_connections: int
    total_email_connections: int
    monthly_tracked_value: float  # sum of all active subscription amounts (monthly)


class SignupDataPoint(BaseModel):
    """Single data point for signup chart."""

    model_config = _ADMIN_CONFIG

    date: date
    count: int


class SignupAnalyticsResponse(BaseModel):
    """Signup trends over time."""

    model_config = _ADMIN_CONFIG

    period: Literal["daily", "weekly", "monthly"]
    data_points: list[SignupDataPoint]
    total: int


class TopMerchant(BaseModel):
    """Top merchant by subscription count."""

    model_config = _ADMIN_CONFIG

    name: str
    count: int
    total_monthly_value: float


class SubscriptionAnalyticsResponse(BaseModel):
    """Platform-wide subscription analytics."""

    model_config = _ADMIN_CONFIG

    total_tracked: int
    avg_per_user: float
    total_monthly_value: float
    total_yearly_value: float
    top_merchants: list[TopMerchant]
    flag_distribution: dict[str, int]  # ai_flag → count
    source_distribution: dict[str, int]  # source → count


class ProviderStat(BaseModel):
    """Connection stats for a single provider."""

    model_config = _ADMIN_CONFIG

    provider: str
    total: int
    connected: int
    error: int
    requires_reauth: int


class ConnectionAnalyticsResponse(BaseModel):
    """Bank + email connection analytics."""

    model_config = _ADMIN_CONFIG

    bank_providers: list[ProviderStat]
    email_providers: list[ProviderStat]
    bank_success_rate: float
    email_success_rate: float


class RevenueAnalyticsResponse(BaseModel):
    """Revenue and tier analytics."""

    model_config = _ADMIN_CONFIG

    tier_breakdown: dict[str, int]  # tier → user count
    total_paid_users: int
    churn_count_30d: int  # users who downgraded from paid in last 30d


# ---------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------


class ServiceStatus(BaseModel):
    """Status of a single service (DB, Redis, etc.)."""

    model_config = _ADMIN_CONFIG

    name: str
    status: Literal["healthy", "unhealthy"]
    latency_ms: float | None
    error: str | None


class SystemHealthDetailResponse(BaseModel):
    """Detailed system health for monitoring page."""

    model_config = _ADMIN_CONFIG

    services: list[ServiceStatus]
    overall_status: Literal["healthy", "degraded", "unhealthy"]


class ErrorLogEntry(BaseModel):
    """A single error log entry."""

    model_config = _ADMIN_CONFIG

    id: UUID
    entity_type: Literal["bank_connection", "email_connection"]
    entity_id: UUID
    tenant_id: UUID
    provider: str
    institution_or_email: str
    error_code: str | None
    error_message: str | None
    status: str
    last_attempt_at: datetime | None
    created_at: datetime


class ErrorLogResponse(BaseModel):
    """Paginated error log."""

    model_config = _ADMIN_CONFIG

    errors: list[ErrorLogEntry]
    pagination: PaginationMeta


class CeleryTaskInfo(BaseModel):
    """Info about a Celery periodic task."""

    model_config = _ADMIN_CONFIG

    name: str
    schedule: str
    last_run: datetime | None
    description: str


class CeleryStatusResponse(BaseModel):
    """Celery task queue status."""

    model_config = _ADMIN_CONFIG

    scheduled_tasks: list[CeleryTaskInfo]
