"""Tests for admin API endpoints.

All admin endpoints require the X-Admin-Key header.
"""

from unittest.mock import patch

import pytest
from httpx import AsyncClient

from app.models.alert import Alert
from app.models.subscription import Subscription
from app.models.tenant import Tenant
from app.models.user import User

P = "/api/v1/admin"
ADMIN_KEY = "test-admin-key-12345"
ADMIN_HEADERS = {"X-Admin-Key": ADMIN_KEY}


# ── Helper: patch admin key for all tests ────────────────────────────────


@pytest.fixture(autouse=True)
def _enable_admin_key():
    """Patch admin_api_key so admin endpoints work in tests."""
    with patch("app.api.v1.endpoints.admin.settings") as mock_settings:
        mock_settings.admin_api_key = ADMIN_KEY
        yield


# ── Auth ─────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_admin_requires_key(client: AsyncClient) -> None:
    """Requests without X-Admin-Key are rejected."""
    response = await client.get(f"{P}/stats")
    assert response.status_code in (403, 422)


@pytest.mark.asyncio
async def test_admin_rejects_wrong_key(client: AsyncClient) -> None:
    """Requests with wrong key are rejected."""
    response = await client.get(
        f"{P}/stats", headers={"X-Admin-Key": "wrong-key"}
    )
    assert response.status_code == 403


# ── Legacy endpoints ────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_admin_stats(
    client: AsyncClient, test_user: User, test_subscription: Subscription
) -> None:
    """GET /admin/stats returns system-wide statistics."""
    response = await client.get(f"{P}/stats", headers=ADMIN_HEADERS)
    assert response.status_code == 200
    data = response.json()
    assert data["total_users"] >= 1
    assert data["total_subscriptions"] >= 1
    assert "tier_breakdown" in data


