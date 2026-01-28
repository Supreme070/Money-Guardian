"""Bank connection service for managing Plaid/Mono/Stitch connections."""

from datetime import datetime, timezone
from decimal import Decimal
from typing import Literal
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import encrypt_sensitive_data, decrypt_sensitive_data
from app.models.bank_connection import BankConnection
from app.models.bank_account import BankAccount
from app.models.transaction import Transaction
from app.services.banking.factory import get_banking_provider
from app.services.banking.schemas import TransactionInfo


class BankConnectionNotFoundError(Exception):
    """Raised when bank connection is not found."""

    pass


class BankConnectionService:
    """
    Service for managing bank connections.

    CRITICAL: All methods require tenant_id for multi-tenant isolation.
    PRO FEATURE: Bank connections require Pro subscription (enforced at endpoint level).
    """

    def __init__(self, db: AsyncSession) -> None:
        """Initialize with database session."""
        self.db = db

    async def create_link_token(
        self,
        tenant_id: UUID,
        user_id: UUID,
        provider: Literal["plaid", "mono", "stitch"] = "plaid",
    ) -> dict[str, str]:
        """
        Create a link token for initiating bank connection.

        Args:
            tenant_id: Tenant UUID
            user_id: User UUID
            provider: Banking provider to use

        Returns:
            Dict with link_token and expiration
        """
        banking = get_banking_provider(provider)
        result = await banking.create_link_token(str(user_id))
        return {
            "link_token": result.link_token,
            "expiration": result.expiration,
            "provider": provider,
        }

    async def exchange_and_save(
        self,
        tenant_id: UUID,
        user_id: UUID,
        public_token: str,
        provider: Literal["plaid", "mono", "stitch"] = "plaid",
    ) -> BankConnection:
        """
        Exchange public token and save connection + accounts.

        Args:
            tenant_id: Tenant UUID
            user_id: User UUID
            public_token: Token from successful Link completion
            provider: Banking provider

        Returns:
            Created BankConnection with accounts
        """
        banking = get_banking_provider(provider)
        result = await banking.exchange_public_token(public_token)

        now = datetime.now(timezone.utc)

        # Create connection with encrypted access token
        connection = BankConnection(
            tenant_id=tenant_id,
            user_id=user_id,
            provider=provider,
            access_token=encrypt_sensitive_data(result.access_token),
            item_id=result.item_id,
            institution_id=result.institution_id,
            institution_name=result.institution_name,
            institution_logo=result.institution_logo,
            status="connected",
            last_sync_at=now,
            last_successful_sync_at=now,
        )
        self.db.add(connection)
        await self.db.flush()  # Get connection.id

        # Create accounts
        for acc in result.accounts:
            account = BankAccount(
                tenant_id=tenant_id,
                user_id=user_id,
                connection_id=connection.id,
                provider_account_id=acc.account_id,
                name=acc.name,
                official_name=acc.official_name,
                mask=acc.mask,
                account_type=acc.account_type,
                account_subtype=acc.account_subtype,
                current_balance=acc.current_balance,
                available_balance=acc.available_balance,
                limit=acc.limit,
                currency=acc.currency,
                balance_updated_at=now,
            )
            self.db.add(account)

        await self.db.commit()
        await self.db.refresh(connection)
        return connection

    async def get_connection(
        self,
        tenant_id: UUID,
        connection_id: UUID,
    ) -> BankConnection:
        """
        Get a bank connection by ID.

        CRITICAL: Always filters by tenant_id.

        Args:
            tenant_id: Tenant UUID
            connection_id: Connection UUID

        Returns:
            BankConnection

        Raises:
            BankConnectionNotFoundError: If not found
        """
        result = await self.db.execute(
            select(BankConnection).where(
                BankConnection.id == connection_id,
                BankConnection.tenant_id == tenant_id,
                BankConnection.deleted_at.is_(None),
            )
        )
        connection = result.scalar_one_or_none()

        if connection is None:
            raise BankConnectionNotFoundError(
                f"Bank connection {connection_id} not found"
            )

        return connection

    async def list_connections(
        self,
        tenant_id: UUID,
        user_id: UUID,
    ) -> list[BankConnection]:
        """
        List all active bank connections for a user.

        CRITICAL: Always filters by tenant_id.

        Args:
            tenant_id: Tenant UUID
            user_id: User UUID

        Returns:
            List of BankConnection objects
        """
        result = await self.db.execute(
            select(BankConnection).where(
                BankConnection.tenant_id == tenant_id,
                BankConnection.user_id == user_id,
                BankConnection.deleted_at.is_(None),
            ).order_by(BankConnection.created_at.desc())
        )
        return list(result.scalars().all())

    async def get_total_balance(
        self,
        tenant_id: UUID,
        user_id: UUID,
    ) -> Decimal:
        """
        Get total available balance from all connected accounts.

        Only includes accounts marked as include_in_pulse.
        Credit card balances are excluded from total.

        Args:
            tenant_id: Tenant UUID
            user_id: User UUID

        Returns:
            Total available balance as Decimal
        """
        result = await self.db.execute(
            select(BankAccount).where(
                BankAccount.tenant_id == tenant_id,
                BankAccount.user_id == user_id,
                BankAccount.is_active == True,
                BankAccount.include_in_pulse == True,
            )
        )
        accounts = list(result.scalars().all())

        total = Decimal("0")
        for acc in accounts:
            # Only count checking and savings accounts
            if acc.account_type in ("checking", "savings"):
                balance = acc.available_balance or acc.current_balance or Decimal("0")
                total += balance

        return total

    async def sync_balances(
        self,
        tenant_id: UUID,
        connection_id: UUID,
    ) -> list[BankAccount]:
        """
        Sync account balances for a connection.

        Args:
            tenant_id: Tenant UUID
            connection_id: Connection UUID

        Returns:
            Updated list of BankAccount objects
        """
        connection = await self.get_connection(tenant_id, connection_id)
        banking = get_banking_provider(connection.provider)  # type: ignore[arg-type]
        access_token = decrypt_sensitive_data(connection.access_token)

        # Get updated balances
        balances = await banking.get_balances(access_token)
        now = datetime.now(timezone.utc)

        # Update accounts
        result = await self.db.execute(
            select(BankAccount).where(
                BankAccount.connection_id == connection_id,
                BankAccount.is_active == True,
            )
        )
        accounts = list(result.scalars().all())

        balance_map = {b.account_id: b for b in balances}

        for account in accounts:
            if account.provider_account_id in balance_map:
                balance = balance_map[account.provider_account_id]
                account.current_balance = balance.current_balance
                account.available_balance = balance.available_balance
                account.limit = balance.limit
                account.balance_updated_at = now
                self.db.add(account)

        await self.db.commit()
        return accounts

    async def sync_transactions(
        self,
        tenant_id: UUID,
        user_id: UUID,
        connection_id: UUID,
    ) -> int:
        """
        Sync transactions for a connection using incremental sync.

        Args:
            tenant_id: Tenant UUID
            user_id: User UUID
            connection_id: Connection UUID

        Returns:
            Count of new transactions added
        """
        connection = await self.get_connection(tenant_id, connection_id)
        banking = get_banking_provider(connection.provider)  # type: ignore[arg-type]
        access_token = decrypt_sensitive_data(connection.access_token)

        # Get accounts for mapping
        accounts_result = await self.db.execute(
            select(BankAccount).where(
                BankAccount.connection_id == connection_id,
            )
        )
        accounts = list(accounts_result.scalars().all())
        account_map = {acc.provider_account_id: acc for acc in accounts}

        # Sync transactions
        sync_result = await banking.sync_transactions(
            access_token,
            cursor=connection.cursor,
        )

        new_count = 0
        now = datetime.now(timezone.utc)

        # Process added transactions
        for tx in sync_result.added:
            # Skip if we don't have this account
            if tx.account_id not in account_map:
                continue

            account = account_map[tx.account_id]

            # Check if transaction already exists
            existing = await self.db.execute(
                select(Transaction).where(
                    Transaction.provider_transaction_id == tx.transaction_id,
                )
            )
            if existing.scalar_one_or_none():
                continue

            transaction = self._create_transaction_from_info(
                tenant_id=tenant_id,
                user_id=user_id,
                account=account,
                tx=tx,
            )
            self.db.add(transaction)
            new_count += 1

        # Update connection cursor
        connection.cursor = sync_result.cursor
        connection.last_sync_at = now
        connection.last_successful_sync_at = now
        self.db.add(connection)

        await self.db.commit()

        # Continue syncing if there's more
        if sync_result.has_more:
            additional = await self.sync_transactions(tenant_id, user_id, connection_id)
            new_count += additional

        return new_count

    async def disconnect(
        self,
        tenant_id: UUID,
        connection_id: UUID,
    ) -> None:
        """
        Disconnect (soft delete) a bank connection.

        Also removes the connection from the provider.

        Args:
            tenant_id: Tenant UUID
            connection_id: Connection UUID
        """
        connection = await self.get_connection(tenant_id, connection_id)
        banking = get_banking_provider(connection.provider)  # type: ignore[arg-type]
        access_token = decrypt_sensitive_data(connection.access_token)

        # Try to remove from provider (non-fatal if fails)
        try:
            await banking.remove_connection(access_token)
        except Exception:
            pass  # Log but don't fail

        # Soft delete
        now = datetime.now(timezone.utc)
        connection.deleted_at = now
        connection.status = "disconnected"
        self.db.add(connection)
        await self.db.commit()

    async def get_recurring_subscriptions(
        self,
        tenant_id: UUID,
        user_id: UUID,
        connection_id: UUID,
    ) -> list:
        """
        Get detected recurring transactions from provider.

        Useful for automatic subscription detection.

        Args:
            tenant_id: Tenant UUID
            user_id: User UUID
            connection_id: Connection UUID

        Returns:
            List of RecurringTransactionInfo objects
        """
        connection = await self.get_connection(tenant_id, connection_id)
        banking = get_banking_provider(connection.provider)  # type: ignore[arg-type]
        access_token = decrypt_sensitive_data(connection.access_token)

        return await banking.get_recurring_transactions(access_token)

    def _create_transaction_from_info(
        self,
        tenant_id: UUID,
        user_id: UUID,
        account: BankAccount,
        tx: TransactionInfo,
    ) -> Transaction:
        """Create Transaction model from TransactionInfo."""
        return Transaction(
            tenant_id=tenant_id,
            user_id=user_id,
            account_id=account.id,
            provider_transaction_id=tx.transaction_id,
            name=tx.name,
            merchant_name=tx.merchant_name,
            amount=tx.amount,
            currency=tx.currency,
            transaction_type=tx.transaction_type,
            transaction_date=tx.transaction_date,
            posted_date=tx.posted_date,
            category=tx.category,
            category_id=tx.category_id,
            is_recurring=tx.is_recurring,
            is_subscription=tx.is_recurring,  # Initial guess, refined later
            recurrence_stream_id=tx.recurrence_stream_id,
            is_pending=tx.is_pending,
            logo_url=tx.logo_url,
        )
