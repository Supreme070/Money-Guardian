"""Abstract base class for email providers (Gmail/Outlook/Yahoo)."""

from abc import ABC, abstractmethod
from datetime import datetime
from typing import Literal

from app.services.email.schemas import (
    OAuthTokenResponse,
    EmailMessage,
    EmailSearchResult,
    UserProfile,
)


class EmailProvider(ABC):
    """
    Abstract base class for email data providers.

    All methods are async and return strictly typed Pydantic models.
    Implementations: GmailProvider, OutlookProvider, YahooProvider
    """

    @property
    @abstractmethod
    def provider_name(self) -> Literal["gmail", "outlook", "yahoo"]:
        """Return the provider identifier."""
        pass

    @property
    @abstractmethod
    def oauth_authorize_url(self) -> str:
        """Return the OAuth authorization URL."""
        pass

    @property
    @abstractmethod
    def oauth_token_url(self) -> str:
        """Return the OAuth token exchange URL."""
        pass

    @property
    @abstractmethod
    def required_scopes(self) -> list[str]:
        """Return list of required OAuth scopes for email reading."""
        pass

    @abstractmethod
    def get_authorization_url(
        self,
        state: str,
        redirect_uri: str,
    ) -> str:
        """
        Build OAuth authorization URL.

        Args:
            state: CSRF protection state token
            redirect_uri: OAuth callback URL

        Returns:
            Full authorization URL for user redirect
        """
        pass

    @abstractmethod
    async def exchange_code_for_tokens(
        self,
        code: str,
        redirect_uri: str,
    ) -> OAuthTokenResponse:
        """
        Exchange authorization code for access/refresh tokens.

        Args:
            code: Authorization code from OAuth callback
            redirect_uri: Must match the redirect_uri used in authorization

        Returns:
            OAuthTokenResponse with access_token, refresh_token, expires_in
        """
        pass

    @abstractmethod
    async def refresh_access_token(
        self,
        refresh_token: str,
    ) -> OAuthTokenResponse:
        """
        Refresh an expired access token.

        Args:
            refresh_token: Refresh token from initial OAuth

        Returns:
            OAuthTokenResponse with new access_token
        """
        pass

    @abstractmethod
    async def get_user_profile(
        self,
        access_token: str,
    ) -> UserProfile:
        """
        Get the email account profile (email address, name).

        Args:
            access_token: Valid access token

        Returns:
            UserProfile with email_address and display_name
        """
        pass

    @abstractmethod
    async def search_subscription_emails(
        self,
        access_token: str,
        since_date: datetime,
        page_token: str | None = None,
        max_results: int = 50,
    ) -> EmailSearchResult:
        """
        Search for subscription-related emails.

        Searches inbox, all mail, spam, and promotions for:
        - Subscription confirmations
        - Payment receipts
        - Billing reminders
        - Price change notices
        - Trial ending warnings

        Args:
            access_token: Valid access token
            since_date: Only return emails after this date
            page_token: Pagination token for next page
            max_results: Maximum emails to return per page

        Returns:
            EmailSearchResult with messages and next_page_token
        """
        pass

    @abstractmethod
    async def get_email_by_id(
        self,
        access_token: str,
        message_id: str,
    ) -> EmailMessage | None:
        """
        Get a specific email by ID.

        Args:
            access_token: Valid access token
            message_id: Provider's message ID

        Returns:
            EmailMessage or None if not found
        """
        pass

    @abstractmethod
    async def revoke_access(
        self,
        access_token: str,
    ) -> bool:
        """
        Revoke OAuth access (disconnect).

        Args:
            access_token: Token to revoke

        Returns:
            True if successful
        """
        pass

    def build_search_query(self, since_date: datetime) -> str:
        """
        Build a search query for subscription emails.

        Override in subclass if provider uses different query syntax.

        Args:
            since_date: Only search emails after this date

        Returns:
            Search query string
        """
        # Gmail-style query that searches ALL folders (inbox, spam,
        # promotions, updates, all mail).  Gmail's messages.list
        # already searches everywhere by default – we don't restrict
        # with `in:inbox`.  Adding `category:` terms explicitly
        # ensures promotions-tab and updates-tab emails are matched
        # even when engagement signals deprioritize them.
        date_str = since_date.strftime("%Y/%m/%d")
        return (
            f"after:{date_str} ("
            # Keyword matches (works across all folders)
            "subject:(subscription OR receipt OR invoice OR payment OR billing OR renewal) "
            "OR from:(noreply OR no-reply OR billing OR invoice OR receipt OR payment OR subscription) "
            "OR subject:(\"your order\" OR \"thank you for your purchase\" OR \"payment received\") "
            "OR subject:(\"trial ending\" OR \"trial expires\" OR \"free trial\") "
            "OR subject:(\"price change\" OR \"price increase\" OR \"new pricing\") "
            "OR subject:(\"upcoming charge\" OR \"auto-renewal\" OR \"will be charged\") "
            "OR subject:(\"cancellation\" OR \"cancelled\" OR \"membership\") "
            # Gmail category labels — catches promo/update emails
            "OR category:promotions "
            "OR category:updates "
            # Gmail smart labels for purchase receipts
            "OR label:^smartlabel_receipt "
            "OR label:^smartlabel_order "
            "OR label:^smartlabel_finance"
            ")"
        )
