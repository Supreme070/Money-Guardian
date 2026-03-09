"""Audit trail service for admin actions.

All state-changing admin operations should call ``log_action`` to create
an append-only audit record.
"""

import logging
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.admin_user import AdminUser, AuditLog
from app.schemas.admin_auth import AuditLogEntry, AuditLogResponse

logger = logging.getLogger(__name__)


async def log_action(
    db: AsyncSession,
    *,
    admin_user_id: UUID | None,
    action: str,
    entity_type: str,
    entity_id: UUID | None = None,
    details: dict[str, str | int | bool | None] | None = None,
    ip_address: str = "",
    user_agent: str = "",
) -> AuditLog:
    """Create an audit log entry.

    This is append-only — audit entries are never updated or deleted.
    """
    entry = AuditLog(
        id=uuid4(),
        admin_user_id=admin_user_id,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        details=details or {},
        ip_address=ip_address,
        user_agent=user_agent,
    )
    db.add(entry)
    await db.flush()

    logger.info(
        "Audit: admin=%s action=%s entity=%s/%s",
        admin_user_id, action, entity_type, entity_id,
    )
    return entry


async def get_audit_log(
    db: AsyncSession,
    *,
    page: int = 1,
    page_size: int = 50,
    action_filter: str | None = None,
    entity_type_filter: str | None = None,
    admin_user_id_filter: UUID | None = None,
    date_from: datetime | None = None,
    date_to: datetime | None = None,
) -> AuditLogResponse:
    """Query audit log with filters and pagination."""
    query = select(AuditLog).order_by(AuditLog.created_at.desc())
    count_query = select(func.count(AuditLog.id))

    # Apply filters
    if action_filter:
        query = query.where(AuditLog.action.ilike(f"%{action_filter}%"))
        count_query = count_query.where(AuditLog.action.ilike(f"%{action_filter}%"))
    if entity_type_filter:
        query = query.where(AuditLog.entity_type == entity_type_filter)
        count_query = count_query.where(AuditLog.entity_type == entity_type_filter)
    if admin_user_id_filter:
        query = query.where(AuditLog.admin_user_id == admin_user_id_filter)
        count_query = count_query.where(AuditLog.admin_user_id == admin_user_id_filter)
    if date_from:
        query = query.where(AuditLog.created_at >= date_from)
        count_query = count_query.where(AuditLog.created_at >= date_from)
    if date_to:
        query = query.where(AuditLog.created_at <= date_to)
        count_query = count_query.where(AuditLog.created_at <= date_to)

    total_count = (await db.execute(count_query)).scalar() or 0

    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)

    result = await db.execute(query)
    entries = result.scalars().all()

    # Build admin email/name lookup
    admin_ids = {e.admin_user_id for e in entries if e.admin_user_id}
    admin_map: dict[UUID, AdminUser] = {}
    if admin_ids:
        admin_result = await db.execute(
            select(AdminUser).where(AdminUser.id.in_(admin_ids))
        )
        for admin in admin_result.scalars().all():
            admin_map[admin.id] = admin

    response_entries: list[AuditLogEntry] = []
    for entry in entries:
        admin = admin_map.get(entry.admin_user_id) if entry.admin_user_id else None
        response_entries.append(
            AuditLogEntry(
                id=entry.id,
                admin_user_id=entry.admin_user_id,
                admin_email=admin.email if admin else None,
                admin_name=admin.full_name if admin else None,
                action=entry.action,
                entity_type=entry.entity_type,
                entity_id=entry.entity_id,
                details=entry.details,
                ip_address=entry.ip_address,
                created_at=entry.created_at,
            )
        )

    return AuditLogResponse(
        entries=response_entries,
        total_count=total_count,
        page=page,
        page_size=page_size,
    )
