"""Email schemas - strictly typed, no Any (Zod pattern)."""

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field

from app.schemas.base import BaseSchema, TimestampSchema


# Email provider type
EmailProviderType = Literal["gmail", "outlook", "yahoo"]

# Email type for subscription detection
EmailType = Literal[
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

# Connection status type
ConnectionStatusType = Literal[
    "pending",
    "connected",
    "error",
    "disconnected",
    "requires_reauth",
]


# Request Schemas

class StartOAuthRequest(BaseModel):
    """Request to start OAuth flow."""

    provider: EmailProviderType = Field(
        ...,
        description="Email provider: gmail, outlook, yahoo",
    )
    redirect_uri: str = Field(
        ...,
        min_length=1,
        description="OAuth callback URL",
    )


class CompleteOAuthRequest(BaseModel):
    """Request to complete OAuth flow."""

    provider: EmailProviderType = Field(
        ...,
        description="Email provider",
    )
    code: str = Field(
        ...,
        min_length=1,
        description="Authorization code from OAuth callback",
    )
    redirect_uri: str = Field(
        ...,
        min_length=1,
        description="Must match the redirect_uri used in authorization",
    )
    state: str | None = Field(
        default=None,
        description="State token for CSRF validation",
    )


class ScanEmailsRequest(BaseModel):
    """Request to scan emails."""

    max_emails: int = Field(
        default=50,
        ge=1,
        le=200,
        description="Maximum emails to scan in this batch",
    )


class MarkEmailProcessedRequest(BaseModel):
    """Request to mark an email as processed."""

    subscription_id: UUID | None = Field(
        default=None,
        description="Linked subscription if created",
    )


class ConvertToSubscriptionRequest(BaseModel):
    """Request to convert a scanned email to a subscription."""

    # Optional overrides - if not provided, uses detected values
    name: str | None = Field(
        default=None,
        min_length=1,
        max_length=255,
        description="Override subscription name (uses detected merchant_name if not provided)",
    )
    amount: float | None = Field(
        default=None,
        gt=0,
        description="Override amount (uses detected_amount if not provided)",
    )
    billing_cycle: Literal["weekly", "monthly", "quarterly", "yearly"] | None = Field(
        default=None,
        description="Override billing cycle (uses detected billing_cycle if not provided)",
    )
    next_billing_date: datetime | None = Field(
        default=None,
        description="Override next billing date",
    )
    color: str | None = Field(
        default=None,
        max_length=7,
        description="Subscription color hex code",
    )
    description: str | None = Field(
        default=None,
        max_length=500,
        description="Optional notes",
    )


# Response Schemas

class OAuthUrlResponse(BaseModel):
    """Response containing OAuth authorization URL."""

    authorization_url: str = Field(..., description="URL to redirect user for OAuth")
    state: str = Field(..., description="State token for CSRF validation")
    provider: EmailProviderType


class EmailConnectionResponse(TimestampSchema):
    """Email connection response."""

    id: UUID
    provider: EmailProviderType
    email_address: str
    status: ConnectionStatusType
    error_message: str | None
    last_scan_at: datetime | None
    last_successful_scan_at: datetime | None
    scan_depth_days: int


class EmailConnectionListResponse(BaseModel):
    """List of email connections."""

    connections: list[EmailConnectionResponse]
    count: int = Field(..., description="Total number of connections")


class ScannedEmailResponse(BaseSchema):
    """Scanned email response."""

    id: UUID
    connection_id: UUID
    provider_message_id: str
    from_address: str
    from_name: str | None
    subject: str
    received_at: datetime
    email_type: EmailType
    confidence_score: float = Field(..., ge=0.0, le=1.0)
    merchant_name: str | None
    detected_amount: float | None
    currency: str | None
    billing_cycle: Literal["weekly", "monthly", "quarterly", "yearly"] | None
    next_billing_date: datetime | None
    is_processed: bool
    is_subscription_created: bool
    subscription_id: UUID | None


class ScannedEmailListResponse(BaseModel):
    """List of scanned emails."""

    emails: list[ScannedEmailResponse]
    count: int = Field(..., description="Total emails returned")
    has_more: bool = Field(default=False, description="More results available")


class ScanResultResponse(BaseModel):
    """Response from email scan operation."""

    connection_id: UUID
    emails_scanned: int = Field(..., description="Number of emails scanned")
    subscriptions_detected: int = Field(..., description="Number of subscriptions found")
    has_more: bool = Field(default=False, description="More emails to scan")


class SupportedProvidersResponse(BaseModel):
    """Response with supported email providers."""

    providers: list[EmailProviderType]


class KnownSenderResponse(BaseModel):
    """Known subscription sender."""

    domain: str
    name: str
    category: str
    logo_url: str | None


class KnownSendersListResponse(BaseModel):
    """List of known subscription senders."""

    senders: list[KnownSenderResponse]
    count: int


# Error Responses

class EmailConnectionErrorResponse(BaseModel):
    """Error response for email operations."""

    detail: str = Field(..., description="Error message")
    error_code: str | None = Field(default=None, description="Error code")


class ProFeatureRequiredResponse(BaseModel):
    """Response when Pro feature is required for email."""

    detail: str = Field(..., description="Error message")
    upgrade_required: bool = Field(default=True)
    feature: str = Field(default="email_scanning")
    current_tier: str = Field(..., description="User's current tier")