@pytest.mark.asyncio
async def test_admin_lookup_user(
    client: AsyncClient, test_user: User
) -> None:
    """GET /admin/users/lookup?email=... returns user info."""
    response = await client.get(
        f"{P}/users/lookup",
        params={"email": test_user.email},
        headers=ADMIN_HEADERS,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["email"] == test_user.email


@pytest.mark.asyncio
async def test_admin_lookup_user_not_found(client: AsyncClient) -> None:
    """GET /admin/users/lookup with unknown email returns 404."""
    response = await client.get(
        f"{P}/users/lookup",
        params={"email": "nonexistent@example.com"},
        headers=ADMIN_HEADERS,
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_admin_override_tier(
    client: AsyncClient, test_tenant: Tenant
) -> None:
    """POST /admin/tenants/{id}/tier changes tenant tier."""
    response = await client.post(
        f"{P}/tenants/{test_tenant.id}/tier",
        json={"tier": "pro", "reason": "Testing tier override"},
        headers=ADMIN_HEADERS,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["new_tier"] == "pro"
    assert data["previous_tier"] == "free"


@pytest.mark.asyncio
async def test_admin_connection_health(client: AsyncClient) -> None:
    """GET /admin/connections/health returns connection health."""
    response = await client.get(
        f"{P}/connections/health", headers=ADMIN_HEADERS
    )
    assert response.status_code == 200
    data = response.json()
    assert "total_connections" in data
    assert "connected" in data


# ── New: User Management ────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_admin_list_users(
    client: AsyncClient, test_user: User
) -> None:
    """GET /admin/users returns paginated user list."""
    response = await client.get(f"{P}/users", headers=ADMIN_HEADERS)
    assert response.status_code == 200
    data = response.json()
    assert "users" in data
    assert "pagination" in data
    assert data["pagination"]["total_count"] >= 1
    assert len(data["users"]) >= 1
    assert data["users"][0]["email"] == test_user.email


@pytest.mark.asyncio
async def test_admin_list_users_search(
    client: AsyncClient, test_user: User
) -> None:
    """GET /admin/users?search= filters by email/name."""
    response = await client.get(
        f"{P}/users",
        params={"search": "test@"},
        headers=ADMIN_HEADERS,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["pagination"]["total_count"] >= 1


@pytest.mark.asyncio
async def test_admin_list_users_no_match(client: AsyncClient, test_user: User) -> None:
    """GET /admin/users?search= with no match returns empty list."""
    response = await client.get(
        f"{P}/users",
        params={"search": "zzz_nonexistent_zzz"},
        headers=ADMIN_HEADERS,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["pagination"]["total_count"] == 0
    assert len(data["users"]) == 0


@pytest.mark.asyncio
async def test_admin_get_user_detail(
    client: AsyncClient, test_user: User
) -> None:
    """GET /admin/users/{id} returns full user detail."""
    response = await client.get(
        f"{P}/users/{test_user.id}", headers=ADMIN_HEADERS
    )
    assert response.status_code == 200
    data = response.json()
    assert data["email"] == test_user.email
    assert "subscription_count" in data
    assert "bank_connection_count" in data
    assert "alert_count" in data


@pytest.mark.asyncio
async def test_admin_get_user_not_found(client: AsyncClient) -> None:
    """GET /admin/users/{id} with bad UUID returns 404."""
    from uuid import uuid4

    response = await client.get(
        f"{P}/users/{uuid4()}", headers=ADMIN_HEADERS
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_admin_update_user_status(
    client: AsyncClient, test_user: User
) -> None:
    """PUT /admin/users/{id}/status deactivates/activates a user."""
    # Deactivate
    response = await client.put(
        f"{P}/users/{test_user.id}/status",
        json={"is_active": False, "reason": "Test deactivation"},
        headers=ADMIN_HEADERS,
    )
    assert response.status_code == 200
    assert response.json()["is_active"] is False

    # Reactivate
    response = await client.put(
        f"{P}/users/{test_user.id}/status",
        json={"is_active": True, "reason": "Test reactivation"},
        headers=ADMIN_HEADERS,
    )
    assert response.status_code == 200
    assert response.json()["is_active"] is True


@pytest.mark.asyncio
async def test_admin_get_user_subscriptions(
    client: AsyncClient, test_user: User, test_subscription: Subscription
) -> None:
    """GET /admin/users/{id}/subscriptions returns user's subscriptions."""
    response = await client.get(
        f"{P}/users/{test_user.id}/subscriptions", headers=ADMIN_HEADERS
    )
    assert response.status_code == 200
    data = response.json()
    assert len(data) >= 1
    assert data[0]["name"] == "Netflix"


@pytest.mark.asyncio
async def test_admin_get_user_alerts(
    client: AsyncClient, test_user: User, test_alert: Alert
) -> None:
    """GET /admin/users/{id}/alerts returns user's alerts."""
    response = await client.get(
        f"{P}/users/{test_user.id}/alerts", headers=ADMIN_HEADERS
    )
    assert response.status_code == 200
    data = response.json()
    assert len(data) >= 1
    assert data[0]["title"] == "Netflix renewal"


@pytest.mark.asyncio
async def test_admin_get_user_connections(
    client: AsyncClient, test_user: User
) -> None:
    """GET /admin/users/{id}/connections returns bank + email connections."""
    response = await client.get(
        f"{P}/users/{test_user.id}/connections", headers=ADMIN_HEADERS
    )
    assert response.status_code == 200
    data = response.json()
    assert "bank_connections" in data
    assert "email_connections" in data


# ── New: Tenant Management ──────────────────────────────────────────────


@pytest.mark.asyncio
async def test_admin_list_tenants(
    client: AsyncClient, test_tenant: Tenant
) -> None:
    """GET /admin/tenants returns paginated tenant list."""
    response = await client.get(f"{P}/tenants", headers=ADMIN_HEADERS)
    assert response.status_code == 200
    data = response.json()
    assert "tenants" in data
    assert "pagination" in data
    assert data["pagination"]["total_count"] >= 1


@pytest.mark.asyncio
async def test_admin_get_tenant_detail(
    client: AsyncClient, test_tenant: Tenant
) -> None:
    """GET /admin/tenants/{id} returns full tenant detail."""
    response = await client.get(
        f"{P}/tenants/{test_tenant.id}", headers=ADMIN_HEADERS
    )
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Test Tenant"
    assert "user_count" in data
    assert "subscription_count" in data


@pytest.mark.asyncio
async def test_admin_update_tenant_status(
    client: AsyncClient, test_tenant: Tenant
) -> None:
    """PUT /admin/tenants/{id}/status changes tenant status."""
    response = await client.put(
        f"{P}/tenants/{test_tenant.id}/status",
        json={"status": "suspended", "reason": "Test suspension"},
        headers=ADMIN_HEADERS,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["new_status"] == "suspended"
    assert data["previous_status"] == "active"


# ── New: Analytics ──────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_admin_analytics_overview(
    client: AsyncClient, test_user: User, test_subscription: Subscription
) -> None:
    """GET /admin/analytics/overview returns platform metrics."""
    response = await client.get(
        f"{P}/analytics/overview", headers=ADMIN_HEADERS
    )
    assert response.status_code == 200
    data = response.json()
    assert data["total_users"] >= 1
    assert data["total_subscriptions"] >= 1
    assert "conversion_rate" in data
    assert "monthly_tracked_value" in data


@pytest.mark.asyncio
async def test_admin_analytics_signups(
    client: AsyncClient, test_user: User
) -> None:
    """GET /admin/analytics/signups returns signup trends."""
    response = await client.get(
        f"{P}/analytics/signups",
        params={"period": "daily", "days": 30},
        headers=ADMIN_HEADERS,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["period"] == "daily"
    assert "data_points" in data
    assert data["total"] >= 1


@pytest.mark.asyncio
async def test_admin_analytics_subscriptions(
    client: AsyncClient, test_subscription: Subscription
) -> None:
    """GET /admin/analytics/subscriptions returns subscription analytics."""
    response = await client.get(
        f"{P}/analytics/subscriptions", headers=ADMIN_HEADERS
    )
    assert response.status_code == 200
    data = response.json()
    assert data["total_tracked"] >= 1
    assert "top_merchants" in data
    assert "flag_distribution" in data
    assert "source_distribution" in data


@pytest.mark.asyncio
async def test_admin_analytics_connections(client: AsyncClient) -> None:
    """GET /admin/analytics/connections returns connection analytics."""
    response = await client.get(
        f"{P}/analytics/connections", headers=ADMIN_HEADERS
    )
    assert response.status_code == 200
    data = response.json()
    assert "bank_providers" in data
    assert "email_providers" in data
    assert "bank_success_rate" in data


@pytest.mark.asyncio
async def test_admin_analytics_revenue(
    client: AsyncClient, test_user: User
) -> None:
    """GET /admin/analytics/revenue returns revenue analytics."""
    response = await client.get(
        f"{P}/analytics/revenue", headers=ADMIN_HEADERS
    )
    assert response.status_code == 200
    data = response.json()
    assert "tier_breakdown" in data
    assert "total_paid_users" in data
    assert "churn_count_30d" in data


# ── New: Monitoring ─────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_admin_monitoring_health(client: AsyncClient) -> None:
    """GET /admin/monitoring/health returns system health."""
    response = await client.get(
        f"{P}/monitoring/health", headers=ADMIN_HEADERS
    )
    assert response.status_code == 200
    data = response.json()
    assert "services" in data
    assert "overall_status" in data
    # DB should be healthy in tests (SQLite in-memory)
    db_service = next(
        (s for s in data["services"] if s["name"] == "PostgreSQL"), None
    )
    assert db_service is not None
    assert db_service["status"] == "healthy"


@pytest.mark.asyncio
async def test_admin_monitoring_errors(client: AsyncClient) -> None:
    """GET /admin/monitoring/errors returns error log."""
    response = await client.get(
        f"{P}/monitoring/errors", headers=ADMIN_HEADERS
    )
    assert response.status_code == 200
    data = response.json()
    assert "errors" in data
    assert "pagination" in data


@pytest.mark.asyncio
async def test_admin_monitoring_celery(client: AsyncClient) -> None:
    """GET /admin/monitoring/celery returns task info."""
    response = await client.get(
        f"{P}/monitoring/celery", headers=ADMIN_HEADERS
    )
    assert response.status_code == 200
    data = response.json()
    assert "scheduled_tasks" in data
    assert len(data["scheduled_tasks"]) == 5
    task_names = [t["name"] for t in data["scheduled_tasks"]]
    assert "sync_all_bank_transactions" in task_names
    assert "check_overdraft_risk" in task_names
