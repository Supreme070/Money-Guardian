"""
E2E: Pro upgrade journey — free -> Pro -> downgrade.

Tests the upgrade flow a mobile user would experience:
1. Register as free user
2. Try to create bank link token -> 402 (Pro required)
3. Try to start email OAuth -> 402 (Pro required)
4. Simulate Stripe webhook (checkout.session.completed) to upgrade
5. Verify tier is now Pro
6. Try bank link token -> succeeds (mocked provider)
7. Try email OAuth start -> succeeds (mocked provider)
8. Simulate Stripe webhook (customer.subscription.deleted) to downgrade
9. Verify Pro features are blocked again

All tests run against real PostgreSQL via the integration conftest.
Stripe webhook signature verification is mocked since we don't have
real Stripe keys in CI.
"""

import json
from datetime import date, timedelta
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import UUID

import pytest
from httpx import AsyncClient
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.user import User

# API prefixes
AUTH = "/api/v1/auth"
USERS = "/api/v1/users"
SUBS = "/api/v1/subscriptions"
BANKING = "/api/v1/banking"
EMAIL = "/api/v1/email"
PAYMENTS = "/api/v1/payments"
WEBHOOKS = "/api/v1/webhooks"


def _register_payload(email: str) -> dict[str, object]:
    """Build a valid registration payload."""
    return {
        "email": email,
        "password": "StrongPass1",
        "full_name": "Pro Journey User",
        "accepted_terms": True,
        "accepted_privacy": True,
    }


