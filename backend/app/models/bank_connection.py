"""Bank connection model for Plaid/Mono/Stitch integrations."""

from datetime import datetime
from typing import TYPE_CHECKING, Literal
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TenantMixin, TimestampMixin, SoftDeleteMixin

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.bank_account import BankAccount


# Strictly typed provider options
BankProviderType = Literal["plaid", "mono", "stitch"]

# Strictly typed connection status
ConnectionStatusType = Literal[
    "pending",
    "connected",
    "error",
    "disconnected",
    "requires_reauth",
]


class BankConnection(Base, TenantMixin, TimestampMixin, SoftDeleteMixin):
    """
    Bank connection via Plaid/Mono/Stitch.

    Stores the encrypted access token and connection metadata.

    CRITICAL: Always filter by tenant_id in queries.
    PRO FEATURE: Bank connections require Pro subscription.
    """

    __tablename__ = "bank_connections"

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

    # Provider information
    provider: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )  # plaid, mono, stitch

    # Provider-specific IDs (access_token is encrypted)
    access_token: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )  # Encrypted with Fernet
    item_id: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )  # Plaid item_id

    # Institution information
    institution_id: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
    )
    institution_name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    institution_logo: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True,
    )

    # Connection status
    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="connected",
    )  # See ConnectionStatusType
    error_code: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
    )
    error_message: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    # Sync tracking
    last_sync_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    last_successful_sync_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    cursor: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )  # Plaid cursor for incremental sync

    # Consent expiry (some providers have time-limited consent)
    consent_expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Relationships
    user: Mapped["User"] = relationship(
        "User",
        back_populates="bank_connections",
    )
    accounts: Mapped[list["BankAccount"]] = relationship(
        "BankAccount",
        back_populates="connection",
        cascade="all, delete-orphan",
        lazy="selectin",
    )
