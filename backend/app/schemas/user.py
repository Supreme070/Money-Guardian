"""User schemas - strictly typed, no Any."""

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field

from app.schemas.base import BaseSchema, TimestampSchema, TenantSchema


# Subscription tier types
SubscriptionTierType = Literal["free", "pro", "premium"]


class NotificationPreferences(BaseModel):
    """Granular notification type preferences.

    Each key controls whether that notification type is enabled.
    Defaults to True (all enabled) when not explicitly set.
    """

    overdraft_warnings: bool = True
    upcoming_charges: bool = True
    trial_endings: bool = True
    price_increases: bool = True
    unused_subscriptions: bool = True


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
    notification_preferences: NotificationPreferences = Field(
        default_factory=NotificationPreferences
    )
    subscription_tier: SubscriptionTierType = "free"
    subscription_expires_at: datetime | None = None
    onboarding_completed: bool = False
    terms_accepted_at: datetime | None = None
    privacy_accepted_at: datetime | None = None


class UserUpdate(BaseModel):
    """User update request."""

    full_name: str | None = Field(default=None, max_length=255)
    push_notifications_enabled: bool | None = None
    email_notifications_enabled: bool | None = None
    notification_preferences: NotificationPreferences | None = None
    onboarding_completed: bool | None = None


class UserSettingsResponse(BaseSchema):
    """User settings response."""

    push_notifications_enabled: bool
    email_notifications_enabled: bool
    notification_preferences: NotificationPreferences = Field(
        default_factory=NotificationPreferences
    )
    tier: SubscriptionTierType


class DataExportResponse(BaseModel):
    """GDPR Article 20 data export response."""

    user: UserResponse
    subscriptions: list[dict[str, object]]
    alerts: list[dict[str, object]]
    bank_connections: list[dict[str, object]]
    email_connections: list[dict[str, object]]
    exported_at: datetime