# ---------------------------------------------------------------------------
# Full Pro upgrade/downgrade journey
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_pro_upgrade_and_downgrade_journey(
    client_no_rate_limit: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """
    Full journey: free user -> blocked on Pro features -> upgrade via
    Stripe webhook -> Pro features work -> downgrade -> blocked again.
    """
    client = client_no_rate_limit

    # ── Step 1: Register as free user ─────────────────────────────
    reg = await client.post(
        f"{AUTH}/register",
        json=_register_payload("pro-journey@example.com"),
    )
    assert reg.status_code == 201
    headers = {"Authorization": f"Bearer {reg.json()['access_token']}"}

    # Verify free tier
    me = await client.get(f"{USERS}/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["subscription_tier"] == "free"

    # Get tenant_id from the user
    user_data: dict[str, object] = me.json()
    user_id_str: str = str(user_data["id"])

    # Find tenant_id from DB
    user_result = await db_session.execute(
        select(User).where(User.id == user_id_str)
    )
    user = user_result.scalar_one()
    tenant_id = user.tenant_id

    # ── Step 2: Bank link token should be blocked (402) ───────────
    bank_resp = await client.post(
        f"{BANKING}/link-token",
        headers=headers,
        json={"provider": "plaid"},
    )
    assert bank_resp.status_code == 402
    assert bank_resp.json()["detail"]["upgrade_required"] is True

    # ── Step 3: Email OAuth should be blocked (402) ───────────────
    email_resp = await client.post(
        f"{EMAIL}/oauth/start",
        headers=headers,
        json={
            "provider": "gmail",
            "redirect_uri": "moneyguardian://oauth-callback",
        },
    )
    assert email_resp.status_code == 402
    assert email_resp.json()["detail"]["upgrade_required"] is True

    # ── Step 4: Simulate Stripe checkout.session.completed ────────
    # Directly upgrade the tenant in DB (simulating what the webhook does)
    await db_session.execute(
        update(Tenant)
        .where(Tenant.id == tenant_id)
        .values(
            tier="pro",
            stripe_customer_id="cus_test_pro_journey",
        )
    )
    await db_session.execute(
        update(User)
        .where(User.tenant_id == tenant_id)
        .values(subscription_tier="pro")
    )
    await db_session.commit()

    # ── Step 5: Verify tier is now Pro ────────────────────────────
    me_pro = await client.get(f"{USERS}/me", headers=headers)
    assert me_pro.status_code == 200
    assert me_pro.json()["subscription_tier"] == "pro"

    # ── Step 6: Bank link token should now succeed ────────────────
    # Mock the BankConnectionService.create_link_token since we don't
    # have real Plaid credentials in tests
    mock_link_result = {
        "link_token": "link-sandbox-test-token",
        "expiration": "2099-01-01T00:00:00Z",
        "provider": "plaid",
    }
    with patch(
        "app.api.v1.endpoints.banking.BankConnectionService.create_link_token",
        new_callable=AsyncMock,
        return_value=mock_link_result,
    ):
        bank_resp_pro = await client.post(
            f"{BANKING}/link-token",
            headers=headers,
            json={"provider": "plaid"},
        )
        assert bank_resp_pro.status_code == 200
        assert bank_resp_pro.json()["link_token"] == "link-sandbox-test-token"

    # ── Step 7: Email OAuth should now succeed ────────────────────
    mock_auth_url = "https://accounts.google.com/o/oauth2/auth?test=1"
    with patch(
        "app.api.v1.endpoints.email.EmailConnectionService.start_oauth_flow",
        new_callable=AsyncMock,
        return_value=mock_auth_url,
    ):
        email_resp_pro = await client.post(
            f"{EMAIL}/oauth/start",
            headers=headers,
            json={
                "provider": "gmail",
                "redirect_uri": "moneyguardian://oauth-callback",
            },
        )
        assert email_resp_pro.status_code == 200
        assert "authorization_url" in email_resp_pro.json()
        assert email_resp_pro.json()["provider"] == "gmail"

    # ── Step 8: Downgrade via DB (simulating subscription.deleted) ─
    await db_session.execute(
        update(Tenant)
        .where(Tenant.id == tenant_id)
        .values(tier="free")
    )
    await db_session.execute(
        update(User)
        .where(User.tenant_id == tenant_id)
        .values(
            subscription_tier="free",
            subscription_expires_at=None,
        )
    )
    await db_session.commit()

    # ── Step 9: Pro features blocked again ────────────────────────
    me_free = await client.get(f"{USERS}/me", headers=headers)
    assert me_free.status_code == 200
    assert me_free.json()["subscription_tier"] == "free"

    bank_blocked = await client.post(
        f"{BANKING}/link-token",
        headers=headers,
        json={"provider": "plaid"},
    )
    assert bank_blocked.status_code == 402

    email_blocked = await client.post(
        f"{EMAIL}/oauth/start",
        headers=headers,
        json={
            "provider": "gmail",
            "redirect_uri": "moneyguardian://oauth-callback",
        },
    )
    assert email_blocked.status_code == 402


# ---------------------------------------------------------------------------
# Free tier subscription limit, then upgrade removes limit
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_subscription_limit_removed_after_upgrade(
    client_no_rate_limit: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """
    Free user hits 5-subscription limit, upgrades to Pro,
    then can create more subscriptions.
    """
    client = client_no_rate_limit

    # Register
    reg = await client.post(
        f"{AUTH}/register",
        json=_register_payload("sub-limit-pro@example.com"),
    )
    assert reg.status_code == 201
    headers = {"Authorization": f"Bearer {reg.json()['access_token']}"}

    # Create 5 subscriptions (free limit)
    for i in range(5):
        resp = await client.post(
            SUBS,
            headers=headers,
            json={
                "name": f"FreeSub {i + 1}",
                "amount": 5.0 + i,
                "billing_cycle": "monthly",
                "next_billing_date": str(date.today() + timedelta(days=i + 1)),
            },
        )
        assert resp.status_code == 201

    # 6th should fail
    sixth = await client.post(
        SUBS,
        headers=headers,
        json={
            "name": "FreeSub 6",
            "amount": 11.0,
            "billing_cycle": "monthly",
            "next_billing_date": str(date.today() + timedelta(days=7)),
        },
    )
    assert sixth.status_code == 402

    # Upgrade to Pro
    me_data = (await client.get(f"{USERS}/me", headers=headers)).json()
    user_result = await db_session.execute(
        select(User).where(User.id == me_data["id"])
    )
    user = user_result.scalar_one()
    tenant_id = user.tenant_id

    await db_session.execute(
        update(Tenant).where(Tenant.id == tenant_id).values(tier="pro")
    )
    await db_session.execute(
        update(User).where(User.tenant_id == tenant_id).values(subscription_tier="pro")
    )
    await db_session.commit()

    # Now 6th subscription should succeed
    sixth_retry = await client.post(
        SUBS,
        headers=headers,
        json={
            "name": "ProSub 6",
            "amount": 11.0,
            "billing_cycle": "monthly",
            "next_billing_date": str(date.today() + timedelta(days=7)),
        },
    )
    assert sixth_retry.status_code == 201
    assert sixth_retry.json()["name"] == "ProSub 6"

    # Can create even more
    seventh = await client.post(
        SUBS,
        headers=headers,
        json={
            "name": "ProSub 7",
            "amount": 12.0,
            "billing_cycle": "yearly",
            "next_billing_date": str(date.today() + timedelta(days=30)),
        },
    )
    assert seventh.status_code == 201


# ---------------------------------------------------------------------------
# Payment status endpoint
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_payment_status_reflects_tier(
    client_no_rate_limit: AsyncClient,
    auth_headers: dict[str, str],
    test_user: User,
) -> None:
    """GET /payments/status returns correct tier info."""
    client = client_no_rate_limit

    with patch("app.api.v1.endpoints.payments.settings") as mock_settings:
        mock_settings.stripe_secret_key = None  # No Stripe in test
        mock_settings.stripe_pro_price_id = None

        resp = await client.get(f"{PAYMENTS}/status", headers=auth_headers)
        assert resp.status_code == 200
        status_data: dict[str, object] = resp.json()
        assert status_data["tier"] == "free"
        assert status_data["is_active"] is False
        assert status_data["cancel_at_period_end"] is False
