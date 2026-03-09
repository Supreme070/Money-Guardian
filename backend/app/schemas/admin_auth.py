"""Admin authentication and audit log schemas.

Strict Pydantic models — no ``Any`` types.
"""

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

_ADMIN_CONFIG = ConfigDict(
    from_attributes=True,
    str_strip_whitespace=True,
    strict=True,
    ser_json_inf_nan="constants",
)

AdminRole = Literal["super_admin", "admin", "support", "viewer"]


# ---------------------------------------------------------------------------
# Admin Auth
# ---------------------------------------------------------------------------


class AdminLoginRequest(BaseModel):
    model_config = _ADMIN_CONFIG
    email: str = Field(..., max_length=255)
    password: str = Field(..., min_length=8, max_length=128)


class AdminLoginResponse(BaseModel):
    model_config = _ADMIN_CONFIG
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"
    requires_mfa: bool = False


class AdminMfaVerifyRequest(BaseModel):
    model_config = _ADMIN_CONFIG
    code: str = Field(..., min_length=6, max_length=6)
    session_token: str  # Temporary token from login


class AdminMfaSetupResponse(BaseModel):
    model_config = _ADMIN_CONFIG
    secret: str  # Base32 TOTP secret
    qr_uri: str  # otpauth:// URI for QR code


class AdminMfaConfirmRequest(BaseModel):
    model_config = _ADMIN_CONFIG
    code: str = Field(..., min_length=6, max_length=6)


class AdminRefreshRequest(BaseModel):
    model_config = _ADMIN_CONFIG
    refresh_token: str


class AdminTokenResponse(BaseModel):
    model_config = _ADMIN_CONFIG
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"


class AdminProfileResponse(BaseModel):
    model_config = _ADMIN_CONFIG
    id: UUID
    email: str
    full_name: str
    role: AdminRole
    is_active: bool
    mfa_enabled: bool
    last_login_at: datetime | None
    created_at: datetime


# ---------------------------------------------------------------------------
# Admin User Management (super_admin only)
# ---------------------------------------------------------------------------


class AdminUserCreateRequest(BaseModel):
    model_config = _ADMIN_CONFIG
    email: str = Field(..., max_length=255)
    password: str = Field(..., min_length=12, max_length=128)
    full_name: str = Field(..., min_length=1, max_length=255)
    role: AdminRole


class AdminUserUpdateRequest(BaseModel):
    model_config = _ADMIN_CONFIG
    full_name: str | None = Field(default=None, max_length=255)
    role: AdminRole | None = None
    is_active: bool | None = None


class AdminUserListItem(BaseModel):
    model_config = _ADMIN_CONFIG
    id: UUID
    email: str
    full_name: str
    role: AdminRole
    is_active: bool
    mfa_enabled: bool
    last_login_at: datetime | None
    created_at: datetime


class AdminUserListResponse(BaseModel):
    model_config = _ADMIN_CONFIG
    admin_users: list[AdminUserListItem]
    total_count: int


# ---------------------------------------------------------------------------
# Audit Log
# ---------------------------------------------------------------------------


class AuditLogEntry(BaseModel):
    model_config = _ADMIN_CONFIG
    id: UUID
    admin_user_id: UUID | None
    admin_email: str | None  # Denormalized for display
    admin_name: str | None
    action: str
    entity_type: str
    entity_id: UUID | None
    details: dict[str, str | int | bool | None]
    ip_address: str
    created_at: datetime


class AuditLogResponse(BaseModel):
    model_config = _ADMIN_CONFIG
    entries: list[AuditLogEntry]
    total_count: int
    page: int
    page_size: int
