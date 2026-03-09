"""Admin authentication endpoints.

Provides JWT-based login, MFA (TOTP), token refresh, and admin user
management for the admin portal.
"""

import logging
from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.rate_limit import limiter
from app.db.session import get_db
from app.models.admin_user import AdminUser
from app.schemas.admin_auth import (
    AdminLoginRequest,
    AdminLoginResponse,
    AdminMfaConfirmRequest,
    AdminMfaSetupResponse,
    AdminMfaVerifyRequest,
    AdminProfileResponse,
    AdminRefreshRequest,
    AdminTokenResponse,
    AdminUserCreateRequest,
    AdminUserListResponse,
    AdminUserUpdateRequest,
    AuditLogResponse,
)
from app.services import admin_auth_service, audit_service
from app.services.admin_auth_service import (
    AdminAuthError,
    AdminEmailExistsError,
    AdminNotFoundError,
    InvalidCredentialsError,
    InvalidMfaCodeError,
    MfaRequiredError,
    decode_admin_token,
)
from app.services.rbac_service import require_permission

logger = logging.getLogger(__name__)

router = APIRouter()
admin_bearer = HTTPBearer(auto_error=False)


# ---------------------------------------------------------------------------
# Current admin dependency
# ---------------------------------------------------------------------------


async def get_current_admin(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(admin_bearer),
    db: AsyncSession = Depends(get_db),
) -> AdminUser:
    """Extract and validate admin JWT.

    Also supports legacy X-Admin-Key fallback during migration.
    """
    # Try JWT first
    if credentials and credentials.credentials:
        token = credentials.credentials
        payload = decode_admin_token(token, "admin_access")
        if payload:
            admin_id = UUID(payload["sub"])
            from sqlalchemy import select
            result = await db.execute(
                select(AdminUser).where(
                    AdminUser.id == admin_id, AdminUser.is_active == True,
                )
            )
            admin = result.scalar_one_or_none()
            if admin:
                return admin

    # Fallback: X-Admin-Key header (for backward compatibility)
    admin_key = request.headers.get("X-Admin-Key")
    if admin_key and settings.admin_api_key and admin_key == settings.admin_api_key:
        # Return a virtual super_admin for legacy key access
        from sqlalchemy import select
        result = await db.execute(
            select(AdminUser).where(
                AdminUser.role == "super_admin", AdminUser.is_active == True,
            ).limit(1)
        )
        admin = result.scalar_one_or_none()
        if admin:
            return admin

        # If no admin users exist yet, this is initial setup
        # The legacy key still works but with limited identity
        logger.warning("Legacy admin key used but no admin users exist")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No admin users configured. Create one via seed script.",
        )

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or missing admin credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )


def _get_client_info(request: Request) -> tuple[str, str]:
    """Extract IP address and user agent from request."""
    ip = request.client.host if request.client else ""
    ua = request.headers.get("User-Agent", "")[:500]
    return ip, ua


# ---------------------------------------------------------------------------
# Auth endpoints
# ---------------------------------------------------------------------------


@router.post("/auth/login", response_model=AdminLoginResponse)
@limiter.limit("5/minute")
async def admin_login(
    request: Request,
    body: AdminLoginRequest,
    db: AsyncSession = Depends(get_db),
) -> AdminLoginResponse:
    """Admin login with email/password. Returns JWT tokens or MFA challenge."""
    ip, ua = _get_client_info(request)
    try:
        response = await admin_auth_service.login(
            db, email=body.email, password=body.password,
            ip_address=ip, user_agent=ua,
        )
        await audit_service.log_action(
            db,
            admin_user_id=None,  # Logged after successful auth
            action="admin.login",
            entity_type="admin_user",
            details={"email": body.email},
            ip_address=ip,
            user_agent=ua,
        )
        await db.commit()
        return response
    except MfaRequiredError as e:
        return AdminLoginResponse(
            access_token="",
            refresh_token=e.session_token,
            requires_mfa=True,
        )
    except InvalidCredentialsError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )


@router.post("/auth/verify-mfa", response_model=AdminTokenResponse)
@limiter.limit("5/minute")
async def admin_verify_mfa(
    request: Request,
    body: AdminMfaVerifyRequest,
    db: AsyncSession = Depends(get_db),
) -> AdminTokenResponse:
    """Verify MFA TOTP code after login."""
    ip, ua = _get_client_info(request)
    try:
        response = await admin_auth_service.verify_mfa(
            db, session_token=body.session_token, code=body.code,
            ip_address=ip, user_agent=ua,
        )
        await db.commit()
        return response
    except (InvalidCredentialsError, InvalidMfaCodeError) as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
        )


@router.post("/auth/refresh", response_model=AdminTokenResponse)
@limiter.limit("10/minute")
async def admin_refresh(
    request: Request,
    body: AdminRefreshRequest,
    db: AsyncSession = Depends(get_db),
) -> AdminTokenResponse:
    """Refresh admin access token."""
    ip, ua = _get_client_info(request)
    try:
        response = await admin_auth_service.refresh_tokens(
            db, refresh_token=body.refresh_token,
            ip_address=ip, user_agent=ua,
        )
        await db.commit()
        return response
    except InvalidCredentialsError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )


