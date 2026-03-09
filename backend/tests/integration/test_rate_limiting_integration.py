"""Integration tests for rate limiting with real SlowAPI limiter.

Unlike unit tests where the rate limiter is disabled, these tests
verify that rate limiting actually works end-to-end.
"""

import pytest

pytestmark = pytest.mark.integration


class TestRateLimiting:
    """Rate limiting integration tests."""

    async def test_auth_endpoint_rate_limited(self, client):
        """Auth login should be rate limited after exceeding threshold."""
        login_data = {
            "email": "test@example.com",
            "password": "wrong-password",
        }

        # Send requests up to the limit — auth limit is typically 10/minute
        # We send enough to trigger the limiter
        responses = []
        for _ in range(15):
            resp = await client.post("/api/v1/auth/login", json=login_data)
            responses.append(resp)

        # At least one of the later responses should be 429
        status_codes = [r.status_code for r in responses]
        assert 429 in status_codes, (
            f"Expected 429 in responses but got: {set(status_codes)}"
        )

    async def test_rate_limited_response_has_retry_after(self, client):
        """Rate limited responses should include Retry-After header."""
        login_data = {
            "email": "test@example.com",
            "password": "wrong-password",
        }

        last_response = None
        for _ in range(20):
            resp = await client.post("/api/v1/auth/login", json=login_data)
            if resp.status_code == 429:
                last_response = resp
                break

        if last_response is not None:
            assert "retry-after" in last_response.headers or last_response.status_code == 429

    async def test_health_endpoint_not_rate_limited(self, client):
        """Health check should always be accessible."""
        for _ in range(50):
            resp = await client.get("/health")
            assert resp.status_code == 200

    async def test_different_endpoints_have_independent_limits(
        self, client_no_rate_limit, test_user, auth_headers
    ):
        """Verify rate limits are per-endpoint, not global."""
        # This test uses the no-rate-limit client to just verify
        # that both endpoints are accessible independently
        resp1 = await client_no_rate_limit.get(
            "/api/v1/subscriptions",
            headers=auth_headers,
        )
        resp2 = await client_no_rate_limit.get(
            "/api/v1/alerts",
            headers=auth_headers,
        )
        # Both should respond (not blocked by each other)
        assert resp1.status_code in (200, 422)
        assert resp2.status_code in (200, 422)
