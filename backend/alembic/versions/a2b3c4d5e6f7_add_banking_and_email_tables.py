"""Add banking and email integration tables

Revision ID: a2b3c4d5e6f7
Revises: f1ff611aadd1
Create Date: 2026-01-28 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'a2b3c4d5e6f7'
down_revision: Union[str, None] = 'f1ff611aadd1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ### Bank Connections Table ###
    op.create_table(
        'bank_connections',
        sa.Column('tenant_id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('provider', sa.String(length=20), nullable=False),
        sa.Column('access_token', sa.Text(), nullable=False),
        sa.Column('item_id', sa.String(length=255), nullable=True),
        sa.Column('institution_id', sa.String(length=100), nullable=True),
        sa.Column('institution_name', sa.String(length=255), nullable=False),
        sa.Column('institution_logo', sa.String(length=500), nullable=True),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='connected'),
        sa.Column('error_code', sa.String(length=50), nullable=True),
        sa.Column('error_message', sa.Text(), nullable=True),
        sa.Column('last_sync_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('last_successful_sync_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('cursor', sa.Text(), nullable=True),
        sa.Column('consent_expires_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_bank_connections_tenant_id'), 'bank_connections', ['tenant_id'], unique=False)
    op.create_index(op.f('ix_bank_connections_user_id'), 'bank_connections', ['user_id'], unique=False)

    # ### Bank Accounts Table ###
    op.create_table(
        'bank_accounts',
        sa.Column('tenant_id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('connection_id', sa.UUID(), nullable=False),
        sa.Column('provider_account_id', sa.String(length=255), nullable=False),
        sa.Column('name', sa.String(length=255), nullable=False),
        sa.Column('official_name', sa.String(length=255), nullable=True),
        sa.Column('mask', sa.String(length=10), nullable=True),
        sa.Column('account_type', sa.String(length=20), nullable=False),
        sa.Column('account_subtype', sa.String(length=30), nullable=True),
        sa.Column('current_balance', sa.Numeric(precision=12, scale=2), nullable=True),
        sa.Column('available_balance', sa.Numeric(precision=12, scale=2), nullable=True),
        sa.Column('limit', sa.Numeric(precision=12, scale=2), nullable=True),
        sa.Column('currency', sa.String(length=3), nullable=False, server_default='USD'),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('is_primary', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('include_in_pulse', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('balance_updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['connection_id'], ['bank_connections.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_bank_accounts_tenant_id'), 'bank_accounts', ['tenant_id'], unique=False)
    op.create_index(op.f('ix_bank_accounts_user_id'), 'bank_accounts', ['user_id'], unique=False)
    op.create_index(op.f('ix_bank_accounts_connection_id'), 'bank_accounts', ['connection_id'], unique=False)

    # ### Transactions Table ###
    op.create_table(
        'transactions',
        sa.Column('tenant_id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('account_id', sa.UUID(), nullable=False),
        sa.Column('subscription_id', sa.UUID(), nullable=True),
        sa.Column('provider_transaction_id', sa.String(length=255), nullable=False),
        sa.Column('name', sa.String(length=255), nullable=False),
        sa.Column('merchant_name', sa.String(length=255), nullable=True),
        sa.Column('amount', sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column('currency', sa.String(length=3), nullable=False, server_default='USD'),
        sa.Column('transaction_type', sa.String(length=10), nullable=False),
        sa.Column('transaction_date', sa.Date(), nullable=False),
        sa.Column('posted_date', sa.Date(), nullable=True),
        sa.Column('category', sa.String(length=100), nullable=True),
        sa.Column('category_id', sa.String(length=50), nullable=True),
        sa.Column('is_recurring', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('is_subscription', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('recurrence_stream_id', sa.String(length=255), nullable=True),
        sa.Column('is_pending', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('logo_url', sa.String(length=500), nullable=True),
        sa.Column('raw_data', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['account_id'], ['bank_accounts.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['subscription_id'], ['subscriptions.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('provider_transaction_id')
    )
    op.create_index(op.f('ix_transactions_tenant_id'), 'transactions', ['tenant_id'], unique=False)
    op.create_index(op.f('ix_transactions_user_id'), 'transactions', ['user_id'], unique=False)
    op.create_index(op.f('ix_transactions_account_id'), 'transactions', ['account_id'], unique=False)
    op.create_index(op.f('ix_transactions_subscription_id'), 'transactions', ['subscription_id'], unique=False)
    op.create_index(op.f('ix_transactions_transaction_date'), 'transactions', ['transaction_date'], unique=False)
    op.create_index(op.f('ix_transactions_provider_transaction_id'), 'transactions', ['provider_transaction_id'], unique=False)

    # ### Email Connections Table ###
    op.create_table(
        'email_connections',
        sa.Column('tenant_id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('provider', sa.String(length=20), nullable=False),
        sa.Column('email_address', sa.String(length=255), nullable=False),
        sa.Column('access_token', sa.Text(), nullable=False),
        sa.Column('refresh_token', sa.Text(), nullable=True),
        sa.Column('token_expires_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('scopes', sa.Text(), nullable=True),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='connected'),
        sa.Column('error_message', sa.Text(), nullable=True),
        sa.Column('last_scan_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('last_successful_scan_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('scan_cursor', sa.Text(), nullable=True),
        sa.Column('oldest_email_scanned', sa.DateTime(timezone=True), nullable=True),
        sa.Column('scan_depth_days', sa.Integer(), nullable=False, server_default='90'),
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_email_connections_tenant_id'), 'email_connections', ['tenant_id'], unique=False)
    op.create_index(op.f('ix_email_connections_user_id'), 'email_connections', ['user_id'], unique=False)

    # ### Scanned Emails Table ###
    op.create_table(
        'scanned_emails',
        sa.Column('tenant_id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('connection_id', sa.UUID(), nullable=False),
        sa.Column('subscription_id', sa.UUID(), nullable=True),
        sa.Column('provider_message_id', sa.String(length=255), nullable=False),
        sa.Column('thread_id', sa.String(length=255), nullable=True),
        sa.Column('from_address', sa.String(length=255), nullable=False),
        sa.Column('from_name', sa.String(length=255), nullable=True),
        sa.Column('subject', sa.Text(), nullable=False),
        sa.Column('received_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('email_type', sa.String(length=30), nullable=False),
        sa.Column('confidence_score', sa.Numeric(precision=3, scale=2), nullable=False),
        sa.Column('merchant_name', sa.String(length=255), nullable=True),
        sa.Column('detected_amount', sa.Numeric(precision=10, scale=2), nullable=True),
        sa.Column('currency', sa.String(length=3), nullable=True),
        sa.Column('billing_cycle', sa.String(length=20), nullable=True),
        sa.Column('next_billing_date', sa.DateTime(timezone=True), nullable=True),
        sa.Column('is_processed', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('is_subscription_created', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('extracted_data', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['connection_id'], ['email_connections.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['subscription_id'], ['subscriptions.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('provider_message_id')
    )
    op.create_index(op.f('ix_scanned_emails_tenant_id'), 'scanned_emails', ['tenant_id'], unique=False)
    op.create_index(op.f('ix_scanned_emails_user_id'), 'scanned_emails', ['user_id'], unique=False)
    op.create_index(op.f('ix_scanned_emails_connection_id'), 'scanned_emails', ['connection_id'], unique=False)
    op.create_index(op.f('ix_scanned_emails_received_at'), 'scanned_emails', ['received_at'], unique=False)
    op.create_index(op.f('ix_scanned_emails_provider_message_id'), 'scanned_emails', ['provider_message_id'], unique=False)

    # ### Add new columns to subscriptions table ###
    op.add_column('subscriptions', sa.Column('email_message_id', sa.String(length=255), nullable=True))
    op.add_column('subscriptions', sa.Column('bank_transaction_pattern', sa.String(length=255), nullable=True))


def downgrade() -> None:
    # ### Remove columns from subscriptions ###
    op.drop_column('subscriptions', 'bank_transaction_pattern')
    op.drop_column('subscriptions', 'email_message_id')

    # ### Drop scanned_emails ###
    op.drop_index(op.f('ix_scanned_emails_provider_message_id'), table_name='scanned_emails')
    op.drop_index(op.f('ix_scanned_emails_received_at'), table_name='scanned_emails')
    op.drop_index(op.f('ix_scanned_emails_connection_id'), table_name='scanned_emails')
    op.drop_index(op.f('ix_scanned_emails_user_id'), table_name='scanned_emails')
    op.drop_index(op.f('ix_scanned_emails_tenant_id'), table_name='scanned_emails')
    op.drop_table('scanned_emails')

    # ### Drop email_connections ###
    op.drop_index(op.f('ix_email_connections_user_id'), table_name='email_connections')
    op.drop_index(op.f('ix_email_connections_tenant_id'), table_name='email_connections')
    op.drop_table('email_connections')

    # ### Drop transactions ###
    op.drop_index(op.f('ix_transactions_provider_transaction_id'), table_name='transactions')
    op.drop_index(op.f('ix_transactions_transaction_date'), table_name='transactions')
    op.drop_index(op.f('ix_transactions_subscription_id'), table_name='transactions')
    op.drop_index(op.f('ix_transactions_account_id'), table_name='transactions')
    op.drop_index(op.f('ix_transactions_user_id'), table_name='transactions')
    op.drop_index(op.f('ix_transactions_tenant_id'), table_name='transactions')
    op.drop_table('transactions')

    # ### Drop bank_accounts ###
    op.drop_index(op.f('ix_bank_accounts_connection_id'), table_name='bank_accounts')
    op.drop_index(op.f('ix_bank_accounts_user_id'), table_name='bank_accounts')
    op.drop_index(op.f('ix_bank_accounts_tenant_id'), table_name='bank_accounts')
    op.drop_table('bank_accounts')

    # ### Drop bank_connections ###
    op.drop_index(op.f('ix_bank_connections_user_id'), table_name='bank_connections')
    op.drop_index(op.f('ix_bank_connections_tenant_id'), table_name='bank_connections')
    op.drop_table('bank_connections')
