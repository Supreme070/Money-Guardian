"""Tests for authentication endpoints."""

import pytest
from httpx import AsyncClient

from app.models.user import User

# API prefix
P = "/api/v1/auth"


@pytest.mark.asyncio
async def test_register_success(client: AsyncClient) -> None:
    """Register creates a user and returns tokens."""
    response = await client.post(
        f"{P}/register",
        json={
            "email": "new@example.com",
            "password": "StrongPass1",
            "full_name": "New User",
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"
    assert data["expires_in"] > 0


@pytest.mark.asyncio
async def test_register_duplicate_email(client: AsyncClient) -> None:
    """Registering with an existing email returns 409."""
    payload = {
        "email": "dup@example.com",
        "password": "StrongPass1",
        "full_name": "First",
    }
    resp1 = await client.post(f"{P}/register", json=payload)
    assert resp1.status_code == 201

    resp2 = await client.post(f"{P}/register", json=payload)
    assert resp2.status_code == 409


@pytest.mark.asyncio
async def test_register_weak_password(client: AsyncClient) -> None:
    """Registering with a weak password returns 422."""
    response = await client.post(
        f"{P}/register",
        json={
            "email": "weak@example.com",
            "password": "nodigits",
        },
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_login_success(client: AsyncClient, test_user: User) -> None:
    """Login with valid credentials returns tokens."""
    response = await client.post(
        f"{P}/login",
        json={
            "email": "test@example.com",
            "password": "TestPass123",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"


@pytest.mark.asyncio
async def test_login_wrong_password(client: AsyncClient, test_user: User) -> None:
    """Login with wrong password returns 401."""
    response = await client.post(
        f"{P}/login",
        json={
            "email": "test@example.com",
            "password": "WrongPass999",
        },
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_login_nonexistent_email(client: AsyncClient) -> None:
    """Login with unknown email returns 401."""
    response = await client.post(
        f"{P}/login",
        json={
            "email": "nobody@example.com",
            "password": "SomePass1",
        },
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_token_refresh(client: AsyncClient, test_user: User) -> None:
    """Refresh endpoint returns new token pair."""
    login_resp = await client.post(
        f"{P}/login",
        json={
            "email": "test@example.com",
            "password": "TestPass123",
        },
    )
    refresh_token = login_resp.json()["refresh_token"]

    refresh_resp = await client.post(
        f"{P}/refresh",
        json={"refresh_token": refresh_token},
    )
    assert refresh_resp.status_code == 200
    data = refresh_resp.json()
    assert "access_token" in data
    assert "refresh_token" in data


@pytest.mark.asyncio
async def test_refresh_with_invalid_token(client: AsyncClient) -> None:
    """Refresh with garbage token returns 401."""
    response = await client.post(
        f"{P}/refresh",
        json={"refresh_token": "not.a.valid.jwt"},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_logout(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    """Logout returns success message."""
    response = await client.post(f"{P}/logout", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["message"] == "Successfully logged out"
