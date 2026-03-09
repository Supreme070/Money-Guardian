"""User model with tenant association."""

from datetime import datetime
from typing import TYPE_CHECKING
from uuid import UUID

from sqlalchemy import ForeignKey, String, Boolean
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TenantMixin, TimestampMixin

if TYPE_CHECKING:
    from app.models.tenant import Tenant
    from app.models.subscription import Subscription
    from app.models.alert import Alert
    from app.models.bank_connection import BankConnection
    from app.models.email_connection import EmailConnection


class User(Base, TenantMixin, TimestampMixin):
    """
    User model.

    CRITICAL: Always filter by tenant_id in queries.
    """

    __tablename__ = "users"

    # Foreign key to tenant
    tenant_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("tenants.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # User info
    email: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        nullable=False,
        index=True,
    )
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Account status
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # Firebase UID (if using Firebase Auth)
    firebase_uid: Mapped[str | None] = mapped_column(String(128), nullable=True, unique=True)

    # Last activity
    last_login_at: Mapped[datetime | None] = mapped_column(nullable=True)

    # Notification preferences
    push_notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    email_notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=True)

    # Email suppression (system-controlled — bounce/complaint from SES/SNS)
    email_suppressed: Mapped[bool] = mapped_column(Boolean, default=False)
    email_suppressed_reason: Mapped[str | None] = mapped_column(String(50), nullable=True)

    # Granular notification type preferences (JSONB)
    notification_preferences: Mapped[dict[str, bool]] = mapped_column(
        JSONB,
        nullable=False,
        default=dict,
        server_default="{}",
    )

    # Subscription tier (free, pro, premium)
    subscription_tier: Mapped[str] = mapped_column(
        String(20), default="free", nullable=False
    )
    subscription_expires_at: Mapped[datetime | None] = mapped_column(nullable=True)

    # Onboarding
    onboarding_completed: Mapped[bool] = mapped_column(Boolean, default=False)

    # Legal consent tracking (GDPR/compliance)
    terms_accepted_at: Mapped[datetime | None] = mapped_column(nullable=True)
    privacy_accepted_at: Mapped[datetime | None] = mapped_column(nullable=True)

    # Email verification
    email_verification_token: Mapped[str | None] = mapped_column(String(255), nullable=True)
    email_verification_token_expires_at: Mapped[datetime | None] = mapped_column(nullable=True)

    # Password reset
    password_reset_token: Mapped[str | None] = mapped_column(String(255), nullable=True)
    password_reset_token_expires_at: Mapped[datetime | None] = mapped_column(nullable=True)

    # Push notifications (FCM)
    fcm_token: Mapped[str | None] = mapped_column(String(500), nullable=True)
    fcm_device_type: Mapped[str | None] = mapped_column(String(20), nullable=True)

    # Relationships
    tenant: Mapped["Tenant"] = relationship("Tenant", back_populates="users")
    subscriptions: Mapped[list["Subscription"]] = relationship(
        "Subscription",
        back_populates="user",
        lazy="selectin",
    )
    alerts: Mapped[list["Alert"]] = relationship(
        "Alert",
        back_populates="user",
        lazy="selectin",
    )
    bank_connections: Mapped[list["BankConnection"]] = relationship(
        "BankConnection",
        back_populates="user",
        lazy="selectin",
    )
    email_connections: Mapped[list["EmailConnection"]] = relationship(
        "EmailConnection",
        back_populates="user",
        lazy="selectin",
    )
