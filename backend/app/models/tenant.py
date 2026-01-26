"""Tenant model for multi-tenancy."""

from datetime import datetime
from typing import TYPE_CHECKING, Literal
from uuid import UUID

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.user import User


class Tenant(Base, TimestampMixin):
    """
    Tenant model - the root of multi-tenancy.

    Each tenant represents an isolated account/organization.
    For Money Guardian, each user gets their own tenant (single-user tenants).
    This allows for future B2B expansion (family accounts, etc.).
    """

    __tablename__ = "tenants"

    # Tenant name (for display purposes)
    name: Mapped[str] = mapped_column(String(255), nullable=False)

    # Subscription tier
    tier: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="free",
    )  # "free", "pro", "enterprise"

    # Tenant status
    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="active",
    )  # "active", "suspended", "deleted"

    # Stripe customer ID (for billing)
    stripe_customer_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Relationships
    users: Mapped[list["User"]] = relationship(
        "User",
        back_populates="tenant",
        lazy="selectin",
    )
