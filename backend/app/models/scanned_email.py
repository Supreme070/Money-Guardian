"""Scanned email model for subscription detection from emails."""

from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING, Literal
from uuid import UUID

from sqlalchemy import Boolean, DateTime, ForeignKey, Numeric, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TenantMixin, TimestampMixin

if TYPE_CHECKING:
    from app.models.email_connection import EmailConnection
    from app.models.subscription import Subscription


# Strictly typed email types for subscription detection
EmailType = Literal[
    "subscription_confirmation",
    "receipt",
    "billing_reminder",
    "price_change",
    "trial_ending",
    "payment_failed",
    "cancellation",
    "renewal_notice",
    "other",
]


class ScannedEmail(Base, TenantMixin, TimestampMixin):
    """
    Processed email for subscription detection.

    Stores parsed data from subscription-related emails.

    CRITICAL: Always filter by tenant_id in queries.
    """

    __tablename__ = "scanned_emails"

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
    connection_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("email_connections.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Link to created/matched subscription
    subscription_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("subscriptions.id", ondelete="SET NULL"),
        nullable=True,
    )

    # Email identifiers
    provider_message_id: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        unique=True,
        index=True,
    )
    thread_id: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )

    # Email metadata
    from_address: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    from_name: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )
    subject: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )
    received_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        index=True,
    )

    # Detection results
    email_type: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
    )  # See EmailType
    confidence_score: Mapped[Decimal] = mapped_column(
        Numeric(3, 2),
        nullable=False,
    )  # 0.00 - 1.00

    # Extracted data
    merchant_name: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )
    detected_amount: Mapped[Decimal | None] = mapped_column(
        Numeric(10, 2),
        nullable=True,
    )
    currency: Mapped[str | None] = mapped_column(
        String(3),
        nullable=True,
    )
    billing_cycle: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
    )  # weekly, monthly, quarterly, yearly
    next_billing_date: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Processing status
    is_processed: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    is_subscription_created: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    # Raw extracted data for debugging
    extracted_data: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
    )

    # Relationships
    connection: Mapped["EmailConnection"] = relationship(
        "EmailConnection",
        back_populates="scanned_emails",
    )
    subscription: Mapped["Subscription | None"] = relationship(
        "Subscription",
    )