@router.post("/auth/logout", status_code=status.HTTP_204_NO_CONTENT)
async def admin_logout(
    request: Request,
    body: AdminRefreshRequest | None = None,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Logout and revoke admin session."""
    await admin_auth_service.logout(
        db,
        admin_id=admin.id,
        refresh_token=body.refresh_token if body else None,
    )
    ip, ua = _get_client_info(request)
    await audit_service.log_action(
        db,
        admin_user_id=admin.id,
        action="admin.logout",
        entity_type="admin_user",
        entity_id=admin.id,
        ip_address=ip,
        user_agent=ua,
    )
    await db.commit()


@router.get("/auth/me", response_model=AdminProfileResponse)
async def admin_me(
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> AdminProfileResponse:
    """Get current admin profile."""
    return await admin_auth_service.get_admin_profile(db, admin.id)


# ---------------------------------------------------------------------------
# MFA Setup
# ---------------------------------------------------------------------------


@router.post("/auth/setup-mfa", response_model=AdminMfaSetupResponse)
async def admin_setup_mfa(
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> AdminMfaSetupResponse:
    """Generate TOTP secret and QR URI for MFA setup."""
    response = await admin_auth_service.setup_mfa(db, admin_id=admin.id)
    await db.commit()
    return response


@router.post("/auth/confirm-mfa", status_code=status.HTTP_200_OK)
async def admin_confirm_mfa(
    request: Request,
    body: AdminMfaConfirmRequest,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> dict[str, bool]:
    """Verify TOTP code to enable MFA."""
    try:
        await admin_auth_service.confirm_mfa(
            db, admin_id=admin.id, code=body.code,
        )
        ip, ua = _get_client_info(request)
        await audit_service.log_action(
            db,
            admin_user_id=admin.id,
            action="admin.mfa_enabled",
            entity_type="admin_user",
            entity_id=admin.id,
            ip_address=ip,
            user_agent=ua,
        )
        await db.commit()
        return {"mfa_enabled": True}
    except InvalidMfaCodeError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid verification code",
        )


# ---------------------------------------------------------------------------
# Admin User Management (super_admin only)
# ---------------------------------------------------------------------------


@router.get("/admin-users", response_model=AdminUserListResponse)
async def admin_list_admin_users(
    admin: AdminUser = Depends(require_permission("admin_users.manage")),
    db: AsyncSession = Depends(get_db),
) -> AdminUserListResponse:
    """List all admin users (super_admin only)."""
    return await admin_auth_service.list_admin_users(db)


@router.post("/admin-users", response_model=AdminProfileResponse, status_code=status.HTTP_201_CREATED)
async def admin_create_admin_user(
    request: Request,
    body: AdminUserCreateRequest,
    admin: AdminUser = Depends(require_permission("admin_users.manage")),
    db: AsyncSession = Depends(get_db),
) -> AdminProfileResponse:
    """Create a new admin user (super_admin only)."""
    try:
        result = await admin_auth_service.create_admin_user(db, data=body)
        ip, ua = _get_client_info(request)
        await audit_service.log_action(
            db,
            admin_user_id=admin.id,
            action="admin_user.create",
            entity_type="admin_user",
            entity_id=result.id,
            details={"email": body.email, "role": body.role},
            ip_address=ip,
            user_agent=ua,
        )
        await db.commit()
        return result
    except AdminEmailExistsError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already in use",
        )


@router.put("/admin-users/{admin_id}", response_model=AdminProfileResponse)
async def admin_update_admin_user(
    request: Request,
    admin_id: UUID,
    body: AdminUserUpdateRequest,
    admin: AdminUser = Depends(require_permission("admin_users.manage")),
    db: AsyncSession = Depends(get_db),
) -> AdminProfileResponse:
    """Update an admin user (super_admin only)."""
    try:
        result = await admin_auth_service.update_admin_user(
            db, admin_id=admin_id, data=body,
        )
        ip, ua = _get_client_info(request)
        await audit_service.log_action(
            db,
            admin_user_id=admin.id,
            action="admin_user.update",
            entity_type="admin_user",
            entity_id=admin_id,
            details={
                "full_name": body.full_name,
                "role": body.role,
                "is_active": body.is_active,
            },
            ip_address=ip,
            user_agent=ua,
        )
        await db.commit()
        return result
    except AdminNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Admin user not found",
        )


# ---------------------------------------------------------------------------
# Audit Log
# ---------------------------------------------------------------------------


@router.get("/audit-log", response_model=AuditLogResponse)
async def admin_get_audit_log(
    request: Request,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    action: str | None = Query(default=None),
    entity_type: str | None = Query(default=None),
    admin_user_id: UUID | None = Query(default=None),
    admin: AdminUser = Depends(require_permission("audit_log.view")),
    db: AsyncSession = Depends(get_db),
) -> AuditLogResponse:
    """Query audit log with filters (admin/super_admin only)."""
    return await audit_service.get_audit_log(
        db,
        page=page,
        page_size=page_size,
        action_filter=action,
        entity_type_filter=entity_type,
        admin_user_id_filter=admin_user_id,
    )
