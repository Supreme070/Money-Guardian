"""Add FCM token fields to users table

Revision ID: c4d5e6f7g8h9
Revises: b3c4d5e6f7g8
Create Date: 2026-01-28 16:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c4d5e6f7g8h9'
down_revision: Union[str, None] = 'b3c4d5e6f7g8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add FCM token columns to users table
    op.add_column(
        'users',
        sa.Column('fcm_token', sa.String(length=500), nullable=True)
    )
    op.add_column(
        'users',
        sa.Column('fcm_device_type', sa.String(length=20), nullable=True)
    )


def downgrade() -> None:
    op.drop_column('users', 'fcm_device_type')
    op.drop_column('users', 'fcm_token')
