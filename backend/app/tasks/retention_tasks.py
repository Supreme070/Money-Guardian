"""Data retention enforcement tasks.

GDPR compliance: Privacy policy states personal data is permanently removed
within 30 days of account deletion. This task enforces that guarantee by
hard-deleting scrubbed user records and their associated data.
"""

import logging
from datetime import datetime, timedelta, timezone

from app.core.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="app.tasks.retention_tasks.purge_deleted_accounts")
def purge_deleted_accounts() -> dict[str, int]:
    """
    Hard-delete user records that were soft-deleted more than 30 days ago.

    The account deletion endpoint (DELETE /users/me) scrubs PII immediately
    and marks the tenant as "deleted". This task runs weekly to permanently
    remove the scrubbed records from the database once the 30-day retention
    window has passed.

    Cascade deletes remove: subscriptions, alerts, bank_connections,
    email_connections, transactions, scanned_emails.
    """
    import asyncio

    from sqlalchemy import select, delete

    from app.db.session import async_session_maker
    from app.models.user import User
    from app.models.tenant import Tenant

    async def _purge() -> dict[str, int]:
        cutoff = datetime.now(timezone.utc) - timedelta(days=30)
        purged_users = 0
        purged_tenants = 0

        async with async_session_maker() as session:
            # Find users that were deactivated (deleted) more than 30 days ago.
            # Deleted users have email pattern: deleted_<uuid>@deleted.moneyguardian.co
            result = await session.execute(
                select(User).where(
                    User.is_active.is_(False),
                    User.email.like("deleted_%@deleted.moneyguardian.co"),
                    User.updated_at < cutoff,
                )
            )
            users_to_purge = result.scalars().all()

            if not users_to_purge:
                logger.info("No accounts past 30-day retention window")
                return {"purged_users": 0, "purged_tenants": 0}

            tenant_ids_to_check: set[str] = set()

            for user in users_to_purge:
                tenant_ids_to_check.add(str(user.tenant_id))
                await session.delete(user)
                purged_users += 1
                logger.info(
                    "Hard-deleted user %s (tenant %s)",
                    user.id,
                    user.tenant_id,
                )

            # Purge tenants that are marked deleted and have no remaining users
            for tid in tenant_ids_to_check:
                remaining = await session.execute(
                    select(User.id).where(User.tenant_id == tid).limit(1)
                )
                if remaining.scalar_one_or_none() is None:
                    # No users left in this tenant — safe to delete
                    tenant_result = await session.execute(
                        select(Tenant).where(
                            Tenant.id == tid,
                            Tenant.status == "deleted",
                        )
                    )
                    tenant = tenant_result.scalar_one_or_none()
                    if tenant:
                        await session.delete(tenant)
                        purged_tenants += 1
                        logger.info("Hard-deleted tenant %s", tid)

            await session.commit()

        logger.info(
            "Retention purge complete: %d users, %d tenants removed",
            purged_users,
            purged_tenants,
        )
        return {
            "purged_users": purged_users,
            "purged_tenants": purged_tenants,
        }

    return asyncio.get_event_loop().run_until_complete(_purge())
