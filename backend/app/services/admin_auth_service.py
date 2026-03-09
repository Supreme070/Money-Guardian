"""Admin authentication service.

Handles admin login, MFA (TOTP), session management, and admin CRUD.
Admin auth is completely separate from regular user auth.
"""

import hashlib
import logging
import secrets
from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4

import pyotp
from jose import JWTError, jwt
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import (
    encrypt_sensitive_data,
    decrypt_sensitive_data,
    get_password_hash,
    verify_password,
)
from app.models.admin_user import AdminSession, AdminUser
from app.schemas.admin_auth import (
    AdminLoginResponse,
    AdminMfaSetupResponse,
    AdminProfileResponse,
    AdminTokenResponse,
    AdminUserCreateRequest,
    AdminUserListItem,
    AdminUserListResponse,
    AdminUserUpdateRequest,
)

logger = logging.getLogger(__name__)

# Admin JWT uses the same secret but different token_type
ADMIN_ACCESS_TOKEN_MINUTES = 30
ADMIN_REFRESH_TOKEN_DAYS = 1  # Shorter than user tokens for security


class AdminAuthError(Exception):
    """Base admin auth exception."""


class InvalidCredentialsError(AdminAuthError):
    """Raised on bad email/password."""


class MfaRequiredError(AdminAuthError):
    """Raised when MFA verification is needed."""

    def __init__(self, session_token: str) -> None:
        self.session_token = session_token
        super().__init__("MFA verification required")


class InvalidMfaCodeError(AdminAuthError):
    """Raised on bad TOTP code."""


class AdminNotFoundError(AdminAuthError):
    """Raised when admin user not found."""


class AdminEmailExistsError(AdminAuthError):
    """Raised when email already in use."""


# ---------------------------------------------------------------------------
# JWT helpers (admin-specific token_type)
# ---------------------------------------------------------------------------


