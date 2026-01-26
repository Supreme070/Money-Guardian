"""Daily Pulse schemas - strictly typed, no Any."""

from datetime import date, datetime
from decimal import Decimal
from typing import Literal
from uuid import UUID

from pydantic import BaseModel

from app.schemas.base import BaseSchema
from app.schemas.subscription import SubscriptionResponse


# Strict typing for pulse status
PulseStatus = Literal["safe", "caution", "freeze"]


class UpcomingCharge(BaseModel):
    """Upcoming charge in the next 7 days."""

    subscription_id: UUID
    name: str
    amount: Decimal
    date: date
    logo_url: str | None
    color: str | None
    is_warning: bool  # True if might cause overdraft


class PulseResponse(BaseModel):
    """Daily Pulse response - the main home screen data."""

    # Status
    status: PulseStatus
    status_message: str

    # Safe to spend
    safe_to_spend: Decimal
    current_balance: Decimal  # From connected accounts

    # Upcoming charges
    upcoming_charges: list[UpcomingCharge]
    upcoming_total: Decimal

    # Quick stats
    active_subscriptions_count: int
    monthly_subscription_total: Decimal
    unread_alerts_count: int

    # Calculation metadata
    calculated_at: datetime
    next_refresh_at: datetime


class PulseBreakdown(BaseModel):
    """Detailed breakdown of pulse calculation."""

    current_balance: Decimal
    upcoming_charges_7_days: Decimal
    upcoming_charges_30_days: Decimal
    average_daily_spend: Decimal
    predicted_balance_7_days: Decimal
    predicted_balance_30_days: Decimal
    overdraft_risk_date: date | None
    status: PulseStatus
    status_reason: str
