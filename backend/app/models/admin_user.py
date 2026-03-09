"""Admin user, session, and audit log models.

These are separate from the regular User model. Admin users are NOT
multi-tenant — they operate across all tenants.
"""

from datetime import datetime
from typing import Literal
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, String, Boolean, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin


class AdminUser(Base, TimestampMixin):
    """Admin portal user with role-based access."""

    __tablename__ = "admin_users"

    email: Mapped[str] = mapped_column(
        String(255), unique=True, nullable=False, index=True,
    )
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)

    role: Mapped[str] = mapped_column(
        String(20), nullable=False, index=True,
    )  # super_admin, admin, support, viewer

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # MFA (TOTP)
    mfa_secret: Mapped[str | None] = mapped_column(
        String(255), nullable=True,
    )  # Encrypted TOTP secret
    mfa_enabled: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    last_login_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
    )

    # Relationships
    sessions: Mapped[list["AdminSession"]] = relationship(
        "AdminSession", back_populates="admin_user", cascade="all, delete-orphan",
    )
    audit_entries: Mapped[list["AuditLog"]] = relationship(
        "AuditLog", back_populates="admin_user",
    )


class AdminSession(Base, TimestampMixin):
    """Admin JWT session for tracking and revocation."""

    __tablename__ = "admin_sessions"

    admin_user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("admin_users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    token_hash: Mapped[str] = mapped_column(
        String(64), nullable=False, index=True,
    )  # SHA-256 of refresh token

    ip_address: Mapped[str] = mapped_column(String(45), nullable=False)
    user_agent: Mapped[str] = mapped_column(String(500), nullable=False, default="")

    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False,
    )
    revoked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
    )

    # Relationships
    admin_user: Mapped["AdminUser"] = relationship(
        "AdminUser", back_populates="sessions",
    )

    @property
    def is_revoked(self) -> bool:
        return self.revoked_at is not None


class AuditLog(Base):
    """Append-only audit trail for admin actions.

    Every state-changing admin operation is logged here.
    """

    __tablename__ = "audit_logs"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True,
    )

    admin_user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("admin_users.id", ondelete="SET NULL"),
        nullable=True,  # Nullable for system-generated entries
        index=True,
    )

    action: Mapped[str] = mapped_column(
        String(100), nullable=False, index=True,
    )  # e.g. "user.deactivate", "tenant.tier_override"

    entity_type: Mapped[str] = mapped_column(
        String(50), nullable=False,
    )  # "user", "tenant", "admin_user", etc.

    entity_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), nullable=True,
    )

    details: Mapped[dict[str, str | int | bool | None]] = mapped_column(
        JSONB, nullable=False, default=dict, server_default="{}",
    )

    ip_address: Mapped[str] = mapped_column(String(45), nullable=False, default="")
    user_agent: Mapped[str] = mapped_column(String(500), nullable=False, default="")

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
    )

    # Relationships
    admin_user: Mapped["AdminUser | None"] = relationship(
        "AdminUser", back_populates="audit_entries",
    )
