"""Pydantic schemas for request/response validation."""

from app.schemas.auth import (
    LoginRequest,
    RegisterRequest,
    TokenResponse,
    RefreshRequest,
)
from app.schemas.user import (
    UserResponse,
    UserUpdate,
)
from app.schemas.subscription import (
    SubscriptionCreate,
    SubscriptionUpdate,
    SubscriptionResponse,
    SubscriptionListResponse,
)
from app.schemas.alert import (
    AlertResponse,
    AlertListResponse,
    AlertMarkRead,
)
from app.schemas.pulse import (
    PulseResponse,
    PulseStatus,
)
from app.schemas.webhook import (
    PlaidWebhookBody,
    PlaidWebhookError,
    StripeCheckoutSessionData,
    StripeInvoiceData,
    StripeSubscriptionData,
)

__all__ = [
    # Auth
    "LoginRequest",
    "RegisterRequest",
    "TokenResponse",
    "RefreshRequest",
    # User
    "UserResponse",
    "UserUpdate",
    # Subscription
    "SubscriptionCreate",
    "SubscriptionUpdate",
    "SubscriptionResponse",
    "SubscriptionListResponse",
    # Alert
    "AlertResponse",
    "AlertListResponse",
    "AlertMarkRead",
    # Pulse
    "PulseResponse",
    "PulseStatus",
    # Webhooks
    "PlaidWebhookBody",
    "PlaidWebhookError",
    "StripeCheckoutSessionData",
    "StripeInvoiceData",
    "StripeSubscriptionData",
]
