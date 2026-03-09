"""Unified admin search service.

Searches across users, tenants, subscriptions, and audit logs with
ILIKE matching. Returns a maximum of 20 results (5 per entity type).
"""

import logging
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.admin_user import AuditLog
from app.models.subscription import Subscription
from app.models.tenant import Tenant
from app.models.user import User
from app.schemas.admin_search import SearchResult

logger = logging.getLogger(__name__)

_MAX_PER_TYPE = 5
_VALID_TYPES = {"user", "tenant", "subscription", "audit_log"}


async def search(
    db: AsyncSession,
    *,
    query: str,
    entity_types: list[str] | None = None,
) -> list[SearchResult]:
    """Search across multiple entity types.

    Returns up to 20 results total (5 per entity type).
    """
    types_to_search = _VALID_TYPES
    if entity_types:
        types_to_search = _VALID_TYPES & set(entity_types)

    pattern = f"%{query}%"
    results: list[SearchResult] = []

    if "user" in types_to_search:
        results.extend(await _search_users(db, pattern))

    if "tenant" in types_to_search:
        results.extend(await _search_tenants(db, pattern))

    if "subscription" in types_to_search:
        results.extend(await _search_subscriptions(db, pattern))

    if "audit_log" in types_to_search:
        results.extend(await _search_audit_logs(db, pattern))

    return results


async def _search_users(
    db: AsyncSession,
    pattern: str,
) -> list[SearchResult]:
    """Search users by email or full_name."""
    results: list[SearchResult] = []

    # Search by email
    email_query = (
        select(User)
        .where(User.email.ilike(pattern))
        .limit(_MAX_PER_TYPE)
    )
    email_result = await db.execute(email_query)
    email_users = email_result.scalars().all()

    seen_ids: set[UUID] = set()
    for user in email_users:
        seen_ids.add(user.id)
        results.append(SearchResult(
            entity_type="user",
            entity_id=str(user.id),
            title=user.email,
            subtitle=user.full_name or "No name",
            match_field="email",
        ))

    # Search by full_name (fill remaining slots)
    remaining = _MAX_PER_TYPE - len(results)
    if remaining > 0:
        name_query = (
            select(User)
            .where(User.full_name.ilike(pattern))
            .limit(remaining + len(seen_ids))  # over-fetch to account for dupes
        )
        name_result = await db.execute(name_query)
        for user in name_result.scalars().all():
            if user.id not in seen_ids and len(results) < _MAX_PER_TYPE:
                results.append(SearchResult(
                    entity_type="user",
                    entity_id=str(user.id),
                    title=user.full_name or user.email,
                    subtitle=user.email,
                    match_field="full_name",
                ))

    return results


async def _search_tenants(
    db: AsyncSession,
    pattern: str,
) -> list[SearchResult]:
    """Search tenants by name."""
    query = (
        select(Tenant)
        .where(Tenant.name.ilike(pattern))
        .limit(_MAX_PER_TYPE)
    )
    result = await db.execute(query)
    tenants = result.scalars().all()

    return [
        SearchResult(
            entity_type="tenant",
            entity_id=str(tenant.id),
            title=tenant.name,
            subtitle=f"Tier: {tenant.tier} | Status: {tenant.status}",
            match_field="name",
        )
        for tenant in tenants
    ]


async def _search_subscriptions(
    db: AsyncSession,
    pattern: str,
) -> list[SearchResult]:
    """Search subscriptions by name."""
    query = (
        select(Subscription)
        .where(
            Subscription.name.ilike(pattern),
            Subscription.deleted_at.is_(None),
        )
        .limit(_MAX_PER_TYPE)
    )
    result = await db.execute(query)
    subscriptions = result.scalars().all()

    return [
        SearchResult(
            entity_type="subscription",
            entity_id=str(sub.id),
            title=sub.name,
            subtitle=f"{sub.amount} {sub.currency}/{sub.billing_cycle}",
            match_field="name",
        )
        for sub in subscriptions
    ]


async def _search_audit_logs(
    db: AsyncSession,
    pattern: str,
) -> list[SearchResult]:
    """Search audit logs by action or entity_type."""
    results: list[SearchResult] = []

    # Search by action
    action_query = (
        select(AuditLog)
        .where(AuditLog.action.ilike(pattern))
        .order_by(AuditLog.created_at.desc())
        .limit(_MAX_PER_TYPE)
    )
    action_result = await db.execute(action_query)
    action_logs = action_result.scalars().all()

    seen_ids: set[str] = set()
    for log in action_logs:
        log_id = str(log.id)
        seen_ids.add(log_id)
        results.append(SearchResult(
            entity_type="audit_log",
            entity_id=log_id,
            title=log.action,
            subtitle=f"{log.entity_type} | {log.created_at.isoformat()}",
            match_field="action",
        ))

    # Search by entity_type (fill remaining slots)
    remaining = _MAX_PER_TYPE - len(results)
    if remaining > 0:
        entity_query = (
            select(AuditLog)
            .where(AuditLog.entity_type.ilike(pattern))
            .order_by(AuditLog.created_at.desc())
            .limit(remaining + len(seen_ids))
        )
        entity_result = await db.execute(entity_query)
        for log in entity_result.scalars().all():
            log_id = str(log.id)
            if log_id not in seen_ids and len(results) < _MAX_PER_TYPE:
                results.append(SearchResult(
                    entity_type="audit_log",
                    entity_id=log_id,
                    title=log.action,
                    subtitle=f"{log.entity_type} | {log.created_at.isoformat()}",
                    match_field="entity_type",
                ))

    return results
