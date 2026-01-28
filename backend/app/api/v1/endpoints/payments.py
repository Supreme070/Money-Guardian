"""Payment endpoints for Stripe Pro subscription management.

Handles checkout session creation, billing portal, and subscription status.
"""

import logging
from typing import Literal

import stripe
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from app.api.deps import CurrentUserDep, DbSessionDep
from app.core.config import settings
from app.services.tier_service import TierService

logger = logging.getLogger(__name__)

router = APIRouter()


# ---------------------------------------------------------------------------
# Request / Response Schemas (strict typing, no Any)
# ---------------------------------------------------------------------------

class CreateCheckoutRequest(BaseModel):
    """Request to create a Stripe Checkout session."""

    price_id: str | None = Field(
        default=None,
        description="Stripe Price ID. Uses default Pro price if not provided.",
    )
    success_url: str = Field(
        default="moneyguardian://payment-success",
        description="URL to redirect to after successful payment",
    )
    cancel_url: str = Field(
        default="moneyguardian://payment-cancel",
        description="URL to redirect to after cancelled payment",
    )


class CheckoutSessionResponse(BaseModel):
    """Response containing Stripe Checkout session details."""

    session_id: str = Field(..., description="Stripe Checkout Session ID")
    url: str = Field(..., description="Stripe Checkout URL to redirect user to")


class BillingPortalResponse(BaseModel):
    """Response containing Stripe Billing Portal URL."""

    url: str = Field(..., description="Stripe Billing Portal URL")


class SubscriptionStatusResponse(BaseModel):
    """Current subscription status."""

    tier: Literal["free", "pro", "enterprise"]
    is_active: bool
    stripe_customer_id: str | None
    current_period_end: str | None
    cancel_at_period_end: bool


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.post("/checkout", response_model=CheckoutSessionResponse)
async def create_checkout_session(
    request: CreateCheckoutRequest,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> CheckoutSessionResponse:
    """
    Create a Stripe Checkout session for Pro subscription.

    Returns a checkout URL that the mobile app should open in a browser/webview.
    After payment, Stripe sends a webhook to activate the subscription.
    """
    if not settings.stripe_secret_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Payments not configured",
        )

    stripe.api_key = settings.stripe_secret_key
    price_id = request.price_id or settings.stripe_pro_price_id

    if not price_id:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No Pro subscription price configured",
        )

    # Check if already Pro
    tier_service = TierService(db)
    current_tier = await tier_service.get_tenant_tier(current_user.tenant_id)
    if current_tier in ("pro", "enterprise"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Already on Pro or Enterprise tier",
        )

    # Check if tenant already has a Stripe customer ID
    from sqlalchemy import select
    from app.models.tenant import Tenant

    result = await db.execute(
        select(Tenant).where(Tenant.id == current_user.tenant_id)
    )
    tenant = result.scalar_one_or_none()

    try:
        checkout_params: dict[str, object] = {
            "mode": "subscription",
            "line_items": [{"price": price_id, "quantity": 1}],
            "success_url": request.success_url,
            "cancel_url": request.cancel_url,
            "client_reference_id": str(current_user.tenant_id),
            "metadata": {
                "tenant_id": str(current_user.tenant_id),
                "user_id": str(current_user.user_id),
            },
        }

        # Attach existing Stripe customer if available
        if tenant and tenant.stripe_customer_id:
            checkout_params["customer"] = tenant.stripe_customer_id
        else:
            checkout_params["customer_email"] = current_user.email

        session = stripe.checkout.Session.create(**checkout_params)

    except stripe.error.StripeError as e:
        logger.error("Stripe checkout session creation failed: %s", e)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Payment provider error. Please try again.",
        )

    return CheckoutSessionResponse(
        session_id=session.id,
        url=session.url,
    )


@router.post("/billing-portal", response_model=BillingPortalResponse)
async def create_billing_portal_session(
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> BillingPortalResponse:
    """
    Create a Stripe Billing Portal session.

    Allows Pro users to manage their subscription (cancel, update payment, etc.).
    """
    if not settings.stripe_secret_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Payments not configured",
        )

    stripe.api_key = settings.stripe_secret_key

    from sqlalchemy import select
    from app.models.tenant import Tenant

    result = await db.execute(
        select(Tenant).where(Tenant.id == current_user.tenant_id)
    )
    tenant = result.scalar_one_or_none()

    if not tenant or not tenant.stripe_customer_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No active subscription found",
        )

    try:
        portal_session = stripe.billing_portal.Session.create(
            customer=tenant.stripe_customer_id,
            return_url="moneyguardian://settings",
        )
    except stripe.error.StripeError as e:
        logger.error("Stripe billing portal creation failed: %s", e)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Payment provider error. Please try again.",
        )

    return BillingPortalResponse(url=portal_session.url)


@router.get("/status", response_model=SubscriptionStatusResponse)
async def get_subscription_status(
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> SubscriptionStatusResponse:
    """
    Get current subscription status.

    Returns tier, active status, and subscription period info.
    """
    tier_service = TierService(db)
    current_tier = await tier_service.get_tenant_tier(current_user.tenant_id)

    from sqlalchemy import select
    from app.models.tenant import Tenant

    result = await db.execute(
        select(Tenant).where(Tenant.id == current_user.tenant_id)
    )
    tenant = result.scalar_one_or_none()

    # Get Stripe subscription details if Pro
    current_period_end: str | None = None
    cancel_at_period_end = False

    if tenant and tenant.stripe_customer_id and settings.stripe_secret_key:
        stripe.api_key = settings.stripe_secret_key
        try:
            subscriptions = stripe.Subscription.list(
                customer=tenant.stripe_customer_id,
                status="active",
                limit=1,
            )
            if subscriptions.data:
                sub = subscriptions.data[0]
                current_period_end = str(sub.current_period_end)
                cancel_at_period_end = bool(sub.cancel_at_period_end)
        except stripe.error.StripeError:
            pass

    return SubscriptionStatusResponse(
        tier=current_tier,
        is_active=current_tier in ("pro", "enterprise"),
        stripe_customer_id=tenant.stripe_customer_id if tenant else None,
        current_period_end=current_period_end,
        cancel_at_period_end=cancel_at_period_end,
    )
