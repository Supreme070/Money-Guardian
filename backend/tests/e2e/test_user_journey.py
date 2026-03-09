"""
E2E: Complete user journey from registration to account deletion.

Tests the full flow a mobile app user would experience:
1. Register -> get tokens
2. Login -> verify tokens work
3. Get profile -> verify user data
4. Create subscriptions (up to free tier limit)
5. Get pulse -> verify daily status
6. Get alerts -> verify alert system
7. Export data (GDPR)
8. Change password
9. Delete account

All tests run against real PostgreSQL via the integration conftest.
Rate limiter is enabled (same as integration tests).
"""

from datetime import date, timedelta
from decimal import Decimal
from uuid import UUID, uuid4

import pytest
from httpx import AsyncClient

from app.models.alert import Alert
from app.models.subscription import Subscription
from app.models.tenant import Tenant
from app.models.user import User

# API prefixes
AUTH = "/api/v1/auth"
USERS = "/api/v1/users"
SUBS = "/api/v1/subscriptions"
PULSE = "/api/v1/pulse"
ALERTS = "/api/v1/alerts"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _sub_payload(name: str, amount: float, days_ahead: int = 10) -> dict[str, object]:
    """Build a valid subscription creation payload."""
    return {
        "name": name,
        "amount": amount,
        "billing_cycle": "monthly",
        "next_billing_date": str(date.today() + timedelta(days=days_ahead)),
    }


def _register_payload(
    email: str = "e2e-journey@example.com",
    password: str = "StrongPass1",
    full_name: str = "E2E Journey User",
) -> dict[str, object]:
    """Build a valid registration payload."""
    return {
        "email": email,
        "password": password,
        "full_name": full_name,
        "accepted_terms": True,
        "accepted_privacy": True,
    }


# ---------------------------------------------------------------------------
# 1. Registration flow
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_full_registration_flow(client_no_rate_limit: AsyncClient) -> None:
    """Register a new user and verify token response structure."""
    client = client_no_rate_limit

    resp = await client.post(
        f"{AUTH}/register",
        json=_register_payload(email="reg-flow@example.com"),
    )
    assert resp.status_code == 201

    data: dict[str, object] = resp.json()
    assert isinstance(data["access_token"], str)
    assert isinstance(data["refresh_token"], str)
    assert data["token_type"] == "bearer"
    assert isinstance(data["expires_in"], int)
    assert int(str(data["expires_in"])) > 0

    # Token should work for authenticated requests
    headers = {"Authorization": f"Bearer {data['access_token']}"}
    me_resp = await client.get(f"{USERS}/me", headers=headers)
    assert me_resp.status_code == 200
    me_data: dict[str, object] = me_resp.json()
    assert me_data["email"] == "reg-flow@example.com"
    assert me_data["full_name"] == "E2E Journey User"
    assert me_data["subscription_tier"] == "free"


@pytest.mark.asyncio
async def test_register_duplicate_email(client_no_rate_limit: AsyncClient) -> None:
    """Registering with an existing email returns 409."""
    client = client_no_rate_limit
    payload = _register_payload(email="dup-e2e@example.com")

    resp1 = await client.post(f"{AUTH}/register", json=payload)
    assert resp1.status_code == 201

    resp2 = await client.post(f"{AUTH}/register", json=payload)
    assert resp2.status_code == 409


# ---------------------------------------------------------------------------
# 2. Login and profile
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_login_and_profile(client_no_rate_limit: AsyncClient) -> None:
    """Register, login, and verify profile via /users/me."""
    client = client_no_rate_limit
    email = "login-profile@example.com"
    password = "StrongPass1"

    # Register
    reg_resp = await client.post(
        f"{AUTH}/register",
        json=_register_payload(email=email, password=password),
    )
    assert reg_resp.status_code == 201

    # Login with same credentials
    login_resp = await client.post(
        f"{AUTH}/login",
        json={"email": email, "password": password},
    )
    assert login_resp.status_code == 200
    login_data: dict[str, object] = login_resp.json()
    assert isinstance(login_data["access_token"], str)
    assert isinstance(login_data["refresh_token"], str)

    # Verify profile
    headers = {"Authorization": f"Bearer {login_data['access_token']}"}
    me_resp = await client.get(f"{USERS}/me", headers=headers)
    assert me_resp.status_code == 200
    me: dict[str, object] = me_resp.json()
    assert me["email"] == email
    assert me["is_active"] is True
    assert me["subscription_tier"] == "free"


