"""Plaid banking provider implementation for USA/Canada."""

from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Literal

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


class PlaidProviderError(Exception):
    """Exception raised for Plaid API errors."""

    def __init__(
        self,
        message: str,
        error_code: str | None = None,
        error_type: str | None = None,
    ) -> None:
        self.message = message
        self.error_code = error_code
        self.error_type = error_type
        super().__init__(self.message)


class PlaidProvider(BankingProvider):
    """
    Plaid implementation of BankingProvider.

    Supports USA and Canada.
    Uses Plaid API v2 endpoints.
    """

    # Plaid environment URLs
    _ENV_URLS: dict[str, str] = {
        "sandbox": "https://sandbox.plaid.com",
        "development": "https://development.plaid.com",
        "production": "https://production.plaid.com",
    }

    def __init__(self) -> None:
        """Initialize PlaidProvider with settings."""
        self._client_id = settings.plaid_client_id
        self._secret = settings.plaid_secret
        self._environment = settings.plaid_environment
        self._webhook_url = settings.plaid_webhook_url

        if not self._client_id or not self._secret:
            raise ValueError("Plaid credentials not configured")

        self._base_url = self._ENV_URLS[self._environment]

    @property
    def provider_name(self) -> Literal["plaid"]:
        """Return provider identifier."""
        return "plaid"

    @property
    def supported_countries(self) -> list[str]:
        """Return supported country codes."""
        return ["US", "CA"]

    async def _request(
        self,
        endpoint: str,
        data: dict[str, object],
        timeout: float = 30.0,
    ) -> dict[str, object]:
        """
        Make authenticated request to Plaid API.

        Args:
            endpoint: API endpoint path (e.g., "/link/token/create")
            data: Request body data
            timeout: Request timeout in seconds

        Returns:
            Response JSON as dict

        Raises:
            PlaidProviderError: If API returns an error
        """
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.post(
                f"{self._base_url}{endpoint}",
                json={
                    "client_id": self._client_id,
                    "secret": self._secret,
                    **data,
                },
                headers={"Content-Type": "application/json"},
            )

            result = response.json()

            if response.status_code != 200:
                error_code = result.get("error_code")
                error_message = result.get("error_message", "Unknown error")
                error_type = result.get("error_type")
                raise PlaidProviderError(
                    message=error_message,
                    error_code=error_code,
                    error_type=error_type,
                )

            return result

    async def create_link_token(
        self,
        user_id: str,
        client_name: str = "Money Guardian",
        redirect_uri: str | None = None,
    ) -> LinkTokenResponse:
        """Create Plaid Link token."""
        request_data: dict = {
            "user": {"client_user_id": user_id},
            "client_name": client_name,
            "products": ["transactions"],
            "country_codes": self.supported_countries,
            "language": "en",
        }

        if redirect_uri:
            request_data["redirect_uri"] = redirect_uri

        if self._webhook_url:
            request_data["webhook"] = self._webhook_url

        result = await self._request("/link/token/create", request_data)

        return LinkTokenResponse(
            link_token=result["link_token"],
            expiration=result["expiration"],
        )

    async def exchange_public_token(
        self,
        public_token: str,
    ) -> ExchangeTokenResponse:
        """Exchange public token for access token and fetch accounts."""
        # Exchange the public token
        exchange_result = await self._request(
            "/item/public_token/exchange",
            {"public_token": public_token},
        )

        access_token: str = exchange_result["access_token"]
        item_id: str = exchange_result["item_id"]

        # Get item details
        item_result = await self._request(
            "/item/get",
            {"access_token": access_token},
        )
        institution_id: str | None = item_result.get("item", {}).get("institution_id")

        # Get institution info
        institution_name = "Unknown Bank"
        institution_logo: str | None = None

        if institution_id:
            try:
                inst_result = await self._request(
                    "/institutions/get_by_id",
                    {
                        "institution_id": institution_id,
                        "country_codes": self.supported_countries,
                        "options": {"include_optional_metadata": True},
                    },
                )
                institution = inst_result.get("institution", {})
                institution_name = institution.get("name", "Unknown Bank")
                institution_logo = institution.get("logo")
            except PlaidProviderError:
                # Non-fatal: continue without institution details
                pass

        # Get accounts
        accounts_result = await self._request(
            "/accounts/get",
            {"access_token": access_token},
        )

        accounts: list[AccountInfo] = []
        for acc in accounts_result.get("accounts", []):
            balances = acc.get("balances", {})
            account_type = self._map_account_type(acc.get("type", "other"))

            accounts.append(
                AccountInfo(
                    account_id=acc["account_id"],
                    name=acc["name"],
                    official_name=acc.get("official_name"),
                    mask=acc.get("mask"),
                    account_type=account_type,
                    account_subtype=acc.get("subtype"),
                    current_balance=self._to_decimal(balances.get("current")),
                    available_balance=self._to_decimal(balances.get("available")),
                    limit=self._to_decimal(balances.get("limit")),
                    currency=balances.get("iso_currency_code", "USD") or "USD",
                )
            )

        return ExchangeTokenResponse(
            access_token=access_token,
            item_id=item_id,
            institution_id=institution_id,
            institution_name=institution_name,
            institution_logo=institution_logo,
            accounts=accounts,
        )

    async def get_accounts(
        self,
        access_token: str,
    ) -> list[AccountInfo]:
        """Get all accounts for a connection."""
        result = await self._request(
            "/accounts/get",
            {"access_token": access_token},
        )

        accounts: list[AccountInfo] = []
        for acc in result.get("accounts", []):
            balances = acc.get("balances", {})
            account_type = self._map_account_type(acc.get("type", "other"))

            accounts.append(
                AccountInfo(
                    account_id=acc["account_id"],
                    name=acc["name"],
                    official_name=acc.get("official_name"),
                    mask=acc.get("mask"),
                    account_type=account_type,
                    account_subtype=acc.get("subtype"),
                    current_balance=self._to_decimal(balances.get("current")),
                    available_balance=self._to_decimal(balances.get("available")),
                    limit=self._to_decimal(balances.get("limit")),
                    currency=balances.get("iso_currency_code", "USD") or "USD",
                )
            )

        return accounts

    async def get_balances(
        self,
        access_token: str,
        account_ids: list[str] | None = None,
    ) -> list[BalanceInfo]:
        """Get current balances for accounts."""
        request_data: dict = {"access_token": access_token}
        if account_ids:
            request_data["options"] = {"account_ids": account_ids}

        result = await self._request("/accounts/balance/get", request_data)
        now = datetime.now(timezone.utc)

        balances: list[BalanceInfo] = []
        for acc in result.get("accounts", []):
            acc_balances = acc.get("balances", {})
            balances.append(
                BalanceInfo(
                    account_id=acc["account_id"],
                    current_balance=self._to_decimal(acc_balances.get("current")),
                    available_balance=self._to_decimal(acc_balances.get("available")),
                    limit=self._to_decimal(acc_balances.get("limit")),
                    currency=acc_balances.get("iso_currency_code", "USD") or "USD",
                    last_updated=now,
                )
            )

        return balances

    async def sync_transactions(
        self,
        access_token: str,
        cursor: str | None = None,
    ) -> TransactionSyncResponse:
        """Sync transactions using Plaid's incremental sync."""
        request_data: dict = {"access_token": access_token}
        if cursor:
            request_data["cursor"] = cursor

        result = await self._request("/transactions/sync", request_data)

        added: list[TransactionInfo] = []
        for tx in result.get("added", []):
            added.append(self._parse_transaction(tx))

        modified: list[TransactionInfo] = []
        for tx in result.get("modified", []):
            modified.append(self._parse_transaction(tx))

        removed: list[str] = [
            tx.get("transaction_id", "")
            for tx in result.get("removed", [])
            if tx.get("transaction_id")
        ]

        return TransactionSyncResponse(
            added=added,
            modified=modified,
            removed=removed,
            cursor=result.get("next_cursor"),
            has_more=result.get("has_more", False),
        )

    async def get_transactions(
        self,
        access_token: str,
        start_date: date,
        end_date: date,
        account_ids: list[str] | None = None,
    ) -> list[TransactionInfo]:
        """Get transactions for a date range."""
        request_data: dict = {
            "access_token": access_token,
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
        }
        if account_ids:
            request_data["options"] = {"account_ids": account_ids}

        result = await self._request("/transactions/get", request_data)

        transactions: list[TransactionInfo] = []
        for tx in result.get("transactions", []):
            transactions.append(self._parse_transaction(tx))

        return transactions

    async def get_recurring_transactions(
        self,
        access_token: str,
        account_ids: list[str] | None = None,
    ) -> list[RecurringTransactionInfo]:
        """Get detected recurring transaction streams."""
        request_data: dict = {"access_token": access_token}
        if account_ids:
            request_data["account_ids"] = account_ids

        result = await self._request("/transactions/recurring/get", request_data)

        recurring: list[RecurringTransactionInfo] = []

        # Process outflow streams (subscriptions are typically outflows)
        for stream in result.get("outflow_streams", []):
            amount_info = stream.get("average_amount", {})
            frequency = self._map_frequency(stream.get("frequency"))

            recurring.append(
                RecurringTransactionInfo(
                    stream_id=stream["stream_id"],
                    account_id=stream["account_id"],
                    description=stream.get("description", "Unknown"),
                    merchant_name=stream.get("merchant_name"),
                    average_amount=self._to_decimal(amount_info.get("amount")) or Decimal("0"),
                    currency=amount_info.get("iso_currency_code", "USD") or "USD",
                    frequency=frequency,
                    last_date=date.fromisoformat(stream["last_date"]),
                    next_expected_date=(
                        date.fromisoformat(stream["predicted_next_date"])
                        if stream.get("predicted_next_date")
                        else None
                    ),
                    category=stream.get("category", [None])[0] if stream.get("category") else None,
                    is_active=stream.get("is_active", True),
                )
            )

        return recurring

    async def remove_connection(
        self,
        access_token: str,
    ) -> bool:
        """Remove/unlink a Plaid item."""
        try:
            await self._request("/item/remove", {"access_token": access_token})
            return True
        except PlaidProviderError:
            return False

    def _parse_transaction(self, tx: dict[str, object]) -> TransactionInfo:
        """Parse Plaid transaction into TransactionInfo."""
        amount = tx.get("amount", 0)
        # Plaid uses positive amounts for debits (money going out)
        transaction_type: Literal["debit", "credit"] = "debit" if amount > 0 else "credit"

        # Check for recurring indicator
        personal_finance = tx.get("personal_finance_category", {})
        is_recurring = personal_finance.get("confidence_level") == "VERY_HIGH"

        return TransactionInfo(
            transaction_id=tx["transaction_id"],
            account_id=tx["account_id"],
            name=tx.get("name", "Unknown"),
            merchant_name=tx.get("merchant_name"),
            amount=Decimal(str(abs(amount))),
            currency=tx.get("iso_currency_code", "USD") or "USD",
            transaction_type=transaction_type,
            transaction_date=date.fromisoformat(tx["date"]),
            posted_date=(
                date.fromisoformat(tx["authorized_date"])
                if tx.get("authorized_date")
                else None
            ),
            category=tx.get("category", [None])[0] if tx.get("category") else None,
            category_id=tx.get("category_id"),
            is_pending=tx.get("pending", False),
            logo_url=tx.get("logo_url"),
            is_recurring=is_recurring,
            recurrence_stream_id=personal_finance.get("detailed"),
        )

    @staticmethod
    def _map_account_type(
        plaid_type: str,
    ) -> Literal["checking", "savings", "credit", "loan", "investment", "other"]:
        """Map Plaid account type to our AccountType."""
        mapping: dict[str, Literal["checking", "savings", "credit", "loan", "investment", "other"]] = {
            "depository": "checking",  # Will be refined by subtype
            "credit": "credit",
            "loan": "loan",
            "investment": "investment",
            "brokerage": "investment",
        }
        return mapping.get(plaid_type, "other")

    @staticmethod
    def _map_frequency(
        plaid_frequency: str | None,
    ) -> Literal["weekly", "biweekly", "monthly", "quarterly", "yearly", "irregular"]:
        """Map Plaid frequency to our frequency type."""
        if not plaid_frequency:
            return "irregular"

        mapping: dict[str, Literal["weekly", "biweekly", "monthly", "quarterly", "yearly", "irregular"]] = {
            "WEEKLY": "weekly",
            "BIWEEKLY": "biweekly",
            "SEMI_MONTHLY": "biweekly",
            "MONTHLY": "monthly",
            "QUARTERLY": "quarterly",
            "ANNUALLY": "yearly",
        }
        return mapping.get(plaid_frequency.upper(), "irregular")

    @staticmethod
    def _to_decimal(value: float | int | None) -> Decimal | None:
        """Convert numeric value to Decimal."""
        if value is None:
            return None
        return Decimal(str(value))
