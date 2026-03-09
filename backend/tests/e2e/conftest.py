"""E2E test fixtures — full user journey tests against real PostgreSQL.

Re-exports all integration fixtures so E2E tests can run with the same
database setup (real PostgreSQL, mocked Redis/token blacklist).
"""

from datetime import date, timedelta
from decimal import Decimal
from uuid import uuid4

import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.alert import Alert
from app.models.tenant import Tenant
from app.models.user import User

from tests.integration.conftest import *  # noqa: F401,F403


@pytest_asyncio.fixture
async def test_alert(
    db_session: AsyncSession,
    test_user: User,
    test_tenant: Tenant,
) -> Alert:
    """Create a test alert for E2E lifecycle tests."""
    alert = Alert(
        id=uuid4(),
        tenant_id=test_tenant.id,
        user_id=test_user.id,
        alert_type="upcoming_charge",
        severity="info",
        title="Netflix renewal",
        message="Netflix will charge $15.99 in 3 days",
        is_read=False,
        is_dismissed=False,
        is_actioned=False,
        push_sent=False,
        email_sent=False,
    )
    db_session.add(alert)
    await db_session.commit()
    await db_session.refresh(alert)
    return alert
