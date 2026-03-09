"""Customer health snapshot model for tracking user engagement scores."""

from datetime import date, datetime
from uuid import UUID

from sqlalchemy import Date, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class CustomerHealthSnapshot(Base):
    """Point-in-time health score for a user.

    Computed daily by the health_score_tasks Celery beat task.
    Only has created_at (no updated_at) since snapshots are immutable.
    """

    __tablename__ = "customer_health_snapshots"

    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    tenant_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("tenants.id", ondelete="CASCADE"),
        nullable=False,
    )

    score: Mapped[int] = mapped_column(Integer, nullable=False)  # 0-100
    risk_level: Mapped[str] = mapped_column(
        String(20), nullable=False,
    )  # healthy, at_risk, churning

    factors: Mapped[dict[str, int | float | str]] = mapped_column(
        JSONB, nullable=False,
    )

    snapshot_date: Mapped[date] = mapped_column(Date, nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
