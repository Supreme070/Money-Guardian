"""Alert model for notifications and warnings."""

from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING, Literal
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, Numeric, String, Boolean, Text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TenantMixin, TimestampMixin

if TYPE_CHECKING:
    from app.models.user import User


# Alert types - strictly typed
AlertType = Literal[
    "upcoming_charge",      # Subscription renewing soon
    "overdraft_warning",    # Balance may go negative
    "price_increase",       # Subscription price went up
    "trial_ending",         # Free trial ending
    "unused_subscription",  # AI detected unused sub
    "payment_failed",       # Charge failed
    "large_charge",         # Unusually large charge coming
]

# Alert severity levels
AlertSeverity = Literal["info", "warning", "critical"]


class Alert(Base, TenantMixin, TimestampMixin):
    """
    Alert model for user notifications.

    CRITICAL: Always filter by tenant_id in queries.
    """

    __tablename__ = "alerts"

    # Foreign keys
    tenant_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("tenants.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Optional subscription reference
    subscription_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("subscriptions.id", ondelete="SET NULL"),
        nullable=True,
    )

    # Alert details
    alert_type: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        index=True,
    )
    severity: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
        default="info",
    )  # info, warning, critical

    title: Mapped[str] = mapped_column(String(255), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)

    # Associated amount (if applicable)
    amount: Mapped[Decimal | None] = mapped_column(
        Numeric(10, 2),
        nullable=True,
    )

    # Associated date (if applicable)
    alert_date: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Status
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_dismissed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_actioned: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # Timestamps for user interaction
    read_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    dismissed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Notification tracking
    push_sent: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    email_sent: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="alerts")
