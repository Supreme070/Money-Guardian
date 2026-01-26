"""Subscription model for tracking recurring charges."""

from datetime import date, datetime
from decimal import Decimal
from typing import TYPE_CHECKING, Literal
from uuid import UUID

from sqlalchemy import Date, ForeignKey, Numeric, String, Boolean, Text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TenantMixin, TimestampMixin, SoftDeleteMixin

if TYPE_CHECKING:
    from app.models.user import User


# Billing cycle options - strictly typed
BillingCycle = Literal["weekly", "monthly", "quarterly", "yearly"]

# AI flag types for waste detection
AIFlagType = Literal[
    "none",
    "unused",           # Not used in 30+ days
    "duplicate",        # Similar to another subscription
    "price_increase",   # Price went up recently
    "trial_ending",     # Free trial ending soon
    "forgotten",        # Added long ago, rarely used
]


class Subscription(Base, TenantMixin, TimestampMixin, SoftDeleteMixin):
    """
    Subscription model for recurring charges.

    CRITICAL: Always filter by tenant_id in queries.
    """

    __tablename__ = "subscriptions"

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

    # Subscription info
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Billing details
    amount: Mapped[Decimal] = mapped_column(
        Numeric(10, 2),
        nullable=False,
    )
    currency: Mapped[str] = mapped_column(
        String(3),
        nullable=False,
        default="USD",
    )
    billing_cycle: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )  # weekly, monthly, quarterly, yearly

    # Dates
    next_billing_date: Mapped[date] = mapped_column(Date, nullable=False)
    start_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    trial_end_date: Mapped[date | None] = mapped_column(Date, nullable=True)

    # Status
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_paused: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # AI detection fields
    ai_flag: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="none",
    )  # See AIFlagType
    ai_flag_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    last_usage_detected: Mapped[datetime | None] = mapped_column(nullable=True)

    # Previous amount (for price increase detection)
    previous_amount: Mapped[Decimal | None] = mapped_column(
        Numeric(10, 2),
        nullable=True,
    )

    # Source of subscription detection
    source: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="manual",
    )  # "manual", "plaid", "gmail", "ai_detected"

    # External IDs
    plaid_transaction_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Display customization
    color: Mapped[str | None] = mapped_column(String(7), nullable=True)  # Hex color
    icon: Mapped[str | None] = mapped_column(String(50), nullable=True)
    logo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="subscriptions")
