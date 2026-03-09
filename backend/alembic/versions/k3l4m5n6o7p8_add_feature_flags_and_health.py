"""Add feature_flags and customer_health_snapshots tables.

Revision ID: k3l4m5n6o7p8
Revises: j2k3l4m5n6o7
Create Date: 2026-03-09 23:00:00.000000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID, JSONB

# revision identifiers
revision = "k3l4m5n6o7p8"
down_revision = "j2k3l4m5n6o7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Feature flags table
    op.create_table(
        "feature_flags",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "key",
            sa.String(100),
            unique=True,
            nullable=False,
            index=True,
        ),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column(
            "is_enabled",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column(
            "rollout_percentage",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("100"),
        ),
        sa.Column("target_tiers", JSONB, nullable=True),
        sa.Column("target_user_ids", JSONB, nullable=True),
        sa.Column(
            "created_by",
            UUID(as_uuid=True),
            sa.ForeignKey("admin_users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "rollout_percentage >= 0 AND rollout_percentage <= 100",
            name="ck_feature_flags_rollout_pct",
        ),
    )

    # Customer health snapshots table
    op.create_table(
        "customer_health_snapshots",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "tenant_id",
            UUID(as_uuid=True),
            sa.ForeignKey("tenants.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("score", sa.Integer(), nullable=False),
        sa.Column(
            "risk_level",
            sa.String(20),
            nullable=False,
        ),  # healthy, at_risk, churning
        sa.Column("factors", JSONB, nullable=False),
        sa.Column("snapshot_date", sa.Date(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.UniqueConstraint(
            "user_id", "snapshot_date",
            name="uq_health_user_date",
        ),
        sa.CheckConstraint(
            "score >= 0 AND score <= 100",
            name="ck_health_score_range",
        ),
    )

    op.create_index(
        "ix_health_tenant_risk",
        "customer_health_snapshots",
        ["tenant_id", "risk_level"],
    )
    op.create_index(
        "ix_health_snapshot_date",
        "customer_health_snapshots",
        ["snapshot_date"],
    )


def downgrade() -> None:
    op.drop_index("ix_health_snapshot_date", table_name="customer_health_snapshots")
    op.drop_index("ix_health_tenant_risk", table_name="customer_health_snapshots")
    op.drop_table("customer_health_snapshots")
    op.drop_table("feature_flags")
