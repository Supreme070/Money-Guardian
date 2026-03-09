"""Feature flag model for gradual rollouts and targeting."""

from datetime import datetime
from typing import TYPE_CHECKING
from uuid import UUID

from sqlalchemy import Boolean, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.admin_user import AdminUser


class FeatureFlag(Base, TimestampMixin):
    """Feature flag for gradual rollouts and user targeting.

    Flags can be targeted by tier, specific user IDs, or rollout percentage.
    """

    __tablename__ = "feature_flags"

    key: Mapped[str] = mapped_column(
        String(100), unique=True, nullable=False, index=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    is_enabled: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False,
    )
    rollout_percentage: Mapped[int] = mapped_column(
        Integer, default=100, nullable=False,
    )  # 0-100

    # Targeting
    target_tiers: Mapped[list[str] | None] = mapped_column(
        JSONB, nullable=True,
    )  # e.g. ["pro", "enterprise"]
    target_user_ids: Mapped[list[str] | None] = mapped_column(
        JSONB, nullable=True,
    )  # e.g. ["uuid1", "uuid2"]

    # Creator
    created_by: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("admin_users.id", ondelete="SET NULL"),
        nullable=True,
    )

    # Relationships
    creator: Mapped["AdminUser | None"] = relationship(
        "AdminUser", foreign_keys=[created_by],
    )
