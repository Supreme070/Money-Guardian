"""Test fixtures for Money Guardian API tests.

Uses SQLite in-memory database for fast, isolated tests.
Mocks Redis-dependent features (token blacklist, rate limiter).
"""

from collections.abc import AsyncGenerator
from datetime import date, timedelta
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import String, event
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.security import create_token_pair, get_password_hash
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models.alert import Alert
from app.models.subscription import Subscription
from app.models.tenant import Tenant
from app.models.user import User

# In-memory SQLite for tests (aiosqlite)
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"


# ── SQLite compat: compile PostgreSQL-specific types for SQLite ──────────
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.ext.compiler import compiles


@compiles(PG_UUID, "sqlite")
def compile_uuid_sqlite(type_: PG_UUID, compiler: object, **kw: object) -> str:
    """Render PostgreSQL UUID as CHAR(36) for SQLite."""
    return "CHAR(36)"


@compiles(JSONB, "sqlite")
def compile_jsonb_sqlite(type_: JSONB, compiler: object, **kw: object) -> str:
    """Render PostgreSQL JSONB as TEXT for SQLite."""
    return "TEXT"


@pytest.fixture(scope="session")
def anyio_backend():
    return "asyncio"


@pytest_asyncio.fixture
async def engine():
    """Create a fresh in-memory database for each test."""
    engine = create_async_engine(TEST_DATABASE_URL, echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


@pytest_asyncio.fixture
async def db_session(engine) -> AsyncGenerator[AsyncSession, None]:
    """Get a test database session."""
    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with session_factory() as session:
        yield session


@pytest_asyncio.fixture
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Get a test HTTP client with mocked DB, Redis, and rate limiter."""

    async def override_get_db() -> AsyncGenerator[AsyncSession, None]:
        yield db_session

    app.dependency_overrides[get_db] = override_get_db

    # Mock Redis-based token blacklist and rate limiter
    mock_limiter = MagicMock()
    mock_limiter.limit.return_value = lambda f: f  # no-op decorator

    with (
        patch("app.api.deps.is_token_blacklisted", new_callable=AsyncMock, return_value=False),
        patch("app.core.token_blacklist.blacklist_token", new_callable=AsyncMock),
        patch("app.core.token_blacklist.is_token_blacklisted", new_callable=AsyncMock, return_value=False),
        patch("app.api.v1.endpoints.auth.blacklist_token", new_callable=AsyncMock),
        patch("app.api.v1.endpoints.auth.is_token_blacklisted", new_callable=AsyncMock, return_value=False),
        patch("app.core.rate_limit.limiter", mock_limiter),
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as c:
            yield c

    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def test_tenant(db_session: AsyncSession) -> Tenant:
    """Create a test tenant."""
    tenant = Tenant(
        id=uuid4(),
        name="Test Tenant",
        tier="free",
        status="active",
    )
    db_session.add(tenant)
    await db_session.commit()
    await db_session.refresh(tenant)
    return tenant


@pytest_asyncio.fixture
async def test_user(db_session: AsyncSession, test_tenant: Tenant) -> User:
    """Create a test user with known credentials."""
    user = User(
        id=uuid4(),
        tenant_id=test_tenant.id,
        email="test@example.com",
        hashed_password=get_password_hash("TestPass123"),
        full_name="Test User",
        is_active=True,
        is_verified=False,
        subscription_tier="free",
        onboarding_completed=False,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest_asyncio.fixture
async def auth_headers(test_user: User) -> dict[str, str]:
    """Get authorization headers for the test user."""
    tokens = create_token_pair(
        user_id=test_user.id,
        tenant_id=test_user.tenant_id,
        email=test_user.email,
    )
    return {"Authorization": f"Bearer {tokens.access_token}"}


@pytest_asyncio.fixture
async def test_subscription(
    db_session: AsyncSession,
    test_user: User,
    test_tenant: Tenant,
) -> Subscription:
    """Create a test subscription."""
    sub = Subscription(
        id=uuid4(),
        tenant_id=test_tenant.id,
        user_id=test_user.id,
        name="Netflix",
        amount=Decimal("15.99"),
        currency="USD",
        billing_cycle="monthly",
        next_billing_date=date.today() + timedelta(days=5),
        is_active=True,
        is_paused=False,
        ai_flag="none",
        source="manual",
    )
    db_session.add(sub)
    await db_session.commit()
    await db_session.refresh(sub)
    return sub


@pytest_asyncio.fixture
async def test_alert(
    db_session: AsyncSession,
    test_user: User,
    test_tenant: Tenant,
) -> Alert:
    """Create a test alert."""
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
