"""Webhook event log model for tracking inbound webhooks."""

from datetime import datetime
from uuid import UUID

from sqlalchemy import DateTime, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class WebhookEvent(Base):
    """Append-only log of inbound webhook events from external providers.

    Tracks Stripe, Plaid, and SES webhook deliveries with processing
    status and timing for the admin webhook dashboard.
    """

    __tablename__ = "webhook_events"

    provider: Mapped[str] = mapped_column(
        String(50), nullable=False,
    )  # stripe, plaid, ses

    event_type: Mapped[str] = mapped_column(String(100), nullable=False)
    event_id: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    payload_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)

    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="received",
    )  # received, processed, failed, ignored

    processing_time_ms: Mapped[int | None] = mapped_column(
        Integer, nullable=True,
    )
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
    )
