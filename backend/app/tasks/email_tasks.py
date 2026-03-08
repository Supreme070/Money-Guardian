"""Background tasks for email scanning operations."""

import asyncio
import logging
from uuid import UUID

from celery import shared_task
from sqlalchemy import select
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.core.redis_dedup import is_duplicate
from app.models.email_connection import EmailConnection
from app.services.email_connection_service import EmailConnectionService

_SCAN_DEDUP_PREFIX = "mg:task_dedup:scan_email:"
_SCAN_DEDUP_TTL = 600  # 10 minutes

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
def scan_email_connection(
    self,
    connection_id: str,
    tenant_id: str,
    user_id: str,
    max_emails: int = 100,
) -> dict:
    """
    Scan emails for subscriptions from a single email connection.

    Args:
        connection_id: UUID of the email connection
        tenant_id: UUID of the tenant
        user_id: UUID of the user
        max_emails: Maximum emails to scan in this batch

    Returns:
        Dict with scan results
    """
    return asyncio.get_event_loop().run_until_complete(
        _scan_email_connection_async(
            UUID(connection_id),
            UUID(tenant_id),
            UUID(user_id),
            max_emails,
        )
    )


async def _scan_email_connection_async(
    connection_id: UUID,
    tenant_id: UUID,
    user_id: UUID,
    max_emails: int,
) -> dict:
    """Async implementation of email scan."""
    # Dedup: skip if same connection was scanned in the last 10 minutes
    if await is_duplicate(
        str(connection_id), prefix=_SCAN_DEDUP_PREFIX, ttl=_SCAN_DEDUP_TTL
    ):
        logger.info("Skipping duplicate email scan for connection %s", connection_id)
        return {"status": "skipped", "reason": "duplicate", "connection_id": str(connection_id)}

    async with get_async_session() as db:
        try:
            service = EmailConnectionService(db)

            # Get the connection
            connection = await service.get_connection(
                tenant_id=tenant_id,
                user_id=user_id,
                connection_id=connection_id,
            )

            if not connection:
                return {
                    "status": "error",
                    "connection_id": str(connection_id),
                    "error": "Connection not found",
                }

            # Scan emails
            scanned_emails = await service.scan_emails(
                connection=connection,
                max_emails=max_emails,
            )

            subscriptions_found = sum(
                1 for e in scanned_emails if e.confidence_score >= 0.5
            )

            logger.info(
                f"Scanned {len(scanned_emails)} emails from connection {connection_id}, "
                f"found {subscriptions_found} potential subscriptions"
            )

            return {
                "status": "success",
                "connection_id": str(connection_id),
                "emails_scanned": len(scanned_emails),
                "subscriptions_found": subscriptions_found,
            }

        except Exception as e:
            logger.error(
                f"Failed to scan emails for connection {connection_id}: {e}"
            )
            return {
                "status": "error",
                "connection_id": str(connection_id),
                "error": str(e),
            }


@shared_task(bind=True)
def scan_all_email_connections(self) -> dict:
    """
    Scan emails for all active email connections.

    Scheduled task that runs daily to detect new subscriptions.
    """
    return asyncio.get_event_loop().run_until_complete(
        _scan_all_email_connections_async()
    )


async def _scan_all_email_connections_async() -> dict:
    """Async implementation of scan all emails."""
    async with get_async_session() as db:
        # Get all active connections
        result = await db.execute(
            select(EmailConnection).where(
                EmailConnection.status == "connected",
                EmailConnection.deleted_at.is_(None),
            )
        )
        connections = result.scalars().all()

        results = {
            "total": len(connections),
            "success": 0,
            "failed": 0,
            "total_emails": 0,
            "total_subscriptions": 0,
            "errors": [],
        }

        for conn in connections:
            try:
                service = EmailConnectionService(db)

                # Scan emails
                scanned_emails = await service.scan_emails(
                    connection=conn,
                    max_emails=100,
                )

                subscriptions_found = sum(
                    1 for e in scanned_emails if e.confidence_score >= 0.5
                )

                results["success"] += 1
                results["total_emails"] += len(scanned_emails)
                results["total_subscriptions"] += subscriptions_found

                logger.info(
                    f"Scanned {len(scanned_emails)} emails from {conn.email_address}"
                )

            except Exception as e:
                results["failed"] += 1
                results["errors"].append({
                    "connection_id": str(conn.id),
                    "email": conn.email_address,
                    "error": str(e),
                })
                logger.error(f"Failed to scan connection {conn.id}: {e}")

        logger.info(
            f"Completed email scan: {results['success']}/{results['total']} successful, "
            f"{results['total_subscriptions']} subscriptions found"
        )

        return results


@shared_task(
    bind=True,
    autoretry_for=(Exception,),
    retry_backoff=True,
    retry_kwargs={"max_retries": 3},
)
def refresh_email_token(
    self,
    connection_id: str,
    tenant_id: str,
    user_id: str,
) -> dict:
    """
    Refresh OAuth token for an email connection.

    Args:
        connection_id: UUID of the email connection
        tenant_id: UUID of the tenant
        user_id: UUID of the user

    Returns:
        Dict with refresh result
    """
    return asyncio.get_event_loop().run_until_complete(
        _refresh_email_token_async(
            UUID(connection_id),
            UUID(tenant_id),
            UUID(user_id),
        )
    )


async def _refresh_email_token_async(
    connection_id: UUID,
    tenant_id: UUID,
    user_id: UUID,
) -> dict:
    """Async implementation of token refresh."""
    async with get_async_session() as db:
        try:
            service = EmailConnectionService(db)

            # Get the connection
            connection = await service.get_connection(
                tenant_id=tenant_id,
                user_id=user_id,
                connection_id=connection_id,
            )

            if not connection:
                return {
                    "status": "error",
                    "connection_id": str(connection_id),
                    "error": "Connection not found",
                }

            # Refresh token
            await service.refresh_token_if_needed(connection)

            logger.info(f"Refreshed token for connection {connection_id}")

            return {
                "status": "success",
                "connection_id": str(connection_id),
            }

        except Exception as e:
            logger.error(
                f"Failed to refresh token for connection {connection_id}: {e}"
            )
            return {
                "status": "error",
                "connection_id": str(connection_id),
                "error": str(e),
            }
