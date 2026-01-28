"""Strictly typed schemas for banking provider responses (Zod pattern)."""

from datetime import date, datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field


class LinkTokenResponse(BaseModel):
    """Response from creating a link token for Plaid/Mono/Stitch Link."""

    link_token: str = Field(..., min_length=1)
    expiration: str = Field(..., min_length=1)


class AccountInfo(BaseModel):
    """Bank account information from provider."""

    account_id: str = Field(..., min_length=1)
    name: str = Field(..., min_length=1)
    official_name: str | None = None
    mask: str | None = None  # Last 4 digits
    account_type: Literal["checking", "savings", "credit", "loan", "investment", "other"]
    account_subtype: str | None = None
    current_balance: Decimal | None = None
    available_balance: Decimal | None = None
    limit: Decimal | None = None  # For credit cards
    currency: str = Field(default="USD", min_length=3, max_length=3)


class BalanceInfo(BaseModel):
    """Account balance information."""

    account_id: str = Field(..., min_length=1)
    current_balance: Decimal | None = None
    available_balance: Decimal | None = None
    limit: Decimal | None = None
    currency: str = Field(default="USD", min_length=3, max_length=3)
    last_updated: datetime


class ExchangeTokenResponse(BaseModel):
    """Response from exchanging public token for access token."""

    access_token: str = Field(..., min_length=1)  # Will be encrypted before storage
    item_id: str = Field(..., min_length=1)
    institution_id: str | None = None
    institution_name: str = Field(..., min_length=1)
    institution_logo: str | None = None
    accounts: list[AccountInfo]


class TransactionInfo(BaseModel):
    """Transaction information from provider."""

    transaction_id: str = Field(..., min_length=1)
    account_id: str = Field(..., min_length=1)
    name: str = Field(..., min_length=1)
    merchant_name: str | None = None
    amount: Decimal = Field(..., ge=0)
    currency: str = Field(default="USD", min_length=3, max_length=3)
    transaction_type: Literal["debit", "credit"]
    transaction_date: date
    posted_date: date | None = None
    category: str | None = None
    category_id: str | None = None
    is_pending: bool = False
    logo_url: str | None = None
    is_recurring: bool = False
    recurrence_stream_id: str | None = None


class RecurringTransactionInfo(BaseModel):
    """Recurring transaction stream information."""

    stream_id: str = Field(..., min_length=1)
    account_id: str = Field(..., min_length=1)
    description: str = Field(..., min_length=1)
    merchant_name: str | None = None
    average_amount: Decimal = Field(..., ge=0)
    currency: str = Field(default="USD", min_length=3, max_length=3)
    frequency: Literal["weekly", "biweekly", "monthly", "quarterly", "yearly", "irregular"]
    last_date: date
    next_expected_date: date | None = None
    category: str | None = None
    is_active: bool = True


class TransactionSyncResponse(BaseModel):
    """Response from syncing transactions."""

    added: list[TransactionInfo]
    modified: list[TransactionInfo]
    removed: list[str]  # List of transaction IDs
    cursor: str | None = None
    has_more: bool = False
