"""Tests for rate limiting on auth endpoints."""

import pytest
import pytest_asyncio
from httpx import AsyncClient


@pytest.mark.asyncio
class TestRateLimiting:
    """Verify that rate-limited endpoints enforce limits.

    Note: In tests, the rate limiter is mocked to avoid Redis dependency.
    These tests verify the endpoint responses and status codes,
    not the actual rate limiting (which is an integration concern).
    """

    async def test_login_returns_422_with_invalid_body(self, client: AsyncClient) -> None:
        """Auth endpoints validate input before rate limiting kicks in."""
        response = await client.post("/api/v1/auth/login", json={})
        assert response.status_code == 422

    async def test_register_returns_422_with_invalid_body(self, client: AsyncClient) -> None:
        response = await client.post("/api/v1/auth/register", json={})
        assert response.status_code == 422

    async def test_login_with_wrong_credentials(self, client: AsyncClient) -> None:
        response = await client.post(
            "/api/v1/auth/login",
            json={"email": "wrong@example.com", "password": "WrongPass123"},
        )
        assert response.status_code == 401

    async def test_register_weak_password_rejected(self, client: AsyncClient) -> None:
        """Password policy is enforced even under rate limits."""
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": "new@example.com",
                "password": "weak",
                "full_name": "Test User",
            },
        )
        assert response.status_code in (400, 422)

    async def test_health_endpoint_not_rate_limited(self, client: AsyncClient) -> None:
        """Health endpoints should always respond."""
        for _ in range(10):
            response = await client.get("/health")
            assert response.status_code == 200
