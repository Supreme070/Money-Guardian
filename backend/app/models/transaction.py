"""Transaction model for bank transactions."""

from datetime import date, datetime
from decimal import Decimal
from typing import TYPE_CHECKING, Literal
from uuid import UUID

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Numeric, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TenantMixin, TimestampMixin

if TYPE_CHECKING:
    from app.models.bank_account import BankAccount
    from app.models.subscription import Subscription


# Strictly typed transaction type
TransactionType = Literal["debit", "credit"]


class Transaction(Base, TenantMixin, TimestampMixin):
    """
    Bank transaction from Plaid/Mono/Stitch.

    Used for subscription detection and spending analysis.

    CRITICAL: Always filter by tenant_id in queries.
    """

    __tablename__ = "transactions"

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
    account_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("bank_accounts.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Link to detected subscription (if this transaction matches a subscription)
    subscription_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("subscriptions.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # Provider transaction ID (unique per provider)
    provider_transaction_id: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        unique=True,
        index=True,
    )

    # Transaction details
    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    merchant_name: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )
    amount: Mapped[Decimal] = mapped_column(
        Numeric(12, 2),
        nullable=False,
    )
    currency: Mapped[str] = mapped_column(
        String(3),
        nullable=False,
        default="USD",
    )
    transaction_type: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
    )  # debit or credit

    # Dates
    transaction_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        index=True,
    )
    posted_date: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
    )

    # Categories (from Plaid/provider)
    category: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
    )
    category_id: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
    )

    # Subscription detection flags
    is_recurring: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    is_subscription: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    recurrence_stream_id: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )  # Plaid recurring stream ID

    # Pending status
    is_pending: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    # Merchant logo (if available)
    logo_url: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True,
    )

    # Raw data for debugging/future use
    raw_data: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
    )

    # Relationships
    account: Mapped["BankAccount"] = relationship(
        "BankAccount",
        back_populates="transactions",
    )
    subscription: Mapped["Subscription | None"] = relationship(
        "Subscription",
    )
