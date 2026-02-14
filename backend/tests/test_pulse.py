"""Tests for pulse (home screen) endpoints."""

import pytest
from httpx import AsyncClient

from app.models.subscription import Subscription
from app.models.user import User

# API prefix
P = "/api/v1/pulse"


@pytest.mark.asyncio
async def test_get_pulse_no_data(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """GET /pulse with no subscriptions or bank returns default safe status."""
    response = await client.get(P, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "safe"
    assert data["has_bank_connected"] is False
    assert data["safe_to_spend"] == 0.0
    assert data["active_subscriptions_count"] == 0
    assert data["upcoming_charges"] == []
    assert "calculated_at" in data
    assert "next_refresh_at" in data


@pytest.mark.asyncio
async def test_get_pulse_with_subscription(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_subscription: Subscription,
) -> None:
    """GET /pulse with an active subscription shows it in upcoming charges."""
    response = await client.get(P, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["active_subscriptions_count"] == 1
    assert data["monthly_subscription_total"] > 0
    assert len(data["upcoming_charges"]) == 1
    assert data["upcoming_charges"][0]["name"] == "Netflix"


@pytest.mark.asyncio
async def test_get_pulse_breakdown(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """GET /pulse/breakdown returns detailed calculation."""
    response = await client.get(f"{P}/breakdown", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert "current_balance" in data
    assert "upcoming_charges_7_days" in data
    assert "upcoming_charges_30_days" in data
    assert "average_daily_spend" in data
    assert "predicted_balance_7_days" in data
    assert "predicted_balance_30_days" in data
    assert data["status"] in ("safe", "caution", "freeze")


@pytest.mark.asyncio
async def test_refresh_pulse(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """POST /pulse/refresh returns fresh pulse data."""
    response = await client.post(f"{P}/refresh", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] in ("safe", "caution", "freeze")
    assert "calculated_at" in data


@pytest.mark.asyncio
async def test_pulse_unauthenticated(client: AsyncClient) -> None:
    """GET /pulse without auth returns 403."""
    response = await client.get(P)
    assert response.status_code == 403
