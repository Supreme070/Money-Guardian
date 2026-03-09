"""Approval request model for admin workflow approvals."""

from datetime import datetime
from typing import TYPE_CHECKING
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.admin_user import AdminUser


class ApprovalRequest(Base, TimestampMixin):
    """Approval workflow for sensitive admin actions.

    Non-super_admin users must request approval for high-impact actions
    such as tenant deletion, user purge, bulk operations over 100 items,
    refunds over $100, and MFA disable.
    """

    __tablename__ = "approval_requests"

    requester_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("admin_users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    approver_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("admin_users.id", ondelete="SET NULL"),
        nullable=True,
    )

    action: Mapped[str] = mapped_column(String(100), nullable=False)
    entity_type: Mapped[str] = mapped_column(String(50), nullable=False)
    entity_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), nullable=True,
    )

    parameters: Mapped[dict[str, str | int | bool | None] | None] = mapped_column(
        JSONB, nullable=True,
    )

    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="pending",
    )  # pending, approved, rejected, expired, executed

    reason: Mapped[str] = mapped_column(Text, nullable=False)
    review_note: Mapped[str | None] = mapped_column(Text, nullable=True)

    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False,
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
    )
    executed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
    )

    # Relationships
    requester: Mapped["AdminUser"] = relationship(
        "AdminUser", foreign_keys=[requester_id],
    )
    approver: Mapped["AdminUser | None"] = relationship(
        "AdminUser", foreign_keys=[approver_id],
    )
