"""Background tasks for banking sync operations."""

import asyncio
import logging
from uuid import UUID

from celery import shared_task
from sqlalchemy import select
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.models.bank_connection import BankConnection
from app.services.bank_connection_service import BankConnectionService

logger = logging.getLogger(__name__)


def get_async_session() -> AsyncSession:
    """Create an async database session for Celery tasks."""
    engine = create_async_engine(settings.async_database_url, echo=False)
    async_session = sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )
    return async_session()


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
) -> dict:
    """
    Sync transactions for a single bank connection.

    Args:
        connection_id: UUID of the bank connection
        tenant_id: UUID of the tenant
        user_id: UUID of the user

    Returns:
        Dict with sync results
    """
    return asyncio.get_event_loop().run_until_complete(
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
) -> dict:
    """Async implementation of transaction sync."""
    async with get_async_session() as db:
        try:
            service = BankConnectionService(db)
            new_count = await service.sync_transactions(
                tenant_id=tenant_id,
                user_id=user_id,
                connection_id=connection_id,
            )

            logger.info(
                f"Synced {new_count} transactions for connection {connection_id}"
            )

            return {
                "status": "success",
                "connection_id": str(connection_id),
                "new_transactions": new_count,
            }

        except Exception as e:
            logger.error(
                f"Failed to sync transactions for connection {connection_id}: {e}"
            )
            return {
                "status": "error",
                "connection_id": str(connection_id),
                "error": str(e),
            }


@shared_task(bind=True)
def sync_all_transactions(self) -> dict:
    """
    Sync transactions for all active bank connections.

    Scheduled task that runs periodically to keep transactions up to date.
    """
    return asyncio.get_event_loop().run_until_complete(
        _sync_all_transactions_async()
    )


async def _sync_all_transactions_async() -> dict:
    """Async implementation of sync all transactions."""
    async with get_async_session() as db:
        # Get all active connections
        result = await db.execute(
            select(BankConnection).where(
                BankConnection.status == "connected",
                BankConnection.deleted_at.is_(None),
            )
        )
        connections = result.scalars().all()

        results = {
            "total": len(connections),
            "success": 0,
            "failed": 0,
            "errors": [],
        }

        for conn in connections:
            try:
                service = BankConnectionService(db)
                new_count = await service.sync_transactions(
                    tenant_id=conn.tenant_id,
                    user_id=conn.user_id,
                    connection_id=conn.id,
                )
                results["success"] += 1
                logger.info(
                    f"Synced {new_count} transactions for connection {conn.id}"
                )

            except Exception as e:
                results["failed"] += 1
                results["errors"].append({
                    "connection_id": str(conn.id),
                    "error": str(e),
                })
                logger.error(
                    f"Failed to sync connection {conn.id}: {e}"
                )

        logger.info(
            f"Completed transaction sync: {results['success']}/{results['total']} successful"
        )

        return results


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
) -> dict:
    """
    Refresh balances for a single bank connection.

    Args:
        connection_id: UUID of the bank connection
        tenant_id: UUID of the tenant

    Returns:
        Dict with refresh results
    """
    return asyncio.get_event_loop().run_until_complete(
        _refresh_bank_balances_async(
            UUID(connection_id),
            UUID(tenant_id),
        )
    )


async def _refresh_bank_balances_async(
    connection_id: UUID,
    tenant_id: UUID,
) -> dict:
    """Async implementation of balance refresh."""
    async with get_async_session() as db:
        try:
            service = BankConnectionService(db)
            await service.sync_balances(
                tenant_id=tenant_id,
                connection_id=connection_id,
            )

            logger.info(f"Refreshed balances for connection {connection_id}")

            return {
                "status": "success",
                "connection_id": str(connection_id),
            }

        except Exception as e:
            logger.error(
                f"Failed to refresh balances for connection {connection_id}: {e}"
            )
            return {
                "status": "error",
                "connection_id": str(connection_id),
                "error": str(e),
            }


@shared_task(bind=True)
def refresh_all_balances(self) -> dict:
    """
    Refresh balances for all active bank connections.

    Scheduled task that runs periodically to keep balances current.
    """
    return asyncio.get_event_loop().run_until_complete(
        _refresh_all_balances_async()
    )


async def _refresh_all_balances_async() -> dict:
    """Async implementation of refresh all balances."""
    async with get_async_session() as db:
        # Get all active connections
        result = await db.execute(
            select(BankConnection).where(
                BankConnection.status == "connected",
                BankConnection.deleted_at.is_(None),
            )
        )
        connections = result.scalars().all()

        results = {
            "total": len(connections),
            "success": 0,
            "failed": 0,
        }

        for conn in connections:
            try:
                service = BankConnectionService(db)
                await service.sync_balances(
                    tenant_id=conn.tenant_id,
                    connection_id=conn.id,
                )
                results["success"] += 1

            except Exception as e:
                results["failed"] += 1
                logger.error(f"Failed to refresh balances for {conn.id}: {e}")

        logger.info(
            f"Completed balance refresh: {results['success']}/{results['total']} successful"
        )

        return results
