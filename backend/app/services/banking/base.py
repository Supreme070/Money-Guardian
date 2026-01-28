"""Abstract base class for banking providers (Plaid/Mono/Stitch)."""

from abc import ABC, abstractmethod
from datetime import date
from typing import Literal

from app.services.banking.schemas import (
    LinkTokenResponse,
    ExchangeTokenResponse,
    AccountInfo,
    BalanceInfo,
    TransactionSyncResponse,
    RecurringTransactionInfo,
)


class BankingProvider(ABC):
    """
    Abstract base class for banking data providers.

    All methods are async and return strictly typed Pydantic models.
    Implementations: PlaidProvider, MonoProvider, StitchProvider
    """

    @property
    @abstractmethod
    def provider_name(self) -> Literal["plaid", "mono", "stitch", "truelayer", "tink"]:
        """Return the provider identifier."""
        pass

    @property
    @abstractmethod
    def supported_countries(self) -> list[str]:
        """Return list of supported country codes (ISO 3166-1 alpha-2)."""
        pass

    @abstractmethod
    async def create_link_token(
        self,
        user_id: str,
        client_name: str = "Money Guardian",
        redirect_uri: str | None = None,
    ) -> LinkTokenResponse:
        """
        Create a link token for initiating the provider's Link flow.

        Args:
            user_id: Unique identifier for the user (from our system)
            client_name: Name to display in the Link UI
            redirect_uri: OAuth redirect URI (required for some providers)

        Returns:
            LinkTokenResponse with link_token and expiration
        """
        pass

    @abstractmethod
    async def exchange_public_token(
        self,
        public_token: str,
    ) -> ExchangeTokenResponse:
        """
        Exchange public token from Link for access token.

        Args:
            public_token: Token received from successful Link completion

        Returns:
            ExchangeTokenResponse with access_token, item_id, and accounts
        """
        pass

    @abstractmethod
    async def get_accounts(
        self,
        access_token: str,
    ) -> list[AccountInfo]:
        """
        Get all accounts for a connection.

        Args:
            access_token: Decrypted access token

        Returns:
            List of AccountInfo objects
        """
        pass

    @abstractmethod
    async def get_balances(
        self,
        access_token: str,
        account_ids: list[str] | None = None,
    ) -> list[BalanceInfo]:
        """
        Get current balances for accounts.

        Args:
            access_token: Decrypted access token
            account_ids: Optional filter for specific accounts

        Returns:
            List of BalanceInfo objects
        """
        pass

    @abstractmethod
    async def sync_transactions(
        self,
        access_token: str,
        cursor: str | None = None,
    ) -> TransactionSyncResponse:
        """
        Sync transactions using incremental updates.

        Uses cursor-based pagination for efficient updates.

        Args:
            access_token: Decrypted access token
            cursor: Cursor from previous sync (None for initial sync)

        Returns:
            TransactionSyncResponse with added/modified/removed transactions
        """
        pass

    @abstractmethod
    async def get_transactions(
        self,
        access_token: str,
        start_date: date,
        end_date: date,
        account_ids: list[str] | None = None,
    ) -> list:
        """
        Get transactions for a date range.

        Args:
            access_token: Decrypted access token
            start_date: Start of date range
            end_date: End of date range
            account_ids: Optional filter for specific accounts

        Returns:
            List of TransactionInfo objects
        """
        pass

    @abstractmethod
    async def get_recurring_transactions(
        self,
        access_token: str,
        account_ids: list[str] | None = None,
    ) -> list[RecurringTransactionInfo]:
        """
        Get detected recurring transaction streams.

        Useful for automatic subscription detection.

        Args:
            access_token: Decrypted access token
            account_ids: Optional filter for specific accounts

        Returns:
            List of RecurringTransactionInfo objects
        """
        pass

    @abstractmethod
    async def remove_connection(
        self,
        access_token: str,
    ) -> bool:
        """
        Remove/unlink a connection.

        Args:
            access_token: Decrypted access token

        Returns:
            True if successful
        """
        pass

    async def refresh_access_token(
        self,
        access_token: str,
    ) -> str | None:
        """
        Refresh access token if provider supports it.

        Default implementation returns None (no refresh needed).
        Override in providers that support token refresh.

        Args:
            access_token: Current access token

        Returns:
            New access token or None if refresh not supported/needed
        """
        return None
