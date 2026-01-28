"""Tink banking provider implementation for EU-wide coverage.

Tink (Visa-backed) covers 2000+ banks across 19 European countries.
Uses Tink API v1 for account and transaction access.
"""

from datetime import date, datetime, timedelta, timezone
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


class TinkProviderError(Exception):
    """Exception raised for Tink API errors."""

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


class TinkProvider(BankingProvider):
    """
    Tink implementation of BankingProvider.

    Supports broad EU coverage through Visa's Tink platform.
    Uses Tink API v1 endpoints.
    """

    _ENV_URLS: dict[str, str] = {
        "sandbox": "https://api.tink.com",
        "production": "https://api.tink.com",
    }

    def __init__(self) -> None:
        """Initialize TinkProvider with settings."""
        self._client_id = settings.tink_client_id
        self._client_secret = settings.tink_client_secret
        self._redirect_uri = settings.tink_redirect_uri
        self._environment = settings.tink_environment

        if not self._client_id or not self._client_secret:
            raise ValueError("Tink credentials not configured")

        self._api_base = self._ENV_URLS[self._environment]

    @property
    def provider_name(self) -> Literal["tink"]:
        """Return provider identifier."""
        return "tink"

    @property
    def supported_countries(self) -> list[str]:
        """Return supported country codes."""
        return [
            "SE", "FI", "NO", "DK",  # Nordics
            "DE", "FR", "ES", "IT",  # Major EU
            "NL", "BE", "AT", "PT",  # Western EU
            "PL", "LT", "EE", "LV",  # Eastern EU
            "GB", "IE",              # UK & Ireland (also supported)
        ]

    async def _get_client_token(self) -> str:
        """Get a client access token using client credentials flow."""
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{self._api_base}/api/v1/oauth/token",
                data={
                    "client_id": self._client_id,
                    "client_secret": self._client_secret,
                    "grant_type": "client_credentials",
                    "scope": "authorization:grant,user:create",
                },
            )
            if response.status_code != 200:
                raise TinkProviderError(
                    message="Failed to get client token",
                    status_code=response.status_code,
                )
            return response.json()["access_token"]

    async def create_link_token(
        self,
        user_id: str,
        client_name: str = "Money Guardian",
        redirect_uri: str | None = None,
    ) -> LinkTokenResponse:
        """
        Create Tink Link URL for the user.

        Tink uses Tink Link (their hosted UI) for bank connections.
        We return the Tink Link URL as the link_token.
        """
        client_token = await self._get_client_token()

        # Create a Tink user (or get existing)
        async with httpx.AsyncClient(timeout=30.0) as client:
            # Create authorization grant
            response = await client.post(
                f"{self._api_base}/api/v1/oauth/authorization-grant",
                headers={"Authorization": f"Bearer {client_token}"},
                json={
                    "external_user_id": user_id,
                    "scope": "accounts:read,transactions:read,balances:read",
                },
            )
            if response.status_code not in (200, 201):
                raise TinkProviderError(
                    message="Failed to create authorization grant",
                    status_code=response.status_code,
                )
            grant_data = response.json()

        # Build Tink Link URL
        tink_link_params: dict[str, str] = {
            "client_id": self._client_id or "",
            "redirect_uri": redirect_uri or self._redirect_uri,
            "authorization_code": grant_data.get("code", ""),
            "market": "SE",  # Default market, client should override
            "scope": "accounts:read,transactions:read,balances:read",
        }

        link_url = f"https://link.tink.com/1.0/transactions/connect-accounts?{urlencode(tink_link_params)}"

        return LinkTokenResponse(
            link_token=link_url,
            expiration=datetime.now(timezone.utc).isoformat(),
        )

    async def exchange_public_token(
        self,
        public_token: str,
    ) -> ExchangeTokenResponse:
        """
        Exchange Tink authorization code for access token.

        The public_token is the authorization code from Tink Link callback.
        """
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{self._api_base}/api/v1/oauth/token",
                data={
                    "client_id": self._client_id,
                    "client_secret": self._client_secret,
                    "grant_type": "authorization_code",
                    "code": public_token,
                },
            )
            if response.status_code != 200:
                error_data = response.json()
                raise TinkProviderError(
                    message=error_data.get("errorMessage", "Token exchange failed"),
                    error_code=error_data.get("errorCode"),
                    status_code=response.status_code,
                )
            token_data = response.json()

        access_token: str = token_data["access_token"]

        # Fetch accounts
        accounts = await self.get_accounts(access_token)

        # Get provider info
        provider_info = await self._get_provider_info(access_token)

        return ExchangeTokenResponse(
            access_token=access_token,
            item_id=provider_info.get("financialInstitutionId", "unknown"),
            institution_id=provider_info.get("financialInstitutionId"),
            institution_name=provider_info.get("financialInstitutionName", "Unknown Bank"),
            institution_logo=None,
            accounts=accounts,
        )

    async def get_accounts(
        self,
        access_token: str,
    ) -> list[AccountInfo]:
        """Get all accounts from Tink."""
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(
                f"{self._api_base}/data/v2/accounts",
                headers={"Authorization": f"Bearer {access_token}"},
            )
            if response.status_code != 200:
                raise TinkProviderError(
                    message="Failed to fetch accounts",
                    status_code=response.status_code,
                )
            data = response.json()

        accounts: list[AccountInfo] = []
        for acc in data.get("accounts", []):
            balances = acc.get("balances", {})
            booked = balances.get("booked", {})
            available = balances.get("available", {})

            account_type = self._map_account_type(acc.get("type", ""))

            accounts.append(
                AccountInfo(
                    account_id=acc["id"],
                    name=acc.get("name", "Account"),
                    official_name=acc.get("name"),
                    mask=acc.get("identifiers", {}).get("maskedPan"),
                    account_type=account_type,
                    account_subtype=acc.get("type"),
                    current_balance=self._parse_amount(booked),
                    available_balance=self._parse_amount(available),
                    limit=None,
                    currency=booked.get("amount", {}).get("currencyCode", "EUR"),
                )
            )

        return accounts

    async def get_balances(
        self,
        access_token: str,
        account_ids: list[str] | None = None,
    ) -> list[BalanceInfo]:
        """Get balances via account data (Tink includes balances in account response)."""
        accounts = await self.get_accounts(access_token)
        now = datetime.now(timezone.utc)

        balances: list[BalanceInfo] = []
        for acc in accounts:
            if account_ids and acc.account_id not in account_ids:
                continue
            balances.append(
                BalanceInfo(
                    account_id=acc.account_id,
                    current_balance=acc.current_balance,
                    available_balance=acc.available_balance,
                    limit=acc.limit,
                    currency=acc.currency,
                    last_updated=now,
                )
            )

        return balances

    async def sync_transactions(
        self,
        access_token: str,
        cursor: str | None = None,
    ) -> TransactionSyncResponse:
        """Sync transactions from Tink."""
        if cursor:
            try:
                since_date = date.fromisoformat(cursor)
            except ValueError:
                since_date = (datetime.now(timezone.utc) - timedelta(days=90)).date()
        else:
            since_date = (datetime.now(timezone.utc) - timedelta(days=90)).date()

        all_transactions: list[TransactionInfo] = []
        page_token: str | None = None

        async with httpx.AsyncClient(timeout=60.0) as client:
            while True:
                params: dict[str, str] = {
                    "bookedDateGte": since_date.isoformat(),
                    "bookedDateLte": date.today().isoformat(),
                    "pageSize": "100",
                }
                if page_token:
                    params["pageToken"] = page_token

                response = await client.get(
                    f"{self._api_base}/data/v2/transactions",
                    params=params,
                    headers={"Authorization": f"Bearer {access_token}"},
                )
                if response.status_code != 200:
                    break

                data = response.json()
                for tx in data.get("transactions", []):
                    all_transactions.append(self._parse_transaction(tx))

                page_token = data.get("nextPageToken")
                if not page_token:
                    break

        return TransactionSyncResponse(
            added=all_transactions,
            modified=[],
            removed=[],
            cursor=date.today().isoformat(),
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
        result = await self.sync_transactions(
            access_token=access_token,
            cursor=start_date.isoformat(),
        )
        transactions = result.added
        if account_ids:
            transactions = [t for t in transactions if t.account_id in account_ids]
        return [t for t in transactions if t.transaction_date <= end_date]

    async def get_recurring_transactions(
        self,
        access_token: str,
        account_ids: list[str] | None = None,
    ) -> list[RecurringTransactionInfo]:
        """
        Tink does not expose recurring transaction detection via API.

        Our AI Flag Service handles this based on transaction patterns.
        """
        return []

    async def remove_connection(
        self,
        access_token: str,
    ) -> bool:
        """Remove Tink connection by deleting credentials."""
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                await client.delete(
                    f"{self._api_base}/api/v1/credentials",
                    headers={"Authorization": f"Bearer {access_token}"},
                )
            return True
        except httpx.HTTPError:
            return False

    async def _get_provider_info(self, access_token: str) -> dict[str, str]:
        """Get provider (bank) info for the connected account."""
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.get(
                    f"{self._api_base}/api/v1/credentials",
                    headers={"Authorization": f"Bearer {access_token}"},
                )
                if response.status_code == 200:
                    data = response.json()
                    credentials = data.get("credentials", [])
                    if credentials:
                        cred = credentials[0]
                        return {
                            "financialInstitutionId": cred.get("providerName", "unknown"),
                            "financialInstitutionName": cred.get("providerName", "Unknown Bank"),
                        }
        except httpx.HTTPError:
            pass
        return {
            "financialInstitutionId": "unknown",
            "financialInstitutionName": "Unknown Bank",
        }

    def _parse_transaction(self, tx: dict) -> TransactionInfo:
        """Parse Tink transaction into TransactionInfo."""
        amount_data = tx.get("amount", {})
        amount_value = float(amount_data.get("value", {}).get("unscaledValue", 0))
        scale = int(amount_data.get("value", {}).get("scale", 0))
        actual_amount = amount_value / (10 ** scale) if scale > 0 else amount_value

        transaction_type: Literal["debit", "credit"] = (
            "debit" if actual_amount < 0 else "credit"
        )

        tx_date_str = tx.get("dates", {}).get("booked", "")
        try:
            tx_date = date.fromisoformat(tx_date_str)
        except (ValueError, AttributeError):
            tx_date = date.today()

        descriptions = tx.get("descriptions", {})
        display_desc = descriptions.get("display", "Unknown")

        return TransactionInfo(
            transaction_id=tx.get("id", ""),
            account_id=tx.get("accountId", ""),
            name=display_desc,
            merchant_name=tx.get("merchantInformation", {}).get("merchantName"),
            amount=Decimal(str(abs(actual_amount))),
            currency=amount_data.get("currencyCode", "EUR"),
            transaction_type=transaction_type,
            transaction_date=tx_date,
            posted_date=None,
            category=tx.get("categories", {}).get("pfm", {}).get("name"),
            category_id=tx.get("categories", {}).get("pfm", {}).get("id"),
            is_pending=tx.get("status") == "PENDING",
            logo_url=None,
            is_recurring=False,
            recurrence_stream_id=None,
        )

    @staticmethod
    def _map_account_type(
        tink_type: str,
    ) -> Literal["checking", "savings", "credit", "loan", "investment", "other"]:
        """Map Tink account type to our type."""
        mapping: dict[str, Literal["checking", "savings", "credit", "loan", "investment", "other"]] = {
            "CHECKING": "checking",
            "SAVINGS": "savings",
            "CREDIT_CARD": "credit",
            "LOAN": "loan",
            "INVESTMENT": "investment",
            "PENSION": "investment",
            "MORTGAGE": "loan",
        }
        return mapping.get(tink_type.upper(), "other")

    @staticmethod
    def _parse_amount(balance_data: dict) -> Decimal | None:
        """Parse Tink balance amount."""
        amount = balance_data.get("amount", {})
        value = amount.get("value", {})
        unscaled = value.get("unscaledValue")
        scale = value.get("scale", 0)
        if unscaled is None:
            return None
        return Decimal(str(float(unscaled) / (10 ** int(scale))))
