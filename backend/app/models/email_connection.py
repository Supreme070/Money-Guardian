"""Email connection model for Gmail/Outlook/Yahoo OAuth connections."""

from datetime import datetime
from typing import TYPE_CHECKING, Literal
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TenantMixin, TimestampMixin, SoftDeleteMixin

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.scanned_email import ScannedEmail


# Strictly typed email provider options
EmailProviderType = Literal["gmail", "outlook", "yahoo", "icloud"]

# Strictly typed connection status
EmailConnectionStatusType = Literal[
    "pending",
    "connected",
    "error",
    "disconnected",
    "requires_reauth",
]


class EmailConnection(Base, TenantMixin, TimestampMixin, SoftDeleteMixin):
    """
    Email provider OAuth connection.

    Stores encrypted OAuth tokens for scanning subscription emails.

    CRITICAL: Always filter by tenant_id in queries.
    PRO FEATURE: Email connections require Pro subscription.
    """

    __tablename__ = "email_connections"

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
    )  # gmail, outlook, yahoo, icloud
    email_address: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )

    # OAuth tokens (encrypted with Fernet)
    access_token: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )  # Encrypted
    refresh_token: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )  # Encrypted
    token_expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Scopes granted by user
    scopes: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )  # Comma-separated list of scopes

    # Connection status
    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="connected",
    )  # See EmailConnectionStatusType
    error_message: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    # Scan tracking
    last_scan_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    last_successful_scan_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    scan_cursor: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )  # Page token for pagination
    oldest_email_scanned: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Scan depth (based on tier)
    scan_depth_days: Mapped[int] = mapped_column(
        Integer,
        default=90,
        nullable=False,
    )  # Free: 90 days, Pro: 1095 days (3 years)

    # Relationships
    user: Mapped["User"] = relationship(
        "User",
        back_populates="email_connections",
    )
    scanned_emails: Mapped[list["ScannedEmail"]] = relationship(
        "ScannedEmail",
        back_populates="connection",
        cascade="all, delete-orphan",
        lazy="selectin",
    )
