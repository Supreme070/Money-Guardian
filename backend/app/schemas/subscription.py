"""Subscription schemas - strictly typed, no Any."""

from datetime import date, datetime
from decimal import Decimal
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from app.schemas.base import BaseSchema, TimestampSchema, TenantSchema


# Strict typing for billing cycle
BillingCycleType = Literal["weekly", "monthly", "quarterly", "yearly"]

# Strict typing for AI flags
AIFlagType = Literal[
    "none",
    "unused",
    "duplicate",
    "price_increase",
    "trial_ending",
    "forgotten",
]

# Strict typing for source - supports all email providers
SourceType = Literal["manual", "plaid", "gmail", "outlook", "yahoo", "email", "ai_detected"]


class SubscriptionCreate(BaseModel):
    """Create subscription request."""

    name: str = Field(..., min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=1000)
    amount: Decimal = Field(..., gt=0)
    currency: str = Field(default="USD", min_length=3, max_length=3)
    billing_cycle: BillingCycleType
    next_billing_date: date
    start_date: date | None = None
    trial_end_date: date | None = None
    color: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")
    icon: str | None = Field(default=None, max_length=50)
    logo_url: str | None = Field(default=None, max_length=500)

    @field_validator("currency")
    @classmethod
    def validate_currency(cls, v: str) -> str:
        """Validate currency code."""
        return v.upper()


class SubscriptionUpdate(BaseModel):
    """Update subscription request."""

    name: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=1000)
    amount: Decimal | None = Field(default=None, gt=0)
    billing_cycle: BillingCycleType | None = None
    next_billing_date: date | None = None
    is_active: bool | None = None
    is_paused: bool | None = None
    color: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")
    icon: str | None = Field(default=None, max_length=50)
    logo_url: str | None = Field(default=None, max_length=500)


class SubscriptionResponse(TimestampSchema, TenantSchema):
    """Subscription response schema."""

    id: UUID
    user_id: UUID
    name: str
    description: str | None
    amount: float
    currency: str
    billing_cycle: str
    next_billing_date: date
    start_date: date | None
    trial_end_date: date | None
    is_active: bool
    is_paused: bool
    ai_flag: str
    ai_flag_reason: str | None
    last_usage_detected: datetime | None
    previous_amount: float | None
    source: str
    color: str | None
    icon: str | None
    logo_url: str | None


class SubscriptionListResponse(BaseModel):
    """List of subscriptions with summary."""

    subscriptions: list[SubscriptionResponse]
    total_count: int
    monthly_total: float
    yearly_total: float
    flagged_count: int


class AIFlagSummaryResponse(BaseModel):
    """AI flag analysis summary response."""

    total_subscriptions: int = Field(..., description="Total active subscriptions")
    flagged_count: int = Field(..., description="Total flagged subscriptions")
    unused_count: int = Field(..., description="Subscriptions not used recently")
    duplicate_count: int = Field(..., description="Potential duplicate subscriptions")
    price_increase_count: int = Field(..., description="Subscriptions with price increases")
    trial_ending_count: int = Field(..., description="Trials ending soon")
    forgotten_count: int = Field(..., description="Forgotten subscriptions")
    potential_monthly_savings: float = Field(..., description="Potential savings per month")


class AnalyzeResponse(BaseModel):
    """Response from AI flag analysis."""

    flagged_count: int = Field(..., description="Number of subscriptions flagged")
    message: str = Field(..., description="Analysis result message")
