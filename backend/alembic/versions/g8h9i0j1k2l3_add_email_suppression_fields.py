"""Add email suppression fields to users table.

Revision ID: g8h9i0j1k2l3
Revises: f7g8h9i0j1k2
Create Date: 2026-03-09

System-controlled email suppression for SES bounce/complaint handling.
Separate from user-controlled email_notifications_enabled preference.
"""

from alembic import op
import sqlalchemy as sa

revision = "g8h9i0j1k2l3"
down_revision = "f7g8h9i0j1k2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("email_suppressed", sa.Boolean(), nullable=False, server_default="false"),
    )
    op.add_column(
        "users",
        sa.Column("email_suppressed_reason", sa.String(50), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "email_suppressed_reason")
    op.drop_column("users", "email_suppressed")
