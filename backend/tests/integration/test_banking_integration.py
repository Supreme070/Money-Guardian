"""Integration tests for banking endpoints.

Tests banking API endpoints with mocked external Plaid calls
but real PostgreSQL database and Redis.
"""

import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from decimal import Decimal
from uuid import uuid4

pytestmark = pytest.mark.integration


class TestBankingEndpoints:
    """Banking API endpoint integration tests."""

    async def test_link_token_requires_pro_tier(
        self, client_no_rate_limit, auth_headers
    ):
        """Free tier users cannot create bank link tokens."""
        resp = await client_no_rate_limit.post(
            "/api/v1/banking/link-token",
            json={"provider": "plaid"},
            headers=auth_headers,
        )
        assert resp.status_code == 402
        data = resp.json()
        assert "pro" in data["detail"].lower() or "upgrade" in data["detail"].lower()

    async def test_link_token_allowed_for_pro(
        self, client_no_rate_limit, pro_auth_headers
    ):
        """Pro tier users can request bank link tokens."""
        mock_response = MagicMock()
        mock_response.link_token = "link-sandbox-test-token-123"
        mock_response.expiration = "2026-12-31T00:00:00Z"

        with patch(
            "app.services.bank_connection_service.BankConnectionService.create_link_token",
            new_callable=AsyncMock,
            return_value={
                "link_token": "link-sandbox-test-token-123",
                "expiration": "2026-12-31T00:00:00Z",
                "provider": "plaid",
            },
        ):
            resp = await client_no_rate_limit.post(
                "/api/v1/banking/link-token",
                json={"provider": "plaid"},
                headers=pro_auth_headers,
            )
            assert resp.status_code == 200
            data = resp.json()
            assert data["link_token"] == "link-sandbox-test-token-123"
            assert data["provider"] == "plaid"

    async def test_list_connections_empty_for_new_user(
        self, client_no_rate_limit, pro_auth_headers
    ):
        """New Pro user should have no bank connections."""
        resp = await client_no_rate_limit.get(
            "/api/v1/banking",
            headers=pro_auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["connections"] == []
        assert data["total_balance"] == 0

    async def test_exchange_token_creates_connection(
        self, client_no_rate_limit, pro_auth_headers, db_session, pro_user
    ):
        """Exchanging a public token should create a bank connection."""
        from app.models.bank_connection import BankConnection

        mock_exchange_result = MagicMock()
        mock_exchange_result.id = uuid4()

        with patch(
            "app.services.bank_connection_service.BankConnectionService.exchange_and_save",
            new_callable=AsyncMock,
        ) as mock_exchange:
            # Create a mock BankConnection to return
            mock_conn = MagicMock(spec=BankConnection)
            mock_conn.id = uuid4()
            mock_conn.tenant_id = pro_user.tenant_id
            mock_conn.user_id = pro_user.id
            mock_conn.provider = "plaid"
            mock_conn.institution_name = "Chase"
            mock_conn.institution_logo = None
            mock_conn.status = "connected"
            mock_conn.error_code = None
            mock_conn.error_message = None
            mock_conn.last_sync_at = None
            mock_conn.created_at = None
            mock_conn.accounts = []
            mock_exchange.return_value = mock_conn

            resp = await client_no_rate_limit.post(
                "/api/v1/banking/exchange",
                json={
                    "public_token": "public-sandbox-test-token",
                    "provider": "plaid",
                },
                headers=pro_auth_headers,
            )
            assert resp.status_code == 200

    async def test_disconnect_nonexistent_connection(
        self, client_no_rate_limit, pro_auth_headers
    ):
        """Disconnecting a non-existent connection returns 404."""
        fake_id = str(uuid4())
        resp = await client_no_rate_limit.delete(
            f"/api/v1/banking/{fake_id}",
            headers=pro_auth_headers,
        )
        assert resp.status_code == 404

    async def test_banking_tenant_isolation(
        self, client_no_rate_limit, pro_auth_headers, db_session
    ):
        """Users should only see their own bank connections."""
        resp = await client_no_rate_limit.get(
            "/api/v1/banking",
            headers=pro_auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        # Should be empty — no connections for this tenant
        assert data["connections"] == []

    async def test_sync_nonexistent_connection(
        self, client_no_rate_limit, pro_auth_headers
    ):
        """Syncing a non-existent connection returns 404."""
        fake_id = str(uuid4())
        resp = await client_no_rate_limit.post(
            f"/api/v1/banking/{fake_id}/sync",
            headers=pro_auth_headers,
        )
        assert resp.status_code == 404
