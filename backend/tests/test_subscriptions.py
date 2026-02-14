"""Tests for subscription CRUD endpoints."""

from datetime import date, timedelta
from uuid import uuid4

import pytest
from httpx import AsyncClient

from app.models.subscription import Subscription
from app.models.user import User

# API prefix
P = "/api/v1/subscriptions"


@pytest.mark.asyncio
async def test_create_subscription(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """POST /subscriptions creates a subscription."""
    response = await client.post(
        P,
        headers=auth_headers,
        json={
            "name": "Spotify",
            "amount": 9.99,
            "billing_cycle": "monthly",
            "next_billing_date": str(date.today() + timedelta(days=10)),
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Spotify"
    assert data["amount"] == 9.99
    assert data["billing_cycle"] == "monthly"
    assert data["is_active"] is True


@pytest.mark.asyncio
async def test_create_subscription_invalid_cycle(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """POST /subscriptions with invalid billing cycle returns 422."""
    response = await client.post(
        P,
        headers=auth_headers,
        json={
            "name": "Bad Sub",
            "amount": 5.00,
            "billing_cycle": "biweekly",
            "next_billing_date": str(date.today() + timedelta(days=10)),
        },
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_list_subscriptions(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_subscription: Subscription,
) -> None:
    """GET /subscriptions returns list with totals."""
    response = await client.get(P, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["total_count"] >= 1
    assert len(data["subscriptions"]) >= 1
    assert data["monthly_total"] > 0


@pytest.mark.asyncio
async def test_get_subscription_by_id(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_subscription: Subscription,
) -> None:
    """GET /subscriptions/{id} returns the subscription."""
    response = await client.get(
        f"{P}/{test_subscription.id}",
        headers=auth_headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Netflix"
    assert data["amount"] == 15.99


@pytest.mark.asyncio
async def test_get_subscription_not_found(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """GET /subscriptions/{id} with unknown id returns 404."""
    response = await client.get(
        f"{P}/{uuid4()}",
        headers=auth_headers,
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_update_subscription(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_subscription: Subscription,
) -> None:
    """PATCH /subscriptions/{id} updates fields."""
    response = await client.patch(
        f"{P}/{test_subscription.id}",
        headers=auth_headers,
        json={"name": "Netflix Premium", "amount": 22.99},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Netflix Premium"
    assert data["amount"] == 22.99


@pytest.mark.asyncio
async def test_delete_subscription(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_subscription: Subscription,
) -> None:
    """DELETE /subscriptions/{id} soft-deletes it."""
    response = await client.delete(
        f"{P}/{test_subscription.id}",
        headers=auth_headers,
    )
    assert response.status_code == 204

    # Verify it's gone from list
    list_resp = await client.get(P, headers=auth_headers)
    sub_ids = [s["id"] for s in list_resp.json()["subscriptions"]]
    assert str(test_subscription.id) not in sub_ids


@pytest.mark.asyncio
async def test_subscription_tenant_isolation(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
    db_session,
    test_tenant,
) -> None:
    """User cannot see another tenant's subscriptions."""
    from app.models.tenant import Tenant
    from decimal import Decimal

    # Create a second tenant and subscription
    other_tenant = Tenant(
        id=uuid4(),
        name="Other Tenant",
        tier="free",
        status="active",
    )
    db_session.add(other_tenant)

    other_user = User(
        id=uuid4(),
        tenant_id=other_tenant.id,
        email="other@example.com",
        hashed_password="hashed",
        full_name="Other",
        is_active=True,
        is_verified=False,
        subscription_tier="free",
        onboarding_completed=False,
    )
    db_session.add(other_user)

    other_sub = Subscription(
        id=uuid4(),
        tenant_id=other_tenant.id,
        user_id=other_user.id,
        name="Secret Sub",
        amount=Decimal("99.99"),
        currency="USD",
        billing_cycle="monthly",
        next_billing_date=date.today() + timedelta(days=3),
        is_active=True,
        is_paused=False,
        ai_flag="none",
        source="manual",
    )
    db_session.add(other_sub)
    await db_session.commit()

    # Our test_user should NOT see the other tenant's subscription
    response = await client.get(P, headers=auth_headers)
    sub_names = [s["name"] for s in response.json()["subscriptions"]]
    assert "Secret Sub" not in sub_names

    # Direct access by ID should also fail
    response = await client.get(
        f"{P}/{other_sub.id}",
        headers=auth_headers,
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_list_subscriptions_unauthenticated(client: AsyncClient) -> None:
    """GET /subscriptions without auth returns 403."""
    response = await client.get(P)
    assert response.status_code == 403
