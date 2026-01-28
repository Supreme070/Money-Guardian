"""Mono banking provider implementation for African markets.

Mono Connect covers:
- Nigeria (NG) - 50+ banks
- Ghana (GH) - Expanding coverage
- Kenya (KE) - Expanding coverage

API Documentation: https://docs.mono.co/
"""

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
    TransactionSyncResponse,
    TransactionInfo,
    RecurringTransactionInfo,
)


class MonoProviderError(Exception):
    """Exception raised for Mono API errors."""

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


class MonoProvider(BankingProvider):
    """
    Mono Connect implementation of BankingProvider.

    Mono provides open banking APIs for Africa, primarily Nigeria.
    Uses Mono Connect Widget for bank linking.
    """

    # Mono API endpoints
    _BASE_URL = "https://api.withmono.com"

    # Supported countries (ISO 3166-1 alpha-2)
    _SUPPORTED_COUNTRIES = ["NG", "GH", "KE"]

    def __init__(self) -> None:
        """Initialize MonoProvider with settings."""
        self._secret_key = settings.mono_secret_key

        if not self._secret_key:
            raise ValueError("Mono secret key not configured")

    @property
    def provider_name(self) -> Literal["mono"]:
        """Return provider identifier."""
        return "mono"

    @property
    def supported_countries(self) -> list[str]:
        """Return supported countries."""
        return self._SUPPORTED_COUNTRIES

    async def _request(
        self,
        method: Literal["GET", "POST", "DELETE"],
        endpoint: str,
        data: dict | None = None,
        timeout: float = 30.0,
    ) -> dict:
        """Make an authenticated request to Mono API."""
        headers = {
            "mono-sec-key": self._secret_key,
            "Content-Type": "application/json",
        }

        async with httpx.AsyncClient(timeout=timeout) as client:
            if method == "GET":
                response = await client.get(
                    f"{self._BASE_URL}{endpoint}",
                    headers=headers,
                )
            elif method == "POST":
                response = await client.post(
                    f"{self._BASE_URL}{endpoint}",
                    headers=headers,
                    json=data or {},
                )
            elif method == "DELETE":
                response = await client.delete(
                    f"{self._BASE_URL}{endpoint}",
                    headers=headers,
                )
            else:
                raise ValueError(f"Unsupported HTTP method: {method}")

            if response.status_code >= 400:
                error_data = response.json() if response.content else {}
                raise MonoProviderError(
                    message=error_data.get("message", "Mono API error"),
                    error_code=error_data.get("code"),
                    status_code=response.status_code,
                )

            return response.json() if response.content else {}

    async def create_link_token(
        self,
        user_id: str,
        client_name: str = "Money Guardian",
        redirect_uri: str | None = None,
    ) -> LinkTokenResponse:
        """
        Create a Mono Connect widget session.

        Mono uses a different flow - returns a public key for the widget.
        The widget generates a code on successful auth.

        Note: Mono's actual token is the mono_public_key from settings,
        but we create a session reference for tracking.
        """
        # Mono Connect uses a client-side widget with a public key
        # Generate a session reference for tracking
        session_data = await self._request(
            "POST",
            "/v1/connect/session",
            data={
                "customer": user_id,
                "app": client_name,
            },
        )

        return LinkTokenResponse(
            link_token=session_data.get("id", settings.mono_public_key or ""),
            expiration=datetime.now(timezone.utc).isoformat(),
        )

    async def exchange_public_token(
        self,
        public_token: str,
    ) -> ExchangeTokenResponse:
        """
        Exchange Mono Connect code for account access.

        After successful Mono Connect widget completion, the widget returns
        a code that we exchange for an account ID (which serves as access token).
        """
        # Exchange code for account ID
        response = await self._request(
            "POST",
            "/account/auth",
            data={"code": public_token},
        )

        account_id = response.get("id", "")

        # Get account details
        account_info = await self._request(
            "GET",
            f"/accounts/{account_id}",
        )

        # Get institution info
        account_data = account_info.get("account", {})
        institution = account_data.get("institution", {})

        # Map account type
        account_type = self._map_account_type(account_data.get("type", ""))

        # Build account info
        accounts = [
            AccountInfo(
                account_id=account_id,
                name=account_data.get("name", "Account"),
                official_name=account_data.get("name"),
                mask=account_data.get("accountNumber", "")[-4:] if account_data.get("accountNumber") else None,
                account_type=account_type,
                account_subtype=account_data.get("type"),
                current_balance=Decimal(str(account_data.get("balance", 0))) / 100,  # Mono uses kobo/cents
                available_balance=Decimal(str(account_data.get("balance", 0))) / 100,
                limit=None,
                currency=account_data.get("currency", "NGN"),
            )
        ]

        return ExchangeTokenResponse(
            access_token=account_id,  # Mono uses account ID as the identifier
            item_id=account_id,
            institution_id=institution.get("_id"),
            institution_name=institution.get("name", "Bank"),
            institution_logo=institution.get("icon"),
            accounts=accounts,
        )

    async def get_accounts(
        self,
        access_token: str,
    ) -> list[AccountInfo]:
        """Get account information."""
        response = await self._request(
            "GET",
            f"/accounts/{access_token}",
        )

        account_data = response.get("account", {})
        account_type = self._map_account_type(account_data.get("type", ""))

        return [
            AccountInfo(
                account_id=access_token,
                name=account_data.get("name", "Account"),
                official_name=account_data.get("name"),
                mask=account_data.get("accountNumber", "")[-4:] if account_data.get("accountNumber") else None,
                account_type=account_type,
                account_subtype=account_data.get("type"),
                current_balance=Decimal(str(account_data.get("balance", 0))) / 100,
                available_balance=Decimal(str(account_data.get("balance", 0))) / 100,
                limit=None,
                currency=account_data.get("currency", "NGN"),
            )
        ]

    async def get_balances(
        self,
        access_token: str,
        account_ids: list[str] | None = None,
    ) -> list[BalanceInfo]:
        """Get current balances."""
        response = await self._request(
            "GET",
            f"/accounts/{access_token}",
        )

        account_data = response.get("account", {})

        return [
            BalanceInfo(
                account_id=access_token,
                current_balance=Decimal(str(account_data.get("balance", 0))) / 100,
                available_balance=Decimal(str(account_data.get("balance", 0))) / 100,
                limit=None,
                currency=account_data.get("currency", "NGN"),
                last_updated=datetime.now(timezone.utc),
            )
        ]

    async def sync_transactions(
        self,
        access_token: str,
        cursor: str | None = None,
    ) -> TransactionSyncResponse:
        """
        Sync transactions from Mono.

        Mono doesn't support cursor-based sync natively,
        so we fetch recent transactions and track what's new.
        """
        # Fetch transactions (Mono returns last 6 months by default)
        params = {}
        if cursor:
            params["paginate"] = "true"
            params["cursor"] = cursor

        response = await self._request(
            "GET",
            f"/accounts/{access_token}/transactions",
        )

        transactions_data = response.get("data", [])
        paging = response.get("paging", {})

        added_transactions: list[TransactionInfo] = []

        for tx in transactions_data:
            transaction_info = self._map_transaction(tx, access_token)
            added_transactions.append(transaction_info)

        return TransactionSyncResponse(
            added=added_transactions,
            modified=[],
            removed=[],
            cursor=paging.get("next"),
            has_more=bool(paging.get("next")),
        )

    async def get_transactions(
        self,
        access_token: str,
        start_date: date,
        end_date: date,
        account_ids: list[str] | None = None,
    ) -> list[TransactionInfo]:
        """Get transactions for date range."""
        response = await self._request(
            "GET",
            f"/accounts/{access_token}/transactions?start={start_date.isoformat()}&end={end_date.isoformat()}",
        )

        transactions_data = response.get("data", [])

        return [
            self._map_transaction(tx, access_token)
            for tx in transactions_data
        ]

    async def get_recurring_transactions(
        self,
        access_token: str,
        account_ids: list[str] | None = None,
    ) -> list[RecurringTransactionInfo]:
        """
        Get recurring transactions.

        Note: Mono doesn't natively detect recurring transactions,
        so this returns an empty list. Recurring detection is done
        in our EmailParserService and transaction analysis.
        """
        # Mono doesn't have native recurring detection
        # Return empty list - our app handles recurring detection
        return []

    async def remove_connection(
        self,
        access_token: str,
    ) -> bool:
        """Unlink a Mono account."""
        try:
            await self._request(
                "POST",
                f"/accounts/{access_token}/unlink",
            )
            return True
        except MonoProviderError:
            return False

    def _map_account_type(
        self,
        mono_type: str,
    ) -> Literal["checking", "savings", "credit", "loan", "investment", "other"]:
        """Map Mono account type to our standard types."""
        type_map: dict[str, Literal["checking", "savings", "credit", "loan", "investment", "other"]] = {
            "SAVINGS_ACCOUNT": "savings",
            "CURRENT_ACCOUNT": "checking",
            "CHECKING_ACCOUNT": "checking",
            "CREDIT_ACCOUNT": "credit",
            "LOAN_ACCOUNT": "loan",
            "INVESTMENT_ACCOUNT": "investment",
            "DEPOSIT_ACCOUNT": "savings",
        }
        return type_map.get(mono_type.upper(), "other")

    def _map_transaction(
        self,
        tx: dict,
        account_id: str,
    ) -> TransactionInfo:
        """Map Mono transaction to our schema."""
        # Determine transaction type
        amount = Decimal(str(tx.get("amount", 0))) / 100  # Mono uses kobo
        tx_type: Literal["debit", "credit"] = "debit" if tx.get("type") == "debit" else "credit"

        # Parse date
        date_str = tx.get("date", "")
        try:
            tx_date = datetime.fromisoformat(date_str.replace("Z", "+00:00")).date()
        except (ValueError, AttributeError):
            tx_date = date.today()

        return TransactionInfo(
            transaction_id=tx.get("_id", ""),
            account_id=account_id,
            name=tx.get("narration", "Transaction"),
            merchant_name=self._extract_merchant(tx.get("narration", "")),
            amount=abs(amount),
            currency=tx.get("currency", "NGN"),
            transaction_type=tx_type,
            transaction_date=tx_date,
            posted_date=tx_date,
            category=tx.get("category"),
            category_id=None,
            is_pending=False,
            logo_url=None,
            is_recurring=False,
            recurrence_stream_id=None,
        )

    @staticmethod
    def _extract_merchant(narration: str) -> str | None:
        """Extract merchant name from transaction narration."""
        if not narration:
            return None

        # Common patterns in Nigerian bank narrations
        # "NIP/TRANSFER FROM JOHN DOE" -> "JOHN DOE"
        # "POS/WEB PAYMENT SHOPRITE" -> "SHOPRITE"
        narration = narration.upper()

        # Remove common prefixes
        prefixes = [
            "NIP/TRANSFER FROM ",
            "NIP/TRANSFER TO ",
            "POS/WEB PAYMENT ",
            "ATM WITHDRAWAL ",
            "WEB TRANSFER ",
            "MOBILE TRANSFER ",
            "USSD TRANSFER ",
        ]

        for prefix in prefixes:
            if narration.startswith(prefix):
                return narration[len(prefix):].strip().title()

        return narration.title()[:50] if len(narration) > 3 else None
