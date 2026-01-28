"""Email services for subscription detection via OAuth email scanning."""

from app.services.email.base import EmailProvider
from app.services.email.factory import get_email_provider, get_supported_providers
from app.services.email.gmail_provider import GmailProvider, GmailProviderError
from app.services.email.outlook_provider import OutlookProvider, OutlookProviderError
from app.services.email.schemas import (
    OAuthTokenResponse,
    EmailAddress,
    EmailMessage,
    EmailSearchResult,
    UserProfile,
    KnownSender,
    DetectedSubscription,
)

__all__ = [
    # Base
    "EmailProvider",
    # Factory
    "get_email_provider",
    "get_supported_providers",
    # Providers
    "GmailProvider",
    "GmailProviderError",
    "OutlookProvider",
    "OutlookProviderError",
    # Schemas
    "OAuthTokenResponse",
    "EmailAddress",
    "EmailMessage",
    "EmailSearchResult",
    "UserProfile",
    "KnownSender",
    "DetectedSubscription",
]
