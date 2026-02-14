"""Stitch banking provider implementation for South Africa.

Stitch provides open banking APIs for South Africa, covering:
- FNB (First National Bank)
- Standard Bank
- Absa
- Nedbank
- Capitec
- Discovery Bank
- And more

API Documentation: https://docs.stitch.money/
"""

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
    TransactionSyncResponse,
    TransactionInfo,
    RecurringTransactionInfo,
)


class StitchProviderError(Exception):
    """Exception raised for Stitch API errors."""

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


class StitchProvider(BankingProvider):
    """
    Stitch implementation of BankingProvider.

    Stitch provides open banking in South Africa using OAuth 2.0.
    Uses GraphQL API for data access.
    """

    # Stitch API endpoints
    _AUTH_URL = "https://secure.stitch.money/connect/authorize"
    _TOKEN_URL = "https://secure.stitch.money/connect/token"
    _API_URL = "https://api.stitch.money/graphql"

    # Supported countries (ISO 3166-1 alpha-2)
    _SUPPORTED_COUNTRIES = ["ZA"]

    # Required scopes for banking
    _SCOPES = [
        "openid",
        "accounts",
        "balances",
        "transactions",
        "offline_access",
    ]

    def __init__(self) -> None:
        """Initialize StitchProvider with settings."""
        self._client_id = settings.stitch_client_id
        self._client_secret = settings.stitch_client_secret

        if not self._client_id or not self._client_secret:
            raise ValueError("Stitch credentials not configured")

    @property
    def provider_name(self) -> Literal["stitch"]:
        """Return provider identifier."""
        return "stitch"

    @property
    def supported_countries(self) -> list[str]:
        """Return supported countries."""
        return self._SUPPORTED_COUNTRIES

    async def _graphql_request(
        self,
        access_token: str,
        query: str,
        variables: dict | None = None,
        timeout: float = 30.0,
    ) -> dict:
        """Make a GraphQL request to Stitch API."""
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        }

        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.post(
                self._API_URL,
                headers=headers,
                json={
                    "query": query,
                    "variables": variables or {},
                },
            )

            if response.status_code >= 400:
                raise StitchProviderError(
                    message="Stitch API error",
                    status_code=response.status_code,
                )

            data = response.json()

            if "errors" in data:
                error = data["errors"][0]
                raise StitchProviderError(
                    message=error.get("message", "GraphQL error"),
                    error_code=error.get("extensions", {}).get("code"),
                )

            return data.get("data", {})

    async def create_link_token(
        self,
        user_id: str,
        client_name: str = "Money Guardian",
        redirect_uri: str | None = None,
    ) -> LinkTokenResponse:
        """
        Create a Stitch authorization URL.

        Stitch uses OAuth 2.0, so we return an authorization URL
        that the frontend will redirect the user to.
        """
        if not redirect_uri:
            redirect_uri = settings.stitch_redirect_uri

        # Build authorization URL
        params = {
            "client_id": self._client_id,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "scope": " ".join(self._SCOPES),
            "state": user_id,  # Use user_id as state for tracking
        }

        authorization_url = f"{self._AUTH_URL}?{urlencode(params)}"

        return LinkTokenResponse(
            link_token=authorization_url,
            expiration=datetime.now(timezone.utc).isoformat(),
        )

    async def exchange_public_token(
        self,
        public_token: str,
    ) -> ExchangeTokenResponse:
        """
        Exchange authorization code for access token.

        The public_token here is the authorization code from OAuth callback.
        """
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                self._TOKEN_URL,
                data={
                    "grant_type": "authorization_code",
                    "client_id": self._client_id,
                    "client_secret": self._client_secret,
                    "code": public_token,
                    "redirect_uri": settings.stitch_redirect_uri,
                },
            )

            if response.status_code != 200:
                error_data = response.json() if response.content else {}
                raise StitchProviderError(
                    message=error_data.get("error_description", "Token exchange failed"),
                    error_code=error_data.get("error"),
                    status_code=response.status_code,
                )

            token_data = response.json()
            access_token = token_data["access_token"]

        # Fetch account information using GraphQL
        accounts = await self.get_accounts(access_token)

        # Get user info for institution
        user_query = """
        query {
            user {
                bankAccounts {
                    bankId
                    name
                }
            }
        }
        """

        user_data = await self._graphql_request(access_token, user_query)
        bank_accounts = user_data.get("user", {}).get("bankAccounts", [])
        bank_info = bank_accounts[0] if bank_accounts else {}

        return ExchangeTokenResponse(
            access_token=access_token,
            item_id=token_data.get("id_token", access_token[:32]),
            institution_id=bank_info.get("bankId"),
            institution_name=bank_info.get("name", "South African Bank"),
            institution_logo=None,
            accounts=accounts,
        )

    async def get_accounts(
        self,
        access_token: str,
    ) -> list[AccountInfo]:
        """Get all bank accounts using GraphQL."""
        query = """
        query {
            user {
                bankAccounts {
                    id
                    name
                    accountNumber
                    accountType
                    bankId
                    currency
                    currentBalance
                    availableBalance
                }
            }
        }
        """

        data = await self._graphql_request(access_token, query)
        bank_accounts = data.get("user", {}).get("bankAccounts", [])

        accounts: list[AccountInfo] = []
        for acc in bank_accounts:
            account_type = self._map_account_type(acc.get("accountType", ""))

            accounts.append(
                AccountInfo(
                    account_id=acc.get("id", ""),
                    name=acc.get("name", "Account"),
                    official_name=acc.get("name"),
                    mask=acc.get("accountNumber", "")[-4:] if acc.get("accountNumber") else None,
                    account_type=account_type,
                    account_subtype=acc.get("accountType"),
                    current_balance=Decimal(str(acc.get("currentBalance", 0))),
                    available_balance=Decimal(str(acc.get("availableBalance", 0))),
                    limit=None,
                    currency=acc.get("currency", "ZAR"),
                )
            )

        return accounts

    async def get_balances(
        self,
        access_token: str,
        account_ids: list[str] | None = None,
    ) -> list[BalanceInfo]:
        """Get current balances using GraphQL."""
        query = """
        query {
            user {
                bankAccounts {
                    id
                    currency
                    currentBalance
                    availableBalance
                }
            }
        }
        """

        data = await self._graphql_request(access_token, query)
        bank_accounts = data.get("user", {}).get("bankAccounts", [])

        balances: list[BalanceInfo] = []
        for acc in bank_accounts:
            if account_ids and acc.get("id") not in account_ids:
                continue

            balances.append(
                BalanceInfo(
                    account_id=acc.get("id", ""),
                    current_balance=Decimal(str(acc.get("currentBalance", 0))),
                    available_balance=Decimal(str(acc.get("availableBalance", 0))),
                    limit=None,
                    currency=acc.get("currency", "ZAR"),
                    last_updated=datetime.now(timezone.utc),
                )
            )

        return balances

    async def sync_transactions(
        self,
        access_token: str,
        cursor: str | None = None,
    ) -> TransactionSyncResponse:
        """
        Sync transactions using GraphQL.

        Stitch supports cursor-based pagination.
        """
        query = """
        query GetTransactions($first: Int, $after: String) {
            user {
                bankAccounts {
                    id
                    transactions(first: $first, after: $after) {
                        pageInfo {
                            hasNextPage
                            endCursor
                        }
                        edges {
                            node {
                                id
                                amount {
                                    quantity
                                    currency
                                }
                                reference
                                description
                                date
                                runningBalance {
                                    quantity
                                }
                                debitCreditIndicator
                            }
                        }
                    }
                }
            }
        }
        """

        variables = {
            "first": 100,
            "after": cursor,
        }

        data = await self._graphql_request(access_token, query, variables)
        bank_accounts = data.get("user", {}).get("bankAccounts", [])

        added_transactions: list[TransactionInfo] = []
        next_cursor: str | None = None
        has_more = False

        for acc in bank_accounts:
            account_id = acc.get("id", "")
            transactions = acc.get("transactions", {})
            page_info = transactions.get("pageInfo", {})
            edges = transactions.get("edges", [])

            for edge in edges:
                node = edge.get("node", {})
                tx_info = self._map_transaction(node, account_id)
                added_transactions.append(tx_info)

            # Track pagination
            if page_info.get("hasNextPage"):
                has_more = True
                next_cursor = page_info.get("endCursor")

        return TransactionSyncResponse(
            added=added_transactions,
            modified=[],
            removed=[],
            cursor=next_cursor,
            has_more=has_more,
        )

    async def get_transactions(
        self,
        access_token: str,
        start_date: date,
        end_date: date,
        account_ids: list[str] | None = None,
    ) -> list[TransactionInfo]:
        """Get transactions for date range."""
        query = """
        query GetTransactions($from: Date, $to: Date) {
            user {
                bankAccounts {
                    id
                    transactions(filter: { from: $from, to: $to }) {
                        edges {
                            node {
                                id
                                amount {
                                    quantity
                                    currency
                                }
                                reference
                                description
                                date
                                runningBalance {
                                    quantity
                                }
                                debitCreditIndicator
                            }
                        }
                    }
                }
            }
        }
        """

        variables = {
            "from": start_date.isoformat(),
            "to": end_date.isoformat(),
        }

        data = await self._graphql_request(access_token, query, variables)
        bank_accounts = data.get("user", {}).get("bankAccounts", [])

        transactions: list[TransactionInfo] = []

        for acc in bank_accounts:
            account_id = acc.get("id", "")
            if account_ids and account_id not in account_ids:
                continue

            edges = acc.get("transactions", {}).get("edges", [])
            for edge in edges:
                node = edge.get("node", {})
                tx_info = self._map_transaction(node, account_id)
                transactions.append(tx_info)

        return transactions

    async def get_recurring_transactions(
        self,
        access_token: str,
        account_ids: list[str] | None = None,
    ) -> list[RecurringTransactionInfo]:
        """
        Get recurring transactions.

        Note: Stitch doesn't natively detect recurring transactions,
        so this returns an empty list. Recurring detection is done
        in our app's transaction analysis.
        """
        return []

    async def remove_connection(
        self,
        access_token: str,
    ) -> bool:
        """
        Revoke Stitch access token.

        Stitch doesn't have a revoke endpoint in the same way,
        but we can signal the token should be discarded.
        """
        # Stitch tokens eventually expire
        # We just need to delete locally
        return True

    async def refresh_access_token(
        self,
        access_token: str,
    ) -> str | None:
        """
        Refresh Stitch access token using refresh token.

        Note: This requires the refresh_token, not access_token.
        The caller should pass the refresh_token as the parameter.
        """
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                self._TOKEN_URL,
                data={
                    "grant_type": "refresh_token",
                    "client_id": self._client_id,
                    "client_secret": self._client_secret,
                    "refresh_token": access_token,  # Actually the refresh token
                },
            )

            if response.status_code != 200:
                return None

            token_data = response.json()
            return token_data.get("access_token")

    def _map_account_type(
        self,
        stitch_type: str,
    ) -> Literal["checking", "savings", "credit", "loan", "investment", "other"]:
        """Map Stitch account type to our standard types."""
        type_map: dict[str, Literal["checking", "savings", "credit", "loan", "investment", "other"]] = {
            "current": "checking",
            "cheque": "checking",
            "savings": "savings",
            "credit": "credit",
            "creditcard": "credit",
            "loan": "loan",
            "homeloan": "loan",
            "investment": "investment",
        }
        return type_map.get(stitch_type.lower(), "other")

    def _map_transaction(
        self,
        tx: dict[str, object],
        account_id: str,
    ) -> TransactionInfo:
        """Map Stitch transaction to our schema."""
        amount_data = tx.get("amount", {})
        amount = Decimal(str(amount_data.get("quantity", 0)))
        currency = amount_data.get("currency", "ZAR")

        # Determine transaction type
        indicator = tx.get("debitCreditIndicator", "").upper()
        tx_type: Literal["debit", "credit"] = "debit" if indicator == "DEBIT" else "credit"

        # Parse date
        date_str = tx.get("date", "")
        try:
            tx_date = datetime.fromisoformat(date_str.replace("Z", "+00:00")).date()
        except (ValueError, AttributeError):
            tx_date = date.today()

        # Get description
        description = tx.get("description") or tx.get("reference") or "Transaction"

        return TransactionInfo(
            transaction_id=tx.get("id", ""),
            account_id=account_id,
            name=description,
            merchant_name=self._extract_merchant(description),
            amount=abs(amount),
            currency=currency,
            transaction_type=tx_type,
            transaction_date=tx_date,
            posted_date=tx_date,
            category=None,
            category_id=None,
            is_pending=False,
            logo_url=None,
            is_recurring=False,
            recurrence_stream_id=None,
        )

    @staticmethod
    def _extract_merchant(description: str) -> str | None:
        """Extract merchant name from transaction description."""
        if not description or len(description) < 3:
            return None

        # Remove common South African transaction prefixes
        prefixes = [
            "POS PURCHASE ",
            "DEBIT ORDER ",
            "EFT PAYMENT ",
            "CARD PURCHASE ",
            "INTERNET TRF ",
            "ACB DEBIT ",
        ]

        desc_upper = description.upper()
        for prefix in prefixes:
            if desc_upper.startswith(prefix):
                return description[len(prefix):].strip().title()

        return description.title()[:50]
