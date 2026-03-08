"""Background tasks for banking sync operations.

Celery tasks that handle transaction syncing and balance refreshing
for all connected bank accounts. These run on a schedule via Celery Beat
and can also be triggered on-demand (e.g., from Plaid webhooks).
"""

import asyncio
import logging
from uuid import UUID

from celery import shared_task
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.core.redis_dedup import is_duplicate
from app.models.bank_connection import BankConnection
from app.services.bank_connection_service import BankConnectionService

_SYNC_DEDUP_PREFIX = "mg:task_dedup:sync_txns:"
_SYNC_DEDUP_TTL = 300  # 5 minutes

logger = logging.getLogger(__name__)


def _get_async_session() -> AsyncSession:
    """Create an async session for Celery background tasks."""
    engine = create_async_engine(
        str(settings.database_url),
        pool_pre_ping=True,
        pool_size=5,
        max_overflow=0,
    )
    session_factory = sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    return session_factory()


@shared_task(
    bind=True,
    autoretry_for=(Exception,),
    retry_backoff=True,
    retry_kwargs={"max_retries": 3},
)
def sync_bank_transactions(
    self,
    connection_id: str,
    tenant_id: str,
    user_id: str,
) -> dict[str, str | int]:
    """
    Sync transactions for a single bank connection.

    Args:
        connection_id: UUID of the bank connection
        tenant_id: UUID of the tenant
        user_id: UUID of the user

    Returns:
        Dict with sync results
    """
    return asyncio.run(
        _sync_bank_transactions_async(
            UUID(connection_id),
            UUID(tenant_id),
            UUID(user_id),
        )
    )


async def _sync_bank_transactions_async(
    connection_id: UUID,
    tenant_id: UUID,
    user_id: UUID,
) -> dict[str, str | int]:
    """Async implementation of transaction sync."""
    # Dedup: skip if same connection was synced in the last 5 minutes
    # (protects against duplicate webhook triggers from Plaid)
    if await is_duplicate(
        str(connection_id), prefix=_SYNC_DEDUP_PREFIX, ttl=_SYNC_DEDUP_TTL
    ):
        logger.info("Skipping duplicate sync for connection %s", connection_id)
        return {"status": "skipped", "reason": "duplicate", "connection_id": str(connection_id)}

    db = _get_async_session()
    try:
        service = BankConnectionService(db)
        new_count = await service.sync_transactions(
            tenant_id=tenant_id,
            user_id=user_id,
            connection_id=connection_id,
        )

        logger.info(
            "Synced %d transactions for connection %s", new_count, connection_id
        )

        return {
            "status": "success",
            "connection_id": str(connection_id),
            "new_transactions": new_count,
        }

    except Exception as e:
        logger.error(
            "Failed to sync transactions for connection %s: %s", connection_id, e
        )
        return {
            "status": "error",
            "connection_id": str(connection_id),
            "error": str(e),
        }
    finally:
        await db.close()


@shared_task(bind=True)
def sync_all_transactions(self) -> dict[str, int | list[dict[str, str]]]:
    """
    Sync transactions for all active bank connections.

    Scheduled task that runs periodically to keep transactions up to date.
    """
    return asyncio.run(_sync_all_transactions_async())


async def _sync_all_transactions_async() -> dict[str, int | list[dict[str, str]]]:
    """Async implementation of sync all transactions."""
    db = _get_async_session()
    try:
        result = await db.execute(
            select(BankConnection).where(
                BankConnection.status == "connected",
                BankConnection.deleted_at.is_(None),
            )
        )
        connections = list(result.scalars().all())

        total = len(connections)
        success_count = 0
        failed_count = 0
        errors: list[dict[str, str]] = []

        for conn in connections:
            try:
                service = BankConnectionService(db)
                new_count = await service.sync_transactions(
                    tenant_id=conn.tenant_id,
                    user_id=conn.user_id,
                    connection_id=conn.id,
                )
                success_count += 1
                logger.info(
                    "Synced %d transactions for connection %s", new_count, conn.id
                )

            except Exception as e:
                failed_count += 1
                errors.append({
                    "connection_id": str(conn.id),
                    "error": str(e),
                })
                logger.error("Failed to sync connection %s: %s", conn.id, e)

        logger.info(
            "Completed transaction sync: %d/%d successful", success_count, total
        )

        return {
            "total": total,
            "success": success_count,
            "failed": failed_count,
            "errors": errors,
        }
    finally:
        await db.close()


@shared_task(
    bind=True,
    autoretry_for=(Exception,),
    retry_backoff=True,
    retry_kwargs={"max_retries": 3},
)
def refresh_bank_balances(
    self,
    connection_id: str,
    tenant_id: str,
) -> dict[str, str]:
    """
    Refresh balances for a single bank connection.

    Args:
        connection_id: UUID of the bank connection
        tenant_id: UUID of the tenant

    Returns:
        Dict with refresh results
    """
    return asyncio.run(
        _refresh_bank_balances_async(
            UUID(connection_id),
            UUID(tenant_id),
        )
    )


async def _refresh_bank_balances_async(
    connection_id: UUID,
    tenant_id: UUID,
) -> dict[str, str]:
    """Async implementation of balance refresh."""
    db = _get_async_session()
    try:
        service = BankConnectionService(db)
        await service.sync_balances(
            tenant_id=tenant_id,
            connection_id=connection_id,
        )

        logger.info("Refreshed balances for connection %s", connection_id)

        return {
            "status": "success",
            "connection_id": str(connection_id),
        }

    except Exception as e:
        logger.error(
            "Failed to refresh balances for connection %s: %s", connection_id, e
        )
        return {
            "status": "error",
            "connection_id": str(connection_id),
            "error": str(e),
        }
    finally:
        await db.close()


@shared_task(bind=True)
def refresh_all_balances(self) -> dict[str, int]:
    """
    Refresh balances for all active bank connections.

    Scheduled task that runs periodically to keep balances current.
    """
    return asyncio.run(_refresh_all_balances_async())


async def _refresh_all_balances_async() -> dict[str, int]:
    """Async implementation of refresh all balances."""
    db = _get_async_session()
    try:
        result = await db.execute(
            select(BankConnection).where(
                BankConnection.status == "connected",
                BankConnection.deleted_at.is_(None),
            )
        )
        connections = list(result.scalars().all())

        total = len(connections)
        success_count = 0
        failed_count = 0

        for conn in connections:
            try:
                service = BankConnectionService(db)
                await service.sync_balances(
                    tenant_id=conn.tenant_id,
                    connection_id=conn.id,
                )
                success_count += 1

            except Exception as e:
                failed_count += 1
                logger.error("Failed to refresh balances for %s: %s", conn.id, e)

        logger.info(
            "Completed balance refresh: %d/%d successful", success_count, total
        )

        return {
            "total": total,
            "success": success_count,
            "failed": failed_count,
        }
    finally:
        await db.close()
