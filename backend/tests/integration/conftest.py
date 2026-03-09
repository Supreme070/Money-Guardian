"""Integration test fixtures using real PostgreSQL and Redis.

Unlike the unit test conftest (SQLite in-memory), these fixtures connect
to actual PostgreSQL and Redis services — the same as production.
"""

import os
from collections.abc import AsyncGenerator
from datetime import date, timedelta
from decimal import Decimal
from unittest.mock import AsyncMock, patch
from uuid import uuid4

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.security import create_token_pair, get_password_hash
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models.alert import Alert
from app.models.subscription import Subscription
from app.models.tenant import Tenant
from app.models.user import User

# Use the real PostgreSQL from env (CI sets this, local Docker also works)
INTEGRATION_DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql+asyncpg://postgres:postgres@localhost:5432/money_guardian_test",
)


@pytest.fixture(scope="session")
def anyio_backend() -> str:
    return "asyncio"


@pytest_asyncio.fixture
async def engine():
    """Create tables in real PostgreSQL for each test."""
    test_engine = create_async_engine(INTEGRATION_DATABASE_URL, echo=False)
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield test_engine
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await test_engine.dispose()


@pytest_asyncio.fixture
async def db_session(engine) -> AsyncGenerator[AsyncSession, None]:
    """Get a real PostgreSQL test session."""
    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with session_factory() as session:
        yield session


@pytest_asyncio.fixture
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """HTTP client with real DB, real Redis, rate limiter ENABLED."""

    async def override_get_db() -> AsyncGenerator[AsyncSession, None]:
        yield db_session

    app.dependency_overrides[get_db] = override_get_db

    # NOTE: Rate limiter stays ENABLED (unlike unit tests)
    # Token blacklist still mocked — would need running Redis to test fully
    with (
        patch("app.api.deps.is_token_blacklisted", new_callable=AsyncMock, return_value=False),
        patch("app.core.token_blacklist.blacklist_token", new_callable=AsyncMock),
        patch("app.core.token_blacklist.is_token_blacklisted", new_callable=AsyncMock, return_value=False),
        patch("app.api.v1.endpoints.auth.blacklist_token", new_callable=AsyncMock),
        patch("app.api.v1.endpoints.auth.is_token_blacklisted", new_callable=AsyncMock, return_value=False),
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as c:
            yield c

    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def client_no_rate_limit(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """HTTP client with rate limiter disabled (for non-rate-limit tests)."""
    from app.core.rate_limit import limiter as real_limiter

    async def override_get_db() -> AsyncGenerator[AsyncSession, None]:
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    real_limiter.enabled = False
    app.state.limiter = real_limiter

    with (
        patch("app.api.deps.is_token_blacklisted", new_callable=AsyncMock, return_value=False),
        patch("app.core.token_blacklist.blacklist_token", new_callable=AsyncMock),
        patch("app.core.token_blacklist.is_token_blacklisted", new_callable=AsyncMock, return_value=False),
        patch("app.api.v1.endpoints.auth.blacklist_token", new_callable=AsyncMock),
        patch("app.api.v1.endpoints.auth.is_token_blacklisted", new_callable=AsyncMock, return_value=False),
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as c:
            yield c

    real_limiter.enabled = True
    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def test_tenant(db_session: AsyncSession) -> Tenant:
    """Create a test tenant."""
    tenant = Tenant(
        id=uuid4(),
        name="Integration Test Tenant",
        tier="free",
        status="active",
    )
    db_session.add(tenant)
    await db_session.commit()
    await db_session.refresh(tenant)
    return tenant


@pytest_asyncio.fixture
async def pro_tenant(db_session: AsyncSession) -> Tenant:
    """Create a Pro tier test tenant."""
    tenant = Tenant(
        id=uuid4(),
        name="Pro Integration Tenant",
        tier="pro",
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
        email="integration-test@example.com",
        hashed_password=get_password_hash("TestPass123"),
        full_name="Integration Test User",
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
async def pro_user(db_session: AsyncSession, pro_tenant: Tenant) -> User:
    """Create a Pro tier test user."""
    user = User(
        id=uuid4(),
        tenant_id=pro_tenant.id,
        email="pro-test@example.com",
        hashed_password=get_password_hash("TestPass123"),
        full_name="Pro Test User",
        is_active=True,
        is_verified=True,
        subscription_tier="pro",
        onboarding_completed=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest_asyncio.fixture
async def auth_headers(test_user: User) -> dict[str, str]:
    """Get authorization headers for the free tier test user."""
    tokens = create_token_pair(
        user_id=test_user.id,
        tenant_id=test_user.tenant_id,
        email=test_user.email,
    )
    return {"Authorization": f"Bearer {tokens.access_token}"}


@pytest_asyncio.fixture
async def pro_auth_headers(pro_user: User) -> dict[str, str]:
    """Get authorization headers for the Pro tier test user."""
    tokens = create_token_pair(
        user_id=pro_user.id,
        tenant_id=pro_user.tenant_id,
        email=pro_user.email,
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
