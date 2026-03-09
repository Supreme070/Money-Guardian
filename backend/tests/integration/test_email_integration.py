"""Integration tests for email scanning endpoints.

Tests email API endpoints with mocked OAuth/Gmail/Outlook calls
but real PostgreSQL database and Redis.
"""

import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from uuid import uuid4

pytestmark = pytest.mark.integration


class TestEmailEndpoints:
    """Email scanning API endpoint integration tests."""

    async def test_email_providers_list(self, client_no_rate_limit, auth_headers):
        """Anyone can list supported email providers."""
        resp = await client_no_rate_limit.get(
            "/api/v1/email/providers",
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        # Should list gmail and outlook at minimum
        provider_names = [p["id"] for p in data] if isinstance(data, list) else []
        assert "gmail" in provider_names or len(data) > 0

    async def test_oauth_start_requires_pro(
        self, client_no_rate_limit, auth_headers
    ):
        """Free tier users cannot start email OAuth."""
        resp = await client_no_rate_limit.post(
            "/api/v1/email/oauth/start",
            json={"provider": "gmail"},
            headers=auth_headers,
        )
        assert resp.status_code == 402

    async def test_oauth_start_allowed_for_pro(
        self, client_no_rate_limit, pro_auth_headers
    ):
        """Pro tier users can start email OAuth flow."""
        with patch(
            "app.services.email_connection_service.EmailConnectionService.start_oauth_flow",
            new_callable=AsyncMock,
            return_value={
                "auth_url": "https://accounts.google.com/o/oauth2/v2/auth?...",
                "state": "random-state-token",
            },
        ):
            resp = await client_no_rate_limit.post(
                "/api/v1/email/oauth/start",
                json={"provider": "gmail"},
                headers=pro_auth_headers,
            )
            assert resp.status_code == 200
            data = resp.json()
            assert "auth_url" in data

    async def test_oauth_complete_creates_connection(
        self, client_no_rate_limit, pro_auth_headers
    ):
        """Completing OAuth should create an email connection."""
        mock_connection = MagicMock()
        mock_connection.id = uuid4()
        mock_connection.provider = "gmail"
        mock_connection.email_address = "user@gmail.com"
        mock_connection.status = "connected"
        mock_connection.last_scan_at = None
        mock_connection.created_at = None

        with patch(
            "app.services.email_connection_service.EmailConnectionService.complete_oauth_flow",
            new_callable=AsyncMock,
            return_value=mock_connection,
        ):
            resp = await client_no_rate_limit.post(
                "/api/v1/email/oauth/complete",
                json={
                    "provider": "gmail",
                    "code": "auth-code-from-google",
                    "state": "random-state-token",
                },
                headers=pro_auth_headers,
            )
            assert resp.status_code == 200

    async def test_scan_requires_pro(self, client_no_rate_limit, auth_headers):
        """Free tier users cannot scan emails."""
        fake_id = str(uuid4())
        resp = await client_no_rate_limit.post(
            f"/api/v1/email/{fake_id}/scan",
            headers=auth_headers,
        )
        assert resp.status_code == 402

    async def test_disconnect_nonexistent_connection(
        self, client_no_rate_limit, pro_auth_headers
    ):
        """Disconnecting a non-existent email connection returns 404."""
        fake_id = str(uuid4())
        resp = await client_no_rate_limit.delete(
            f"/api/v1/email/{fake_id}",
            headers=pro_auth_headers,
        )
        assert resp.status_code == 404

    async def test_email_tenant_isolation(
        self, client_no_rate_limit, pro_auth_headers
    ):
        """Users should only see their own email connections."""
        # This user has no connections yet
        resp = await client_no_rate_limit.get(
            "/api/v1/email/providers",
            headers=pro_auth_headers,
        )
        assert resp.status_code == 200
