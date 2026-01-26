"""User model with tenant association."""

from datetime import datetime
from typing import TYPE_CHECKING
from uuid import UUID

from sqlalchemy import ForeignKey, String, Boolean
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TenantMixin, TimestampMixin

if TYPE_CHECKING:
    from app.models.tenant import Tenant
    from app.models.subscription import Subscription
    from app.models.alert import Alert


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