def _create_admin_access_token(admin_id: UUID, email: str, role: str) -> str:
    now = datetime.now(timezone.utc)
    expire = now + timedelta(minutes=ADMIN_ACCESS_TOKEN_MINUTES)
    payload = {
        "sub": str(admin_id),
        "email": email,
        "role": role,
        "token_type": "admin_access",
        "exp": int(expire.timestamp()),
        "iat": int(now.timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def _create_admin_refresh_token(admin_id: UUID, email: str, role: str) -> str:
    now = datetime.now(timezone.utc)
    expire = now + timedelta(days=ADMIN_REFRESH_TOKEN_DAYS)
    payload = {
        "sub": str(admin_id),
        "email": email,
        "role": role,
        "token_type": "admin_refresh",
        "exp": int(expire.timestamp()),
        "iat": int(now.timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def _create_mfa_session_token(admin_id: UUID) -> str:
    """Create a short-lived token for the MFA verification step."""
    now = datetime.now(timezone.utc)
    expire = now + timedelta(minutes=5)
    payload = {
        "sub": str(admin_id),
        "token_type": "admin_mfa_session",
        "exp": int(expire.timestamp()),
        "iat": int(now.timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def decode_admin_token(token: str, expected_type: str) -> dict[str, str] | None:
    """Decode an admin JWT and verify token_type."""
    try:
        payload = jwt.decode(
            token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm],
        )
        if payload.get("token_type") != expected_type:
            return None
        return payload
    except JWTError:
        return None


def _hash_token(token: str) -> str:
    """SHA-256 hash a token for storage."""
    return hashlib.sha256(token.encode()).hexdigest()


# ---------------------------------------------------------------------------
# Login / MFA
# ---------------------------------------------------------------------------


async def login(
    db: AsyncSession,
    *,
    email: str,
    password: str,
    ip_address: str,
    user_agent: str,
) -> AdminLoginResponse:
    """Authenticate admin user. Raises MfaRequiredError if MFA is enabled."""
    result = await db.execute(
        select(AdminUser).where(AdminUser.email == email, AdminUser.is_active == True)
    )
    admin = result.scalar_one_or_none()

    if not admin or not verify_password(password, admin.hashed_password):
        raise InvalidCredentialsError("Invalid email or password")

    # If MFA is enabled, return a temporary session token
    if admin.mfa_enabled:
        session_token = _create_mfa_session_token(admin.id)
        raise MfaRequiredError(session_token=session_token)

    # No MFA — issue tokens directly
    return await _issue_tokens(db, admin, ip_address, user_agent)


async def verify_mfa(
    db: AsyncSession,
    *,
    session_token: str,
    code: str,
    ip_address: str,
    user_agent: str,
) -> AdminTokenResponse:
    """Verify MFA TOTP code and issue full tokens."""
    payload = decode_admin_token(session_token, "admin_mfa_session")
    if not payload:
        raise InvalidCredentialsError("Invalid or expired MFA session")

    admin_id = UUID(payload["sub"])
    result = await db.execute(
        select(AdminUser).where(AdminUser.id == admin_id, AdminUser.is_active == True)
    )
    admin = result.scalar_one_or_none()
    if not admin or not admin.mfa_enabled or not admin.mfa_secret:
        raise InvalidCredentialsError("Admin not found or MFA not configured")

    # Decrypt the stored TOTP secret and verify
    totp_secret = decrypt_sensitive_data(admin.mfa_secret)
    totp = pyotp.TOTP(totp_secret)
    if not totp.verify(code, valid_window=1):
        raise InvalidMfaCodeError("Invalid MFA code")

    response = await _issue_tokens(db, admin, ip_address, user_agent)
    return AdminTokenResponse(
        access_token=response.access_token,
        refresh_token=response.refresh_token,
    )


async def _issue_tokens(
    db: AsyncSession,
    admin: AdminUser,
    ip_address: str,
    user_agent: str,
) -> AdminLoginResponse:
    """Issue access + refresh tokens and create a session."""
    access_token = _create_admin_access_token(admin.id, admin.email, admin.role)
    refresh_token = _create_admin_refresh_token(admin.id, admin.email, admin.role)

    # Store session for refresh token tracking
    now = datetime.now(timezone.utc)
    session = AdminSession(
        id=uuid4(),
        admin_user_id=admin.id,
        token_hash=_hash_token(refresh_token),
        ip_address=ip_address,
        user_agent=user_agent,
        expires_at=now + timedelta(days=ADMIN_REFRESH_TOKEN_DAYS),
    )
    db.add(session)

    # Update last login
    admin.last_login_at = now
    db.add(admin)
    await db.flush()

    return AdminLoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        requires_mfa=False,
    )


async def refresh_tokens(
    db: AsyncSession,
    *,
    refresh_token: str,
    ip_address: str,
    user_agent: str,
) -> AdminTokenResponse:
    """Refresh admin tokens. Revokes old session, creates new one."""
    payload = decode_admin_token(refresh_token, "admin_refresh")
    if not payload:
        raise InvalidCredentialsError("Invalid or expired refresh token")

    admin_id = UUID(payload["sub"])
    token_hash = _hash_token(refresh_token)

    # Find and revoke existing session
    session_result = await db.execute(
        select(AdminSession).where(
            AdminSession.admin_user_id == admin_id,
            AdminSession.token_hash == token_hash,
            AdminSession.revoked_at.is_(None),
        )
    )
    session = session_result.scalar_one_or_none()
    if not session:
        raise InvalidCredentialsError("Session not found or already revoked")

    session.revoked_at = datetime.now(timezone.utc)
    db.add(session)

    # Fetch admin
    admin_result = await db.execute(
        select(AdminUser).where(AdminUser.id == admin_id, AdminUser.is_active == True)
    )
    admin = admin_result.scalar_one_or_none()
    if not admin:
        raise InvalidCredentialsError("Admin not found or inactive")

    # Issue new tokens
    new_access = _create_admin_access_token(admin.id, admin.email, admin.role)
    new_refresh = _create_admin_refresh_token(admin.id, admin.email, admin.role)

    new_session = AdminSession(
        id=uuid4(),
        admin_user_id=admin.id,
        token_hash=_hash_token(new_refresh),
        ip_address=ip_address,
        user_agent=user_agent,
        expires_at=datetime.now(timezone.utc) + timedelta(days=ADMIN_REFRESH_TOKEN_DAYS),
    )
    db.add(new_session)
    await db.flush()

    return AdminTokenResponse(
        access_token=new_access,
        refresh_token=new_refresh,
    )


async def logout(
    db: AsyncSession,
    *,
    admin_id: UUID,
    refresh_token: str | None = None,
) -> None:
    """Revoke admin session(s)."""
    now = datetime.now(timezone.utc)
    if refresh_token:
        token_hash = _hash_token(refresh_token)
        result = await db.execute(
            select(AdminSession).where(
                AdminSession.admin_user_id == admin_id,
                AdminSession.token_hash == token_hash,
                AdminSession.revoked_at.is_(None),
            )
        )
        session = result.scalar_one_or_none()
        if session:
            session.revoked_at = now
            db.add(session)
    else:
        # Revoke all sessions
        result = await db.execute(
            select(AdminSession).where(
                AdminSession.admin_user_id == admin_id,
                AdminSession.revoked_at.is_(None),
            )
        )
        for session in result.scalars().all():
            session.revoked_at = now
            db.add(session)

    await db.flush()


# ---------------------------------------------------------------------------
# MFA Setup
# ---------------------------------------------------------------------------


async def setup_mfa(db: AsyncSession, *, admin_id: UUID) -> AdminMfaSetupResponse:
    """Generate TOTP secret for MFA setup. Returns secret + QR URI."""
    result = await db.execute(
        select(AdminUser).where(AdminUser.id == admin_id)
    )
    admin = result.scalar_one_or_none()
    if not admin:
        raise AdminNotFoundError("Admin not found")

    # Generate new TOTP secret
    secret = pyotp.random_base32()
    totp = pyotp.TOTP(secret)
    qr_uri = totp.provisioning_uri(
        name=admin.email,
        issuer_name="Money Guardian Admin",
    )

    # Store encrypted secret (not yet enabled)
    admin.mfa_secret = encrypt_sensitive_data(secret)
    db.add(admin)
    await db.flush()

    return AdminMfaSetupResponse(secret=secret, qr_uri=qr_uri)


async def confirm_mfa(db: AsyncSession, *, admin_id: UUID, code: str) -> bool:
    """Verify TOTP code and enable MFA."""
    result = await db.execute(
        select(AdminUser).where(AdminUser.id == admin_id)
    )
    admin = result.scalar_one_or_none()
    if not admin or not admin.mfa_secret:
        raise AdminNotFoundError("Admin not found or MFA not set up")

    totp_secret = decrypt_sensitive_data(admin.mfa_secret)
    totp = pyotp.TOTP(totp_secret)
    if not totp.verify(code, valid_window=1):
        raise InvalidMfaCodeError("Invalid verification code")

    admin.mfa_enabled = True
    db.add(admin)
    await db.flush()
    return True


# ---------------------------------------------------------------------------
# Admin User CRUD (super_admin only)
# ---------------------------------------------------------------------------


async def create_admin_user(
    db: AsyncSession,
    *,
    data: AdminUserCreateRequest,
) -> AdminProfileResponse:
    """Create a new admin user."""
    # Check email uniqueness
    existing = await db.execute(
        select(AdminUser).where(AdminUser.email == data.email)
    )
    if existing.scalar_one_or_none():
        raise AdminEmailExistsError(f"Email {data.email} already in use")

    admin = AdminUser(
        id=uuid4(),
        email=data.email,
        hashed_password=get_password_hash(data.password),
        full_name=data.full_name,
        role=data.role,
        is_active=True,
        mfa_enabled=False,
    )
    db.add(admin)
    await db.flush()

    return AdminProfileResponse(
        id=admin.id,
        email=admin.email,
        full_name=admin.full_name,
        role=admin.role,
        is_active=admin.is_active,
        mfa_enabled=admin.mfa_enabled,
        last_login_at=admin.last_login_at,
        created_at=admin.created_at,
    )


async def update_admin_user(
    db: AsyncSession,
    *,
    admin_id: UUID,
    data: AdminUserUpdateRequest,
) -> AdminProfileResponse:
    """Update an admin user's role, name, or active status."""
    result = await db.execute(
        select(AdminUser).where(AdminUser.id == admin_id)
    )
    admin = result.scalar_one_or_none()
    if not admin:
        raise AdminNotFoundError("Admin not found")

    if data.full_name is not None:
        admin.full_name = data.full_name
    if data.role is not None:
        admin.role = data.role
    if data.is_active is not None:
        admin.is_active = data.is_active

    db.add(admin)
    await db.flush()

    return AdminProfileResponse(
        id=admin.id,
        email=admin.email,
        full_name=admin.full_name,
        role=admin.role,
        is_active=admin.is_active,
        mfa_enabled=admin.mfa_enabled,
        last_login_at=admin.last_login_at,
        created_at=admin.created_at,
    )


async def list_admin_users(db: AsyncSession) -> AdminUserListResponse:
    """List all admin users."""
    result = await db.execute(
        select(AdminUser).order_by(AdminUser.created_at.desc())
    )
    admins = result.scalars().all()

    items = [
        AdminUserListItem(
            id=a.id,
            email=a.email,
            full_name=a.full_name,
            role=a.role,
            is_active=a.is_active,
            mfa_enabled=a.mfa_enabled,
            last_login_at=a.last_login_at,
            created_at=a.created_at,
        )
        for a in admins
    ]

    return AdminUserListResponse(
        admin_users=items,
        total_count=len(items),
    )


async def get_admin_profile(db: AsyncSession, admin_id: UUID) -> AdminProfileResponse:
    """Get admin profile by ID."""
    result = await db.execute(
        select(AdminUser).where(AdminUser.id == admin_id)
    )
    admin = result.scalar_one_or_none()
    if not admin:
        raise AdminNotFoundError("Admin not found")

    return AdminProfileResponse(
        id=admin.id,
        email=admin.email,
        full_name=admin.full_name,
        role=admin.role,
        is_active=admin.is_active,
        mfa_enabled=admin.mfa_enabled,
        last_login_at=admin.last_login_at,
        created_at=admin.created_at,
    )
