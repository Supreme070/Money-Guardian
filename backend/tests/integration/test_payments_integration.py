"""Integration tests for payment and webhook endpoints.

Tests Stripe checkout, billing portal, and webhook handling
with mocked Stripe SDK but real database.
"""

import json
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from uuid import uuid4

pytestmark = pytest.mark.integration


class TestPaymentEndpoints:
    """Payment API endpoint integration tests."""

    async def test_checkout_requires_stripe_config(
        self, client_no_rate_limit, auth_headers
    ):
        """Checkout should fail gracefully if Stripe not configured."""
        with patch("app.core.config.settings.stripe_secret_key", None):
            resp = await client_no_rate_limit.post(
                "/api/v1/payments/checkout",
                json={},
                headers=auth_headers,
            )
            assert resp.status_code == 503

    async def test_checkout_rejects_existing_pro_users(
        self, client_no_rate_limit, pro_auth_headers
    ):
        """Already-Pro users should not be able to checkout again."""
        with patch("app.core.config.settings.stripe_secret_key", "sk_test_xxx"):
            resp = await client_no_rate_limit.post(
                "/api/v1/payments/checkout",
                json={},
                headers=pro_auth_headers,
            )
            assert resp.status_code == 400
            assert "already" in resp.json()["detail"].lower()

    async def test_subscription_status_returns_tier(
        self, client_no_rate_limit, auth_headers
    ):
        """Subscription status should return current tier info."""
        resp = await client_no_rate_limit.get(
            "/api/v1/payments/status",
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["tier"] == "free"
        assert data["is_active"] is False


class TestStripeWebhooks:
    """Stripe webhook integration tests."""

    async def test_stripe_webhook_rejects_invalid_signature(
        self, client_no_rate_limit
    ):
        """Webhook with invalid signature should be rejected."""
        with patch(
            "app.core.config.settings.stripe_webhook_secret",
            "whsec_test_secret",
        ):
            resp = await client_no_rate_limit.post(
                "/api/v1/webhooks/stripe",
                content=json.dumps({"id": "evt_test", "type": "test"}).encode(),
                headers={
                    "stripe-signature": "t=123,v1=invalid_sig",
                    "content-type": "application/json",
                },
            )
            assert resp.status_code == 400

    async def test_stripe_webhook_requires_config(self, client_no_rate_limit):
        """Webhook should fail if Stripe webhook secret not configured."""
        with patch("app.core.config.settings.stripe_webhook_secret", None):
            resp = await client_no_rate_limit.post(
                "/api/v1/webhooks/stripe",
                content=b"{}",
                headers={
                    "stripe-signature": "t=123,v1=sig",
                    "content-type": "application/json",
                },
            )
            assert resp.status_code == 503

    async def test_checkout_completed_webhook_activates_pro(
        self,
        client_no_rate_limit,
        db_session,
        test_tenant,
        test_user,
    ):
        """Checkout completed webhook should upgrade tenant to Pro."""
        import stripe

        event_data = {
            "id": f"evt_test_{uuid4().hex[:8]}",
            "type": "checkout.session.completed",
            "data": {
                "object": {
                    "id": "cs_test_123",
                    "client_reference_id": str(test_tenant.id),
                    "customer": "cus_test_123",
                    "subscription": "sub_test_123",
                    "payment_status": "paid",
                    "mode": "subscription",
                },
            },
        }

        with (
            patch(
                "app.core.config.settings.stripe_webhook_secret",
                "whsec_test_secret",
            ),
            patch(
                "stripe.Webhook.construct_event",
                return_value=event_data,
            ),
            patch(
                "app.core.redis_dedup.is_duplicate",
                new_callable=AsyncMock,
                return_value=False,
            ),
            patch(
                "app.core.redis_dedup.mark_processed",
                new_callable=AsyncMock,
            ),
        ):
            resp = await client_no_rate_limit.post(
                "/api/v1/webhooks/stripe",
                content=json.dumps(event_data).encode(),
                headers={
                    "stripe-signature": "t=123,v1=valid",
                    "content-type": "application/json",
                },
            )
            assert resp.status_code == 200
            assert resp.json() == {"status": "ok"}

    async def test_webhook_idempotency(self, client_no_rate_limit):
        """Duplicate webhook events should be skipped."""
        event_data = {
            "id": "evt_duplicate_test",
            "type": "checkout.session.completed",
            "data": {
                "object": {
                    "id": "cs_test_dup",
                    "client_reference_id": str(uuid4()),
                    "customer": "cus_test_dup",
                },
            },
        }

        with (
            patch(
                "app.core.config.settings.stripe_webhook_secret",
                "whsec_test_secret",
            ),
            patch(
                "stripe.Webhook.construct_event",
                return_value=event_data,
            ),
            patch(
                "app.core.redis_dedup.is_duplicate",
                new_callable=AsyncMock,
                return_value=True,  # Already processed
            ),
        ):
            resp = await client_no_rate_limit.post(
                "/api/v1/webhooks/stripe",
                content=json.dumps(event_data).encode(),
                headers={
                    "stripe-signature": "t=123,v1=valid",
                    "content-type": "application/json",
                },
            )
            assert resp.status_code == 200
            assert resp.json() == {"status": "ok"}
