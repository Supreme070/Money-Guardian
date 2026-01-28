"""Factory for creating email providers."""

from typing import Literal

from app.services.email.base import EmailProvider
from app.services.email.gmail_provider import GmailProvider
from app.services.email.outlook_provider import OutlookProvider


def get_email_provider(
    provider: Literal["gmail", "outlook", "yahoo"],
) -> EmailProvider:
    """
    Get an email provider instance.

    Args:
        provider: Provider identifier

    Returns:
        EmailProvider implementation

    Raises:
        ValueError: If provider is not supported
        ValueError: If provider credentials are not configured
    """
    if provider == "gmail":
        return GmailProvider()
    elif provider == "outlook":
        return OutlookProvider()
    elif provider == "yahoo":
        # TODO: Implement YahooProvider
        raise ValueError(
            "Yahoo Mail provider not yet implemented. "
            "Use Gmail or Outlook instead."
        )
    else:
        raise ValueError(f"Unknown email provider: {provider}")


def get_supported_providers() -> list[Literal["gmail", "outlook"]]:
    """
    Get list of currently supported email providers.

    Returns:
        List of provider identifiers
    """
    return ["gmail", "outlook"]