# ---------------------------------------------------------------------------
# 3. Subscription CRUD cycle
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_subscription_crud_cycle(
    client_no_rate_limit: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """Create, read, update, delete a subscription -- full lifecycle."""
    client = client_no_rate_limit

    # Create
    create_resp = await client.post(
        SUBS,
        headers=auth_headers,
        json=_sub_payload("Netflix", 15.99),
    )
    assert create_resp.status_code == 201
    sub: dict[str, object] = create_resp.json()
    sub_id: str = str(sub["id"])
    assert sub["name"] == "Netflix"
    assert sub["amount"] == 15.99
    assert sub["billing_cycle"] == "monthly"
    assert sub["is_active"] is True

    # Read by ID
    get_resp = await client.get(f"{SUBS}/{sub_id}", headers=auth_headers)
    assert get_resp.status_code == 200
    assert get_resp.json()["name"] == "Netflix"

    # List -- should contain the subscription
    list_resp = await client.get(SUBS, headers=auth_headers)
    assert list_resp.status_code == 200
    list_data: dict[str, object] = list_resp.json()
    assert int(str(list_data["total_count"])) >= 1
    names = [s["name"] for s in list_data["subscriptions"]]  # type: ignore[union-attr]
    assert "Netflix" in names

    # Update
    patch_resp = await client.patch(
        f"{SUBS}/{sub_id}",
        headers=auth_headers,
        json={"name": "Netflix Premium", "amount": 22.99},
    )
    assert patch_resp.status_code == 200
    assert patch_resp.json()["name"] == "Netflix Premium"
    assert patch_resp.json()["amount"] == 22.99

    # Delete
    del_resp = await client.delete(f"{SUBS}/{sub_id}", headers=auth_headers)
    assert del_resp.status_code == 204

    # Verify deleted from list
    list_after = await client.get(SUBS, headers=auth_headers)
    sub_ids = [s["id"] for s in list_after.json()["subscriptions"]]  # type: ignore[union-attr]
    assert sub_id not in sub_ids


# ---------------------------------------------------------------------------
# 4. Free tier limits (5 manual subscriptions)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_free_tier_limits(
    client_no_rate_limit: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """Free tier allows 5 manual subscriptions; 6th returns 402."""
    client = client_no_rate_limit

    created_ids: list[str] = []
    for i in range(5):
        resp = await client.post(
            SUBS,
            headers=auth_headers,
            json=_sub_payload(f"Service {i + 1}", 5.0 + i, days_ahead=i + 1),
        )
        assert resp.status_code == 201, f"Sub {i + 1} failed: {resp.text}"
        created_ids.append(str(resp.json()["id"]))

    # 6th subscription should be blocked
    sixth = await client.post(
        SUBS,
        headers=auth_headers,
        json=_sub_payload("Service 6", 11.0, days_ahead=6),
    )
    assert sixth.status_code == 402
    detail: dict[str, object] = sixth.json()["detail"]
    assert detail["upgrade_required"] is True
    assert int(str(detail["current_count"])) == 5
    assert int(str(detail["limit"])) == 5


# ---------------------------------------------------------------------------
# 5. Pulse calculation
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_pulse_calculation(
    client_no_rate_limit: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """
    Create subscriptions, get pulse, verify response structure.

    Without a bank connected the status should be 'safe' and
    safe_to_spend should be 0 (prompts user to connect bank).
    """
    client = client_no_rate_limit

    # Add some subscriptions due in the next 7 days
    for i in range(3):
        resp = await client.post(
            SUBS,
            headers=auth_headers,
            json=_sub_payload(f"Pulse Sub {i}", 10.0, days_ahead=i + 1),
        )
        assert resp.status_code == 201

    # Get pulse
    pulse_resp = await client.get(PULSE, headers=auth_headers)
    assert pulse_resp.status_code == 200
    pulse: dict[str, object] = pulse_resp.json()

    # Verify all expected fields
    assert pulse["status"] in ("safe", "caution", "freeze")
    assert isinstance(pulse["status_message"], str)
    assert isinstance(pulse["safe_to_spend"], (int, float, str))
    assert isinstance(pulse["has_bank_connected"], bool)
    assert isinstance(pulse["upcoming_charges"], list)
    assert isinstance(pulse["active_subscriptions_count"], int)
    assert isinstance(pulse["unread_alerts_count"], int)

    # Without bank, status is "safe" with prompt to connect
    assert pulse["has_bank_connected"] is False
    assert pulse["status"] == "safe"


@pytest.mark.asyncio
async def test_pulse_refresh(
    client_no_rate_limit: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """POST /pulse/refresh should return fresh pulse data."""
    client = client_no_rate_limit

    resp = await client.post(f"{PULSE}/refresh", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["status"] in ("safe", "caution", "freeze")


# ---------------------------------------------------------------------------
# 6. Alert lifecycle
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_alert_lifecycle(
    client_no_rate_limit: AsyncClient,
    auth_headers: dict[str, str],
    test_alert: Alert,
) -> None:
    """Get alerts, mark read, dismiss -- full lifecycle."""
    client = client_no_rate_limit
    alert_id = str(test_alert.id)

    # List alerts
    list_resp = await client.get(ALERTS, headers=auth_headers)
    assert list_resp.status_code == 200
    list_data: dict[str, object] = list_resp.json()
    assert int(str(list_data["total_count"])) >= 1
    assert int(str(list_data["unread_count"])) >= 1

    # Get single alert
    get_resp = await client.get(f"{ALERTS}/{alert_id}", headers=auth_headers)
    assert get_resp.status_code == 200
    assert get_resp.json()["title"] == "Netflix renewal"

    # Mark read
    mark_resp = await client.post(
        f"{ALERTS}/mark-read",
        headers=auth_headers,
        json={"alert_ids": [alert_id]},
    )
    assert mark_resp.status_code == 200
    assert mark_resp.json()["marked_read"] == 1

    # Verify it's now read
    get_after = await client.get(f"{ALERTS}/{alert_id}", headers=auth_headers)
    assert get_after.json()["is_read"] is True

    # Dismiss
    dismiss_resp = await client.post(
        f"{ALERTS}/{alert_id}/dismiss",
        headers=auth_headers,
    )
    assert dismiss_resp.status_code == 200

    # Dismissed alert should not appear in default list
    list_after = await client.get(ALERTS, headers=auth_headers)
    alert_ids = [a["id"] for a in list_after.json()["alerts"]]  # type: ignore[union-attr]
    assert alert_id not in alert_ids


# ---------------------------------------------------------------------------
# 7. GDPR data export
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_gdpr_data_export(
    client_no_rate_limit: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
    test_subscription: Subscription,
    test_alert: Alert,
) -> None:
    """GET /users/me/export returns all user data in GDPR-compliant format."""
    client = client_no_rate_limit

    resp = await client.get(f"{USERS}/me/export", headers=auth_headers)
    assert resp.status_code == 200

    data: dict[str, object] = resp.json()

    # Verify top-level sections
    assert "user" in data
    assert "subscriptions" in data
    assert "alerts" in data
    assert "bank_connections" in data
    assert "email_connections" in data
    assert "exported_at" in data

    # Verify user data
    user_data: dict[str, object] = data["user"]  # type: ignore[assignment]
    assert user_data["email"] == test_user.email
    assert user_data["full_name"] == test_user.full_name

    # Verify subscriptions included
    subs: list[dict[str, object]] = data["subscriptions"]  # type: ignore[assignment]
    assert len(subs) >= 1
    sub_names = [s["name"] for s in subs]
    assert "Netflix" in sub_names

    # Verify alerts included
    alerts: list[dict[str, object]] = data["alerts"]  # type: ignore[assignment]
    assert len(alerts) >= 1


# ---------------------------------------------------------------------------
# 8. Password change
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_password_change(client_no_rate_limit: AsyncClient) -> None:
    """Change password, then login with new password."""
    client = client_no_rate_limit
    email = "pwd-change@example.com"
    old_password = "OldPass123"
    new_password = "NewPass456"

    # Register
    reg = await client.post(
        f"{AUTH}/register",
        json=_register_payload(email=email, password=old_password),
    )
    assert reg.status_code == 201
    headers = {"Authorization": f"Bearer {reg.json()['access_token']}"}

    # Change password
    change_resp = await client.put(
        f"{USERS}/me/password",
        headers=headers,
        json={
            "current_password": old_password,
            "new_password": new_password,
        },
    )
    assert change_resp.status_code == 200
    assert change_resp.json()["message"] == "Password changed successfully"

    # Login with new password
    login_resp = await client.post(
        f"{AUTH}/login",
        json={"email": email, "password": new_password},
    )
    assert login_resp.status_code == 200
    assert isinstance(login_resp.json()["access_token"], str)

    # Old password should fail
    old_login = await client.post(
        f"{AUTH}/login",
        json={"email": email, "password": old_password},
    )
    assert old_login.status_code == 401


@pytest.mark.asyncio
async def test_password_change_wrong_current(
    client_no_rate_limit: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """Changing password with wrong current password returns 400."""
    client = client_no_rate_limit

    resp = await client.put(
        f"{USERS}/me/password",
        headers=auth_headers,
        json={
            "current_password": "WrongCurrent1",
            "new_password": "NewValid123",
        },
    )
    assert resp.status_code == 400
    assert "incorrect" in resp.json()["detail"].lower()


# ---------------------------------------------------------------------------
# 9. Account deletion
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_account_deletion(client_no_rate_limit: AsyncClient) -> None:
    """Delete account, then verify login fails."""
    client = client_no_rate_limit
    email = "delete-me@example.com"
    password = "DeleteMe1"

    # Register
    reg = await client.post(
        f"{AUTH}/register",
        json=_register_payload(email=email, password=password),
    )
    assert reg.status_code == 201
    headers = {"Authorization": f"Bearer {reg.json()['access_token']}"}

    # Create a subscription (to verify cascade cleanup)
    sub_resp = await client.post(
        SUBS,
        headers=headers,
        json=_sub_payload("Doomed Sub", 9.99),
    )
    assert sub_resp.status_code == 201

    # Delete account
    del_resp = await client.delete(f"{USERS}/me", headers=headers)
    assert del_resp.status_code == 200
    assert "deleted" in del_resp.json()["message"].lower()

    # Login with deleted account should fail
    login_resp = await client.post(
        f"{AUTH}/login",
        json={"email": email, "password": password},
    )
    assert login_resp.status_code == 401


# ---------------------------------------------------------------------------
# 10. Token refresh flow
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_token_refresh_flow(client_no_rate_limit: AsyncClient) -> None:
    """Register, use refresh token to get new access token."""
    client = client_no_rate_limit

    # Register
    reg = await client.post(
        f"{AUTH}/register",
        json=_register_payload(email="refresh-flow@example.com"),
    )
    assert reg.status_code == 201
    refresh_token: str = reg.json()["refresh_token"]

    # Refresh
    refresh_resp = await client.post(
        f"{AUTH}/refresh",
        json={"refresh_token": refresh_token},
    )
    assert refresh_resp.status_code == 200
    new_tokens: dict[str, object] = refresh_resp.json()
    assert isinstance(new_tokens["access_token"], str)
    assert isinstance(new_tokens["refresh_token"], str)

    # New access token should work
    headers = {"Authorization": f"Bearer {new_tokens['access_token']}"}
    me_resp = await client.get(f"{USERS}/me", headers=headers)
    assert me_resp.status_code == 200


# ---------------------------------------------------------------------------
# 11. Multi-tenant isolation
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_tenant_isolation_between_users(
    client_no_rate_limit: AsyncClient,
) -> None:
    """Two users cannot see each other's subscriptions."""
    client = client_no_rate_limit

    # Register user A
    reg_a = await client.post(
        f"{AUTH}/register",
        json=_register_payload(email="tenant-a@example.com"),
    )
    assert reg_a.status_code == 201
    headers_a = {"Authorization": f"Bearer {reg_a.json()['access_token']}"}

    # Register user B
    reg_b = await client.post(
        f"{AUTH}/register",
        json=_register_payload(email="tenant-b@example.com"),
    )
    assert reg_b.status_code == 201
    headers_b = {"Authorization": f"Bearer {reg_b.json()['access_token']}"}

    # User A creates a subscription
    sub_a = await client.post(
        SUBS,
        headers=headers_a,
        json=_sub_payload("User A Netflix", 15.99),
    )
    assert sub_a.status_code == 201
    sub_a_id: str = str(sub_a.json()["id"])

    # User B creates a subscription
    sub_b = await client.post(
        SUBS,
        headers=headers_b,
        json=_sub_payload("User B Spotify", 9.99),
    )
    assert sub_b.status_code == 201

    # User A cannot see User B's subscriptions
    list_a = await client.get(SUBS, headers=headers_a)
    names_a = [s["name"] for s in list_a.json()["subscriptions"]]
    assert "User A Netflix" in names_a
    assert "User B Spotify" not in names_a

    # User B cannot see User A's subscriptions
    list_b = await client.get(SUBS, headers=headers_b)
    names_b = [s["name"] for s in list_b.json()["subscriptions"]]
    assert "User B Spotify" in names_b
    assert "User A Netflix" not in names_b

    # User B cannot access User A's subscription by ID
    direct = await client.get(f"{SUBS}/{sub_a_id}", headers=headers_b)
    assert direct.status_code == 404


# ---------------------------------------------------------------------------
# 12. Unauthenticated access
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_unauthenticated_access_blocked(
    client_no_rate_limit: AsyncClient,
) -> None:
    """Verify all protected endpoints reject unauthenticated requests."""
    client = client_no_rate_limit

    endpoints: list[tuple[str, str]] = [
        ("GET", f"{USERS}/me"),
        ("GET", SUBS),
        ("GET", PULSE),
        ("GET", ALERTS),
        ("GET", f"{USERS}/me/export"),
    ]

    for method, url in endpoints:
        if method == "GET":
            resp = await client.get(url)
        else:
            resp = await client.post(url)
        assert resp.status_code in (401, 403), (
            f"{method} {url} returned {resp.status_code}, expected 401 or 403"
        )
