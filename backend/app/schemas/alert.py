"""Alert schemas - strictly typed, no Any."""

from datetime import datetime
from decimal import Decimal
from typing import Literal
from uuid import UUID

from pydantic import BaseModel

from app.schemas.base import BaseSchema, TimestampSchema, TenantSchema


# Strict typing for alert types
AlertTypeEnum = Literal[
    "upcoming_charge",
    "overdraft_warning",
    "price_increase",
    "trial_ending",
    "unused_subscription",
    "payment_failed",
    "large_charge",
]

# Strict typing for severity
AlertSeverityEnum = Literal["info", "warning", "critical"]


class AlertResponse(TimestampSchema, TenantSchema):
    """Alert response schema."""

    id: UUID
    user_id: UUID
    subscription_id: UUID | None
    alert_type: str
    severity: str
    title: str
    message: str
    amount: float | None
    alert_date: datetime | None
    is_read: bool
    is_dismissed: bool
    is_actioned: bool
    read_at: datetime | None
    dismissed_at: datetime | None


class AlertListResponse(BaseModel):
    """List of alerts with counts."""

    alerts: list[AlertResponse]
    total_count: int
    unread_count: int
    critical_count: int


class AlertMarkRead(BaseModel):
    """Mark alerts as read request."""

    alert_ids: list[UUID]


class AlertDismiss(BaseModel):
    """Dismiss alerts request."""

    alert_ids: list[UUID]
