"""Tests for user endpoints (profile, change password, account deletion)."""

import pytest
from httpx import AsyncClient

from app.models.user import User

# API prefix
P = "/api/v1/users"


@pytest.mark.asyncio
async def test_get_profile(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """GET /users/me returns the authenticated user's profile."""
    response = await client.get(f"{P}/me", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["email"] == "test@example.com"
    assert data["full_name"] == "Test User"


@pytest.mark.asyncio
async def test_get_profile_unauthenticated(client: AsyncClient) -> None:
    """GET /users/me without token returns 403."""
    response = await client.get(f"{P}/me")
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_update_profile(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """PATCH /users/me updates user profile fields."""
    response = await client.patch(
        f"{P}/me",
        headers=auth_headers,
        json={"full_name": "Updated Name"},
    )
    assert response.status_code == 200
    assert response.json()["full_name"] == "Updated Name"


@pytest.mark.asyncio
async def test_change_password_success(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """PUT /users/me/password changes the password."""
    response = await client.put(
        f"{P}/me/password",
        headers=auth_headers,
        json={
            "current_password": "TestPass123",
            "new_password": "NewSecure1",
        },
    )
    assert response.status_code == 200
    assert response.json()["message"] == "Password changed successfully"

    # Verify new password works for login
    login_resp = await client.post(
        "/api/v1/auth/login",
        json={
            "email": "test@example.com",
            "password": "NewSecure1",
        },
    )
    assert login_resp.status_code == 200


@pytest.mark.asyncio
async def test_change_password_wrong_current(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """PUT /users/me/password with wrong current password returns 400."""
    response = await client.put(
        f"{P}/me/password",
        headers=auth_headers,
        json={
            "current_password": "WrongCurrent1",
            "new_password": "NewSecure1",
        },
    )
    assert response.status_code == 400
    assert "incorrect" in response.json()["detail"].lower()


@pytest.mark.asyncio
async def test_change_password_same_as_current(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """PUT /users/me/password rejects same password."""
    response = await client.put(
        f"{P}/me/password",
        headers=auth_headers,
        json={
            "current_password": "TestPass123",
            "new_password": "TestPass123",
        },
    )
    assert response.status_code == 400
    assert "different" in response.json()["detail"].lower()


@pytest.mark.asyncio
async def test_change_password_weak_new(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """PUT /users/me/password rejects weak new password."""
    response = await client.put(
        f"{P}/me/password",
        headers=auth_headers,
        json={
            "current_password": "TestPass123",
            "new_password": "weak",
        },
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_delete_account(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """DELETE /users/me deactivates the user and scrubs PII."""
    response = await client.delete(f"{P}/me", headers=auth_headers)
    assert response.status_code == 200
    assert "deleted" in response.json()["message"].lower()


@pytest.mark.asyncio
async def test_register_fcm_token(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """POST /users/me/fcm-token registers a push token."""
    response = await client.post(
        f"{P}/me/fcm-token",
        headers=auth_headers,
        json={"token": "fake-fcm-token-abc123", "device_type": "ios"},
    )
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_unregister_fcm_token(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """DELETE /users/me/fcm-token clears the push token."""
    response = await client.delete(
        f"{P}/me/fcm-token",
        headers=auth_headers,
    )
    assert response.status_code == 200
