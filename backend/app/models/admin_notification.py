"""Admin notification model for bulk notifications sent via the admin portal."""

from datetime import datetime
from typing import TYPE_CHECKING
from uuid import UUID

from sqlalchemy import ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.admin_user import AdminUser


class AdminNotification(Base, TimestampMixin):
    """Admin-sent notification record.

    Tracks bulk notifications dispatched to users, tiers, or all users.
    """

    __tablename__ = "admin_notifications"

    admin_user_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("admin_users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    notification_type: Mapped[str] = mapped_column(
        String(10), nullable=False,
    )  # push, email, both

    target_type: Mapped[str] = mapped_column(
        String(10), nullable=False,
    )  # user, tier, all

    target_ids: Mapped[list[str]] = mapped_column(
        JSONB, nullable=False, default=list, server_default="[]",
    )  # Array of user UUID strings

    target_tier: Mapped[str | None] = mapped_column(
        String(20), nullable=True,
    )

    title: Mapped[str] = mapped_column(String(255), nullable=False)
    body: Mapped[str] = mapped_column(Text(), nullable=False)

    sent_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0",
    )
    failed_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0",
    )

    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="pending", server_default="pending",
        index=True,
    )  # pending, sending, sent, failed

    # Relationships
    admin_user: Mapped["AdminUser | None"] = relationship(
        "AdminUser",
    )
