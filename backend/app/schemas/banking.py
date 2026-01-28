"""Banking schemas - strictly typed, no Any (Zod pattern)."""

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field

from app.schemas.base import BaseSchema, TimestampSchema


# Request Schemas

class CreateLinkTokenRequest(BaseModel):
    """Request to create a link token."""

    provider: Literal["plaid", "mono", "stitch", "truelayer", "tink"] = Field(
        default="plaid",
        description="Banking provider to use",
    )


class ExchangeTokenRequest(BaseModel):
    """Request to exchange public token for access token."""

    public_token: str = Field(
        ...,
        min_length=1,
        description="Public token from successful Link completion",
    )
    provider: Literal["plaid", "mono", "stitch", "truelayer", "tink"] = Field(
        default="plaid",
        description="Banking provider",
    )


class UpdateAccountRequest(BaseModel):
    """Request to update account settings."""

    is_primary: bool | None = Field(
        default=None,
        description="Mark as primary account",
    )
    include_in_pulse: bool | None = Field(
        default=None,
        description="Include in Daily Pulse balance calculation",
    )


class ConvertRecurringToSubscriptionRequest(BaseModel):
    """Request to convert a recurring bank transaction to a subscription."""

    stream_id: str = Field(
        ...,
        min_length=1,
        description="Stream ID of the recurring transaction",
    )
    name: str | None = Field(
        default=None,
        min_length=1,
        max_length=255,
        description="Override subscription name",
    )
    amount: float | None = Field(
        default=None,
        gt=0,
        description="Override amount",
    )
    billing_cycle: Literal["weekly", "monthly", "quarterly", "yearly"] | None = Field(
        default=None,
        description="Override billing cycle",
    )
    next_billing_date: datetime | None = Field(
        default=None,
        description="Override next billing date",
    )
    color: str | None = Field(
        default=None,
        max_length=7,
        description="Subscription color (hex)",
    )
    description: str | None = Field(
        default=None,
        max_length=500,
        description="Subscription description",
    )


# Response Schemas

class LinkTokenResponse(BaseModel):
    """Response containing link token."""

    link_token: str = Field(..., description="Token for initiating Link flow")
    expiration: str = Field(..., description="Token expiration timestamp")
    provider: str = Field(..., description="Banking provider")


class BankAccountResponse(BaseSchema):
    """Bank account response."""

    id: UUID
    name: str
    official_name: str | None
    mask: str | None
    account_type: str
    account_subtype: str | None
    current_balance: float | None
    available_balance: float | None
    limit: float | None
    currency: str
    is_active: bool
    is_primary: bool
    include_in_pulse: bool
    balance_updated_at: datetime | None


class BankConnectionResponse(TimestampSchema):
    """Bank connection response."""

    id: UUID
    provider: str
    institution_name: str
    institution_logo: str | None
    status: str
    error_code: str | None
    error_message: str | None
    last_sync_at: datetime | None
    accounts: list[BankAccountResponse]


class BankConnectionListResponse(BaseModel):
    """List of bank connections with total balance."""

    connections: list[BankConnectionResponse]
    total_balance: float = Field(..., description="Combined balance from all accounts")
    account_count: int = Field(..., description="Total number of accounts")


class SyncTransactionsResponse(BaseModel):
    """Response from transaction sync."""

    new_transactions: int = Field(..., description="Number of new transactions synced")
    connection_id: UUID


class RecurringTransactionResponse(BaseModel):
    """Recurring transaction detected by provider."""

    stream_id: str
    account_id: str
    description: str
    merchant_name: str | None
    average_amount: float
    currency: str
    frequency: str
    last_date: str
    next_expected_date: str | None
    is_active: bool


class RecurringTransactionsListResponse(BaseModel):
    """List of detected recurring transactions."""

    recurring_transactions: list[RecurringTransactionResponse]
    count: int


# Error Response for Pro Feature

class ProFeatureRequiredResponse(BaseModel):
    """Response when Pro feature is required."""

    detail: str = Field(..., description="Error message")
    upgrade_required: bool = Field(default=True)
    feature: str = Field(..., description="Feature that requires Pro")
    current_tier: str = Field(..., description="User's current tier")
