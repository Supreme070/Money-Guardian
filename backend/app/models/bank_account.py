"""Bank account model for individual accounts within a connection."""

from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING, Literal
from uuid import UUID

from sqlalchemy import Boolean, DateTime, ForeignKey, Numeric, String
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TenantMixin, TimestampMixin

if TYPE_CHECKING:
    from app.models.bank_connection import BankConnection
    from app.models.transaction import Transaction


# Strictly typed account types
AccountType = Literal[
    "checking",
    "savings",
    "credit",
    "loan",
    "investment",
    "other",
]

# Strictly typed account subtypes
AccountSubtype = Literal[
    "checking",
    "savings",
    "money_market",
    "cd",
    "credit_card",
    "auto",
    "mortgage",
    "student",
    "personal",
    "brokerage",
    "ira",
    "401k",
    "other",
]


class BankAccount(Base, TenantMixin, TimestampMixin):
    """
    Individual bank account linked via Plaid/Mono/Stitch.

    CRITICAL: Always filter by tenant_id in queries.
    """

    __tablename__ = "bank_accounts"

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
        ForeignKey("bank_connections.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Provider account ID
    provider_account_id: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )

    # Account information
    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    official_name: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )
    mask: Mapped[str | None] = mapped_column(
        String(10),
        nullable=True,
    )  # Last 4 digits

    # Account type
    account_type: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )  # See AccountType
    account_subtype: Mapped[str | None] = mapped_column(
        String(30),
        nullable=True,
    )  # See AccountSubtype

    # Balances
    current_balance: Mapped[Decimal | None] = mapped_column(
        Numeric(12, 2),
        nullable=True,
    )
    available_balance: Mapped[Decimal | None] = mapped_column(
        Numeric(12, 2),
        nullable=True,
    )
    limit: Mapped[Decimal | None] = mapped_column(
        Numeric(12, 2),
        nullable=True,
    )  # For credit cards
    currency: Mapped[str] = mapped_column(
        String(3),
        nullable=False,
        default="USD",
    )

    # Status flags
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )
    is_primary: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )  # User's main account for calculations
    include_in_pulse: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )  # Include in Daily Pulse balance

    # Balance last updated
    balance_updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Relationships
    connection: Mapped["BankConnection"] = relationship(
        "BankConnection",
        back_populates="accounts",
    )
    transactions: Mapped[list["Transaction"]] = relationship(
        "Transaction",
        back_populates="account",
        lazy="selectin",
    )
