"""Bulk operation model for tracking admin batch jobs."""

from datetime import datetime
from typing import TYPE_CHECKING
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.admin_user import AdminUser


class BulkOperation(Base, TimestampMixin):
    """Tracks bulk admin operations (user status changes, tier overrides, etc.).

    Status lifecycle: pending -> running -> completed / failed / cancelled
    """

    __tablename__ = "bulk_operations"

    admin_user_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("admin_users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    operation_type: Mapped[str] = mapped_column(
        String(50), nullable=False,
    )  # "user_status", "tier_override", "notification", "export"

    target_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0,
    )
    processed_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0,
    )
    failed_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0,
    )

    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="pending",
    )  # "pending", "running", "completed", "failed", "cancelled"

    parameters: Mapped[dict[str, str | int | bool | list[str] | None] | None] = mapped_column(
        JSONB, nullable=True,
    )

    result_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)

    started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
    )
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
    )

    # Relationships
    admin_user: Mapped["AdminUser | None"] = relationship(
        "AdminUser",
    )
