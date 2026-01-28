"""User schemas - strictly typed, no Any."""

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field

from app.schemas.base import BaseSchema, TimestampSchema, TenantSchema


# Subscription tier types
SubscriptionTierType = Literal["free", "pro", "premium"]


class UserResponse(TimestampSchema, TenantSchema):
    """User response schema."""

    id: UUID
    email: EmailStr
    full_name: str | None
    is_active: bool
    is_verified: bool
    last_login_at: datetime | None
    push_notifications_enabled: bool
    email_notifications_enabled: bool
    subscription_tier: SubscriptionTierType = "free"
    subscription_expires_at: datetime | None = None
    onboarding_completed: bool = False


class UserUpdate(BaseModel):
    """User update request."""

    full_name: str | None = Field(default=None, max_length=255)
    push_notifications_enabled: bool | None = None
    email_notifications_enabled: bool | None = None
    onboarding_completed: bool | None = None


class UserSettingsResponse(BaseSchema):
    """User settings response."""

    push_notifications_enabled: bool
    email_notifications_enabled: bool
    tier: SubscriptionTierType
