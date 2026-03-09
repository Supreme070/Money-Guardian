"""Admin notification schemas — strict Pydantic models, no ``Any`` types."""

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


class SendNotificationRequest(BaseModel):
    model_config = _ADMIN_CONFIG
    notification_type: Literal["push", "email", "both"]
    target_type: Literal["user", "tier", "all"]
    target_ids: list[str] | None = Field(
        default=None,
        description="List of user UUIDs. Required when target_type is 'user'.",
    )
    target_tier: str | None = Field(
        default=None,
        description="Subscription tier. Required when target_type is 'tier'.",
    )
    title: str = Field(..., min_length=1, max_length=255)
    body: str = Field(..., min_length=1)


class NotificationResponse(BaseModel):
    model_config = _ADMIN_CONFIG
    id: UUID
    admin_user_id: UUID | None
    notification_type: str
    target_type: str
    target_ids: list[str]
    target_tier: str | None
    title: str
    body: str
    sent_count: int
    failed_count: int
    status: str
    created_at: datetime


class NotificationListResponse(BaseModel):
    model_config = _ADMIN_CONFIG
    notifications: list[NotificationResponse]
    total_count: int
