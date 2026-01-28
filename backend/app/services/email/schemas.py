"""Strictly typed schemas for email provider responses (Zod pattern)."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class OAuthTokenResponse(BaseModel):
    """OAuth token response from email provider."""

    access_token: str = Field(..., min_length=1)
    refresh_token: str | None = None
    expires_in: int = Field(..., ge=0)  # Seconds until expiration
    token_type: str = Field(default="Bearer")
    scope: str | None = None  # Space-separated scopes


class EmailAddress(BaseModel):
    """Parsed email address with optional display name."""

    address: str = Field(..., min_length=1)
    name: str | None = None


class EmailMessage(BaseModel):
    """Email message from provider."""

    message_id: str = Field(..., min_length=1)
    thread_id: str | None = None
    from_address: str = Field(..., min_length=1)
    from_name: str | None = None
    to_addresses: list[str] = Field(default_factory=list)
    subject: str
    snippet: str | None = None  # Preview text
    body_plain: str | None = None
    body_html: str | None = None
    received_at: datetime
    labels: list[str] = Field(default_factory=list)  # Gmail labels / Outlook categories
    is_read: bool = False
    has_attachments: bool = False


class EmailSearchResult(BaseModel):
    """Result from searching emails."""

    messages: list[EmailMessage]
    next_page_token: str | None = None
    result_size_estimate: int = 0


class UserProfile(BaseModel):
    """Email account profile information."""

    email_address: str = Field(..., min_length=1)
    display_name: str | None = None


# Known subscription senders database
class KnownSender(BaseModel):
    """Known subscription service sender."""

    domain: str = Field(..., min_length=1)
    name: str = Field(..., min_length=1)
    category: Literal[
        "streaming",
        "software",
        "cloud_storage",
        "gaming",
        "news_media",
        "productivity",
        "fitness",
        "food_delivery",
        "music",
        "education",
        "finance",
        "shopping",
        "other",
    ]
    logo_url: str | None = None


# Subscription detection result
class DetectedSubscription(BaseModel):
    """Subscription detected from email parsing."""

    email_type: Literal[
        "subscription_confirmation",
        "receipt",
        "billing_reminder",
        "price_change",
        "trial_ending",
        "payment_failed",
        "cancellation",
        "renewal_notice",
        "other",
    ]
    confidence_score: float = Field(..., ge=0.0, le=1.0)
    merchant_name: str | None = None
    amount: float | None = None
    currency: str | None = None
    billing_cycle: Literal["weekly", "monthly", "quarterly", "yearly"] | None = None
    next_billing_date: datetime | None = None
    source_email_id: str = Field(..., min_length=1)
