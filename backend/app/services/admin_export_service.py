"""Service for exporting admin data to CSV."""

import csv
import logging
import tempfile
from datetime import datetime
from pathlib import Path
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.admin_user import AdminUser, AuditLog
from app.models.subscription import Subscription
from app.models.user import User

logger = logging.getLogger(__name__)

EXPORT_DIR = Path(tempfile.gettempdir()) / "mg_exports"


def _ensure_export_dir() -> None:
    """Create export directory if it doesn't exist."""
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)


async def export_users_csv(
    db: AsyncSession,
    filters: dict[str, str] | None = None,
) -> str:
    """Export users to a CSV file and return the file path."""
    _ensure_export_dir()

    query = select(User).order_by(User.created_at.desc())

    # Apply optional filters
    if filters:
        if "tier" in filters:
            query = query.where(User.subscription_tier == filters["tier"])
        if "is_active" in filters:
            is_active = filters["is_active"].lower() == "true"
            query = query.where(User.is_active == is_active)

    result = await db.execute(query)
    users = result.scalars().all()

    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    filepath = EXPORT_DIR / f"users_export_{timestamp}.csv"

    with open(filepath, "w", newline="", encoding="utf-8") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow([
            "id", "email", "full_name", "tenant_id", "subscription_tier",
            "is_active", "is_verified", "onboarding_completed",
            "last_login_at", "created_at",
        ])
        for user in users:
            writer.writerow([
                str(user.id),
                user.email,
                user.full_name or "",
                str(user.tenant_id),
                user.subscription_tier,
                user.is_active,
                user.is_verified,
                user.onboarding_completed,
                user.last_login_at.isoformat() if user.last_login_at else "",
                user.created_at.isoformat(),
            ])

    logger.info("Exported %d users to %s", len(users), filepath)
    return str(filepath)


async def export_subscriptions_csv(
    db: AsyncSession,
    filters: dict[str, str] | None = None,
) -> str:
    """Export subscriptions to a CSV file and return the file path."""
    _ensure_export_dir()

    query = select(Subscription).where(
        Subscription.deleted_at.is_(None),
    ).order_by(Subscription.created_at.desc())

    if filters:
        if "billing_cycle" in filters:
            query = query.where(
                Subscription.billing_cycle == filters["billing_cycle"],
            )
        if "is_active" in filters:
            is_active = filters["is_active"].lower() == "true"
            query = query.where(Subscription.is_active == is_active)

    result = await db.execute(query)
    subscriptions = result.scalars().all()

    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    filepath = EXPORT_DIR / f"subscriptions_export_{timestamp}.csv"

    with open(filepath, "w", newline="", encoding="utf-8") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow([
            "id", "tenant_id", "user_id", "name", "amount", "currency",
            "billing_cycle", "next_billing_date", "is_active", "is_paused",
            "ai_flag", "source", "created_at",
        ])
        for sub in subscriptions:
            writer.writerow([
                str(sub.id),
                str(sub.tenant_id),
                str(sub.user_id),
                sub.name,
                str(sub.amount),
                sub.currency,
                sub.billing_cycle,
                sub.next_billing_date.isoformat() if sub.next_billing_date else "",
                sub.is_active,
                sub.is_paused,
                sub.ai_flag,
                sub.source,
                sub.created_at.isoformat(),
            ])

    logger.info("Exported %d subscriptions to %s", len(subscriptions), filepath)
    return str(filepath)


async def export_audit_log_csv(
    db: AsyncSession,
    filters: dict[str, str] | None = None,
) -> str:
    """Export audit log entries to a CSV file and return the file path."""
    _ensure_export_dir()

    query = select(AuditLog).order_by(AuditLog.created_at.desc())

    if filters:
        if "action" in filters:
            query = query.where(AuditLog.action.ilike(f"%{filters['action']}%"))
        if "entity_type" in filters:
            query = query.where(AuditLog.entity_type == filters["entity_type"])

    result = await db.execute(query)
    entries = result.scalars().all()

    # Build admin email lookup
    admin_ids = {e.admin_user_id for e in entries if e.admin_user_id}
    admin_map: dict[UUID, str] = {}
    if admin_ids:
        admin_result = await db.execute(
            select(AdminUser).where(AdminUser.id.in_(admin_ids))
        )
        for admin in admin_result.scalars().all():
            admin_map[admin.id] = admin.email

    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    filepath = EXPORT_DIR / f"audit_log_export_{timestamp}.csv"

    with open(filepath, "w", newline="", encoding="utf-8") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow([
            "id", "admin_user_id", "admin_email", "action",
            "entity_type", "entity_id", "details",
            "ip_address", "created_at",
        ])
        for entry in entries:
            admin_email = admin_map.get(entry.admin_user_id, "") if entry.admin_user_id else ""
            writer.writerow([
                str(entry.id),
                str(entry.admin_user_id) if entry.admin_user_id else "",
                admin_email,
                entry.action,
                entry.entity_type,
                str(entry.entity_id) if entry.entity_id else "",
                str(entry.details),
                entry.ip_address,
                entry.created_at.isoformat(),
            ])

    logger.info("Exported %d audit log entries to %s", len(entries), filepath)
    return str(filepath)
