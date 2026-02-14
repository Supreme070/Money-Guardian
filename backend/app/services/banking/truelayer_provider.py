"""TrueLayer banking provider implementation for UK/Europe."""

from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Literal
from urllib.parse import urlencode

import httpx

from app.core.config import settings
from app.services.banking.base import BankingProvider
from app.services.banking.schemas import (
    LinkTokenResponse,
    ExchangeTokenResponse,
    AccountInfo,
    BalanceInfo,
    TransactionInfo,
    TransactionSyncResponse,
    RecurringTransactionInfo,
)


class TrueLayerProviderError(Exception):
    """Exception raised for TrueLayer API errors."""

    def __init__(
        self,
        message: str,
        error_code: str | None = None,
        status_code: int | None = None,
    ) -> None:
        self.message = message
        self.error_code = error_code
        self.status_code = status_code
        super().__init__(self.message)


class TrueLayerProvider(BankingProvider):
    """
    TrueLayer implementation of BankingProvider.

    Supports UK and EU countries.
    Uses TrueLayer Data API v1 for account and transaction access.
    """

    _ENV_URLS: dict[str, str] = {
        "sandbox": "https://api.truelayer-sandbox.com",
        "live": "https://api.truelayer.com",
    }

    _AUTH_URLS: dict[str, str] = {
        "sandbox": "https://auth.truelayer-sandbox.com",
        "live": "https://auth.truelayer.com",
    }

    def __init__(self) -> None:
        """Initialize TrueLayerProvider with settings."""
        self._client_id = settings.truelayer_client_id
        self._client_secret = settings.truelayer_client_secret
        self._redirect_uri = settings.truelayer_redirect_uri
        self._environment = settings.truelayer_environment

        if not self._client_id or not self._client_secret:
            raise ValueError("TrueLayer credentials not configured")

        self._api_base = self._ENV_URLS[self._environment]
        self._auth_base = self._AUTH_URLS[self._environment]

    @property
    def provider_name(self) -> Literal["truelayer"]:
        """Return provider identifier."""
        return "truelayer"

    @property
    def supported_countries(self) -> list[str]:
        """Return supported country codes."""
        return [
            "GB",  # United Kingdom
            "IE",  # Ireland
            "FR",  # France
            "DE",  # Germany
            "ES",  # Spain
            "IT",  # Italy
            "NL",  # Netherlands
            "LT",  # Lithuania
            "PL",  # Poland
            "PT",  # Portugal
            "AT",  # Austria
            "BE",  # Belgium
            "FI",  # Finland
            "NO",  # Norway
        ]

    async def create_link_token(
        self,
        user_id: str,
        client_name: str = "Money Guardian",
        redirect_uri: str | None = None,
    ) -> LinkTokenResponse:
        """
        Create a TrueLayer auth link for the user.

        TrueLayer uses OAuth-based auth links (not token-based like Plaid).
        We return the authorization URL as the link_token.
        """
        scopes = [
            "info",
            "accounts",
            "balance",
            "transactions",
            "offline_access",  # Allows refresh token
        ]

        params: dict[str, str] = {
            "response_type": "code",
            "client_id": self._client_id or "",
            "redirect_uri": redirect_uri or self._redirect_uri,
            "scope": " ".join(scopes),
            "state": user_id,  # Pass user_id as state for callback
            "providers": "uk-ob-all uk-oauth-all",  # All UK banks
        }

        auth_url = f"{self._auth_base}/?{urlencode(params)}"

        return LinkTokenResponse(
            link_token=auth_url,
            expiration=datetime.now(timezone.utc).isoformat(),
        )

    async def exchange_public_token(
        self,
        public_token: str,
    ) -> ExchangeTokenResponse:
        """
        Exchange TrueLayer authorization code for access token.

        In TrueLayer, the 'public_token' is actually the authorization code
        received from the OAuth callback.
        """
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{self._auth_base}/connect/token",
                data={
                    "grant_type": "authorization_code",
                    "client_id": self._client_id,
                    "client_secret": self._client_secret,
                    "redirect_uri": self._redirect_uri,
                    "code": public_token,
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )

            if response.status_code != 200:
                error_data = response.json()
                raise TrueLayerProviderError(
                    message=error_data.get("error_description", "Token exchange failed"),
                    error_code=error_data.get("error"),
                    status_code=response.status_code,
                )

            token_data = response.json()

        access_token: str = token_data["access_token"]

        # Fetch accounts with the new access token
        accounts = await self.get_accounts(access_token)

        # Get metadata (TrueLayer doesn't have a direct "item" concept)
        metadata = await self._get_metadata(access_token)
        provider_display_name = metadata.get("display_name", "Unknown Bank")
        provider_id = metadata.get("provider_id", "unknown")
        logo_uri = metadata.get("logo_uri")

        return ExchangeTokenResponse(
            access_token=access_token,
            item_id=provider_id,  # Use provider_id as item_id
            institution_id=provider_id,
            institution_name=provider_display_name,
            institution_logo=logo_uri,
            accounts=accounts,
        )

    async def get_accounts(
        self,
        access_token: str,
    ) -> list[AccountInfo]:
        """Get all accounts from TrueLayer."""
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(
                f"{self._api_base}/data/v1/accounts",
                headers={"Authorization": f"Bearer {access_token}"},
            )

            if response.status_code != 200:
                raise TrueLayerProviderError(
                    message="Failed to fetch accounts",
                    status_code=response.status_code,
                )

            data = response.json()

        accounts: list[AccountInfo] = []
        for acc in data.get("results", []):
            account_type = self._map_account_type(acc.get("account_type", ""))

            accounts.append(
                AccountInfo(
                    account_id=acc["account_id"],
                    name=acc.get("display_name", "Account"),
                    official_name=acc.get("description"),
                    mask=acc.get("account_number", {}).get("number", "")[-4:] or None,
                    account_type=account_type,
                    account_subtype=acc.get("account_type"),
                    current_balance=None,  # Fetched separately
                    available_balance=None,
                    limit=None,
                    currency=acc.get("currency", "GBP"),
                )
            )

        return accounts

    async def get_balances(
        self,
        access_token: str,
        account_ids: list[str] | None = None,
    ) -> list[BalanceInfo]:
        """Get balances for all accounts."""
        accounts = await self.get_accounts(access_token)
        target_ids = account_ids or [acc.account_id for acc in accounts]

        balances: list[BalanceInfo] = []
        now = datetime.now(timezone.utc)

        async with httpx.AsyncClient(timeout=30.0) as client:
            for account_id in target_ids:
                try:
                    response = await client.get(
                        f"{self._api_base}/data/v1/accounts/{account_id}/balance",
                        headers={"Authorization": f"Bearer {access_token}"},
                    )
                    if response.status_code == 200:
                        data = response.json()
                        for bal in data.get("results", []):
                            balances.append(
                                BalanceInfo(
                                    account_id=account_id,
                                    current_balance=self._to_decimal(bal.get("current")),
                                    available_balance=self._to_decimal(bal.get("available")),
                                    limit=self._to_decimal(bal.get("overdraft")),
                                    currency=bal.get("currency", "GBP"),
                                    last_updated=now,
                                )
                            )
                except httpx.HTTPError:
                    continue

        return balances

    async def sync_transactions(
        self,
        access_token: str,
        cursor: str | None = None,
    ) -> TransactionSyncResponse:
        """
        Sync transactions from TrueLayer.

        TrueLayer doesn't have cursor-based sync like Plaid.
        We fetch recent transactions and return them as 'added'.
        The cursor is used to track the last sync date.
        """
        # Parse cursor as last sync date, default to 90 days ago
        if cursor:
            try:
                since_date = date.fromisoformat(cursor)
            except ValueError:
                since_date = date.today().replace(day=1)
        else:
            from datetime import timedelta
            since_date = (datetime.now(timezone.utc) - timedelta(days=90)).date()

        accounts = await self.get_accounts(access_token)
        all_transactions: list[TransactionInfo] = []

        async with httpx.AsyncClient(timeout=60.0) as client:
            for account in accounts:
                try:
                    response = await client.get(
                        f"{self._api_base}/data/v1/accounts/{account.account_id}/transactions",
                        params={
                            "from": since_date.isoformat(),
                            "to": date.today().isoformat(),
                        },
                        headers={"Authorization": f"Bearer {access_token}"},
                    )
                    if response.status_code == 200:
                        data = response.json()
                        for tx in data.get("results", []):
                            all_transactions.append(
                                self._parse_transaction(tx, account.account_id)
                            )
                except httpx.HTTPError:
                    continue

        # New cursor is today's date
        new_cursor = date.today().isoformat()

        return TransactionSyncResponse(
            added=all_transactions,
            modified=[],
            removed=[],
            cursor=new_cursor,
            has_more=False,
        )

    async def get_transactions(
        self,
        access_token: str,
        start_date: date,
        end_date: date,
        account_ids: list[str] | None = None,
    ) -> list[TransactionInfo]:
        """Get transactions for a date range."""
        accounts = await self.get_accounts(access_token)
        target_accounts = (
            [a for a in accounts if a.account_id in account_ids]
            if account_ids
            else accounts
        )

        transactions: list[TransactionInfo] = []

        async with httpx.AsyncClient(timeout=60.0) as client:
            for account in target_accounts:
                try:
                    response = await client.get(
                        f"{self._api_base}/data/v1/accounts/{account.account_id}/transactions",
                        params={
                            "from": start_date.isoformat(),
                            "to": end_date.isoformat(),
                        },
                        headers={"Authorization": f"Bearer {access_token}"},
                    )
                    if response.status_code == 200:
                        data = response.json()
                        for tx in data.get("results", []):
                            transactions.append(
                                self._parse_transaction(tx, account.account_id)
                            )
                except httpx.HTTPError:
                    continue

        return transactions

    async def get_recurring_transactions(
        self,
        access_token: str,
        account_ids: list[str] | None = None,
    ) -> list[RecurringTransactionInfo]:
        """
        TrueLayer does not have native recurring transaction detection.

        Return empty list - our AI Flag Service handles recurring detection
        based on transaction patterns.
        """
        return []

    async def remove_connection(
        self,
        access_token: str,
    ) -> bool:
        """
        TrueLayer connections are removed by revoking the token.

        The user can also revoke via their bank's consent dashboard.
        """
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                await client.delete(
                    f"{self._api_base}/data/v1/tokens/revoke",
                    headers={"Authorization": f"Bearer {access_token}"},
                )
            return True
        except httpx.HTTPError:
            return False

    async def refresh_access_token(
        self,
        access_token: str,
    ) -> str | None:
        """
        Refresh TrueLayer access token using refresh token.

        Note: In TrueLayer, the refresh_token is separate from access_token.
        This method expects the refresh_token to be passed as access_token
        (as stored in our encrypted field).
        """
        # The access_token stored is actually the initial access_token.
        # TrueLayer returns refresh_token separately.
        # For now, return None - the service layer handles token refresh
        # through the exchange flow.
        return None

    async def _get_metadata(self, access_token: str) -> dict[str, str]:
        """Get provider metadata for the connected account."""
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.get(
                    f"{self._api_base}/data/v1/me",
                    headers={"Authorization": f"Bearer {access_token}"},
                )
                if response.status_code == 200:
                    data = response.json()
                    results = data.get("results", [])
                    if results:
                        provider = results[0].get("provider", {})
                        return {
                            "display_name": provider.get("display_name", "Unknown Bank"),
                            "provider_id": provider.get("provider_id", "unknown"),
                            "logo_uri": provider.get("logo_uri", ""),
                        }
        except httpx.HTTPError:
            pass
        return {"display_name": "Unknown Bank", "provider_id": "unknown", "logo_uri": ""}

    def _parse_transaction(
        self,
        tx: dict[str, object],
        account_id: str,
    ) -> TransactionInfo:
        """Parse TrueLayer transaction into TransactionInfo."""
        amount = float(tx.get("amount", 0))
        tx_type = tx.get("transaction_type", "")

        # TrueLayer: DEBIT = money out, CREDIT = money in
        transaction_type: Literal["debit", "credit"] = (
            "debit" if tx_type.upper() == "DEBIT" else "credit"
        )

        tx_date_str = tx.get("timestamp", "")
        try:
            tx_date = datetime.fromisoformat(tx_date_str.replace("Z", "+00:00")).date()
        except (ValueError, AttributeError):
            tx_date = date.today()

        return TransactionInfo(
            transaction_id=tx.get("transaction_id", ""),
            account_id=account_id,
            name=tx.get("description", "Unknown"),
            merchant_name=tx.get("merchant_name"),
            amount=Decimal(str(abs(amount))),
            currency=tx.get("currency", "GBP"),
            transaction_type=transaction_type,
            transaction_date=tx_date,
            posted_date=None,
            category=tx.get("transaction_category", ""),
            category_id=None,
            is_pending=tx.get("transaction_classification", []) == ["Pending"],
            logo_url=None,
            is_recurring=False,
            recurrence_stream_id=None,
        )

    @staticmethod
    def _map_account_type(
        tl_type: str,
    ) -> Literal["checking", "savings", "credit", "loan", "investment", "other"]:
        """Map TrueLayer account type to our type."""
        mapping: dict[str, Literal["checking", "savings", "credit", "loan", "investment", "other"]] = {
            "TRANSACTION": "checking",
            "SAVINGS": "savings",
            "BUSINESS_TRANSACTION": "checking",
            "BUSINESS_SAVINGS": "savings",
        }
        return mapping.get(tl_type.upper(), "other")

    @staticmethod
    def _to_decimal(value: float | int | None) -> Decimal | None:
        """Convert numeric value to Decimal."""
        if value is None:
            return None
        return Decimal(str(value))
