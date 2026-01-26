"""User schemas - strictly typed, no Any."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field

from app.schemas.base import BaseSchema, TimestampSchema, TenantSchema


class UserResponse(BaseSchema, TimestampSchema, TenantSchema):
    """User response schema."""

    id: UUID
    email: EmailStr
    full_name: str | None
    is_active: bool
    is_verified: bool
    last_login_at: datetime | None
    push_notifications_enabled: bool
    email_notifications_enabled: bool


class UserUpdate(BaseModel):
    """User update request."""

    full_name: str | None = Field(default=None, max_length=255)
    push_notifications_enabled: bool | None = None
    email_notifications_enabled: bool | None = None


class UserSettingsResponse(BaseSchema):
    """User settings response."""

    push_notifications_enabled: bool
    email_notifications_enabled: bool
    tier: str  # From tenant
