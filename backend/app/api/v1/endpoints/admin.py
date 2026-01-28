"""Internal admin endpoints for operational management.

Protected by ADMIN_API_KEY header. Not exposed to mobile app.
Intended for internal dashboards (pgAdmin, Metabase) and ops scripts.
"""

import logging
from datetime import datetime, timezone
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.db.session import get_db
from app.models.bank_connection import BankConnection
from app.models.subscription import Subscription
from app.models.tenant import Tenant
from app.models.user import User

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


AdminKeyDep = str  # resolved via Depends(verify_admin_key)


# ---------------------------------------------------------------------------
# Response schemas
# ---------------------------------------------------------------------------

class AdminUserResponse(BaseModel):
    """Admin view of a user."""

    id: str
    email: str
    full_name: str | None
    tenant_id: str
    tier: str
    is_active: bool
    is_email_verified: bool
    created_at: datetime
    last_login_at: datetime | None


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
# Endpoints
# ---------------------------------------------------------------------------

@router.get("/users/lookup", response_model=AdminUserResponse)
async def admin_lookup_user(
    email: str,
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> AdminUserResponse:
    """Look up a user by email address."""
    result = await db.execute(
        select(User).where(User.email == email)
    )
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Get tenant tier
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
        is_email_verified=user.is_email_verified,
        created_at=user.created_at,
        last_login_at=getattr(user, "last_login_at", None),
    )


@router.post("/tenants/{tenant_id}/tier", response_model=TierOverrideResponse)
async def admin_override_tier(
    tenant_id: UUID,
    request: TierOverrideRequest,
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> TierOverrideResponse:
    """Override a tenant's subscription tier (e.g., for support, partners)."""
    result = await db.execute(
        select(Tenant).where(Tenant.id == tenant_id)
    )
    tenant = result.scalar_one_or_none()

    if not tenant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tenant not found",
        )

    previous_tier = tenant.tier
    tenant.tier = request.tier
    db.add(tenant)
    await db.commit()

    logger.info(
        "Admin tier override: tenant=%s from=%s to=%s reason=%s",
        tenant_id,
        previous_tier,
        request.tier,
        request.reason,
    )

    return TierOverrideResponse(
        tenant_id=str(tenant_id),
        previous_tier=previous_tier,
        new_tier=request.tier,
    )


@router.get("/stats", response_model=SystemStatsResponse)
async def admin_system_stats(
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> SystemStatsResponse:
    """Get system-wide statistics."""
    # User counts
    total_users_result = await db.execute(select(func.count(User.id)))
    total_users = total_users_result.scalar() or 0

    active_users_result = await db.execute(
        select(func.count(User.id)).where(User.is_active == True)
    )
    active_users = active_users_result.scalar() or 0

    # Tenant counts
    total_tenants_result = await db.execute(select(func.count(Tenant.id)))
    total_tenants = total_tenants_result.scalar() or 0

    # Tier breakdown
    tier_rows = await db.execute(
        select(Tenant.tier, func.count(Tenant.id)).group_by(Tenant.tier)
    )
    tier_breakdown: dict[str, int] = {
        row[0]: row[1] for row in tier_rows.all()
    }

    # Subscription count
    total_subs_result = await db.execute(
        select(func.count(Subscription.id)).where(
            Subscription.deleted_at.is_(None)
        )
    )
    total_subscriptions = total_subs_result.scalar() or 0

    # Bank connection counts
    total_bank_result = await db.execute(
        select(func.count(BankConnection.id)).where(
            BankConnection.deleted_at.is_(None)
        )
    )
    total_bank_connections = total_bank_result.scalar() or 0

    connected_bank_result = await db.execute(
        select(func.count(BankConnection.id)).where(
            BankConnection.deleted_at.is_(None),
            BankConnection.status == "connected",
        )
    )
    connected_bank_connections = connected_bank_result.scalar() or 0

    return SystemStatsResponse(
        total_users=total_users,
        active_users=active_users,
        total_tenants=total_tenants,
        tier_breakdown=tier_breakdown,
        total_subscriptions=total_subscriptions,
        total_bank_connections=total_bank_connections,
        connected_bank_connections=connected_bank_connections,
    )


@router.get("/connections/health", response_model=ConnectionHealthResponse)
async def admin_connection_health(
    db: AsyncSession = Depends(get_db),
    _admin: str = Depends(verify_admin_key),
) -> ConnectionHealthResponse:
    """Get bank connection health overview."""
    active_connections = await db.execute(
        select(BankConnection).where(BankConnection.deleted_at.is_(None))
    )
    connections = active_connections.scalars().all()

    status_counts: dict[str, int] = {
        "connected": 0,
        "error": 0,
        "requires_reauth": 0,
        "disconnected": 0,
        "pending": 0,
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
