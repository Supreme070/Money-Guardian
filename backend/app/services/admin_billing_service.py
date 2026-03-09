"""Admin billing service for Stripe management.

Provides read/write access to Stripe customer data, subscriptions,
invoices, refunds, and account credits for the admin portal.
"""

import logging
from datetime import datetime, timezone
from uuid import UUID

import stripe
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.tenant import Tenant
from app.schemas.admin_billing import (
    StripeCustomerInfo,
    StripeInvoiceInfo,
    StripeSubscriptionInfo,
    TenantBillingResponse,
)

logger = logging.getLogger(__name__)


class BillingError(Exception):
    """Base billing exception."""


class TenantNotFoundError(BillingError):
    """Raised when the tenant does not exist."""


class NoStripeCustomerError(BillingError):
    """Raised when the tenant has no Stripe customer ID."""


def _configure_stripe() -> None:
    """Ensure stripe is configured with the API key."""
    stripe.api_key = settings.stripe_secret_key


async def get_tenant_billing(
    tenant_id: str,
    db: AsyncSession,
) -> TenantBillingResponse:
    """Fetch Stripe billing data for a tenant.

    Retrieves customer info, active subscription, and recent invoices.
    """
    _configure_stripe()

    tenant_uuid = UUID(tenant_id)
    result = await db.execute(
        select(Tenant).where(Tenant.id == tenant_uuid)
    )
    tenant = result.scalar_one_or_none()
    if tenant is None:
        raise TenantNotFoundError(f"Tenant {tenant_id} not found")

    if not tenant.stripe_customer_id:
        return TenantBillingResponse(customer=None, subscription=None, invoices=[])

    customer_id = tenant.stripe_customer_id

    # Fetch customer
    try:
        cust = stripe.Customer.retrieve(customer_id)
    except stripe.StripeError as e:
        logger.error("Stripe customer fetch failed for %s: %s", customer_id, e)
        raise BillingError(f"Failed to fetch Stripe customer: {e}") from e

    customer_info = StripeCustomerInfo(
        customer_id=cust.id,
        email=cust.get("email"),
        name=cust.get("name"),
        created=datetime.fromtimestamp(cust.created, tz=timezone.utc),
        default_payment_method=cust.get("default_source")
        or (cust.get("invoice_settings") or {}).get("default_payment_method"),
    )

    # Fetch active subscription
    subscription_info: StripeSubscriptionInfo | None = None
    try:
        subs = stripe.Subscription.list(customer=customer_id, limit=1, status="all")
        if subs.data:
            sub = subs.data[0]
            plan = sub["items"]["data"][0]["plan"] if sub["items"]["data"] else {}
            subscription_info = StripeSubscriptionInfo(
                subscription_id=sub.id,
                status=sub.status,
                current_period_start=datetime.fromtimestamp(
                    sub.current_period_start, tz=timezone.utc,
                ),
                current_period_end=datetime.fromtimestamp(
                    sub.current_period_end, tz=timezone.utc,
                ),
                plan_amount=plan.get("amount", 0),
                plan_interval=plan.get("interval", "month"),
                cancel_at_period_end=sub.cancel_at_period_end,
            )
    except stripe.StripeError as e:
        logger.error("Stripe subscription fetch failed for %s: %s", customer_id, e)

    # Fetch recent invoices
    invoices: list[StripeInvoiceInfo] = []
    try:
        inv_list = stripe.Invoice.list(customer=customer_id, limit=10)
        for inv in inv_list.data:
            invoices.append(
                StripeInvoiceInfo(
                    invoice_id=inv.id,
                    status=inv.status,
                    amount_due=inv.amount_due,
                    amount_paid=inv.amount_paid,
                    currency=inv.currency,
                    created=datetime.fromtimestamp(inv.created, tz=timezone.utc),
                    hosted_invoice_url=inv.get("hosted_invoice_url"),
                )
            )
    except stripe.StripeError as e:
        logger.error("Stripe invoice fetch failed for %s: %s", customer_id, e)

    return TenantBillingResponse(
        customer=customer_info,
        subscription=subscription_info,
        invoices=invoices,
    )


async def refund_payment(
    payment_intent_id: str,
    amount_cents: int | None,
    reason: str,
) -> dict[str, str | int]:
    """Issue a full or partial refund for a payment intent.

    Returns dict with refund_id, amount, status, reason.
    """
    _configure_stripe()

    try:
        params: dict[str, str | int] = {"payment_intent": payment_intent_id}
        if amount_cents is not None:
            params["amount"] = amount_cents

        refund = stripe.Refund.create(**params)

        logger.info(
            "Refund issued: %s amount=%s for pi=%s reason=%s",
            refund.id, refund.amount, payment_intent_id, reason,
        )

        return {
            "refund_id": refund.id,
            "amount": refund.amount,
            "status": refund.status,
            "reason": reason,
        }

    except stripe.StripeError as e:
        logger.error("Stripe refund failed for %s: %s", payment_intent_id, e)
        raise BillingError(f"Refund failed: {e}") from e


async def cancel_subscription(
    subscription_id: str,
    at_period_end: bool,
) -> dict[str, str | bool]:
    """Cancel a Stripe subscription immediately or at period end.

    Returns dict with subscription_id, status, cancel_at_period_end.
    """
    _configure_stripe()

    try:
        if at_period_end:
            sub = stripe.Subscription.modify(
                subscription_id,
                cancel_at_period_end=True,
            )
        else:
            sub = stripe.Subscription.cancel(subscription_id)

        logger.info(
            "Subscription cancelled: %s at_period_end=%s status=%s",
            subscription_id, at_period_end, sub.status,
        )

        return {
            "subscription_id": sub.id,
            "status": sub.status,
            "cancel_at_period_end": sub.cancel_at_period_end,
        }

    except stripe.StripeError as e:
        logger.error("Stripe cancel failed for %s: %s", subscription_id, e)
        raise BillingError(f"Cancellation failed: {e}") from e


async def grant_credit(
    customer_id: str,
    amount_cents: int,
    description: str,
) -> dict[str, str | int]:
    """Add account credit (negative balance) to a Stripe customer.

    Stripe customer balance transactions use negative amounts for credits.
    Returns dict with transaction_id, amount, description.
    """
    _configure_stripe()

    try:
        txn = stripe.CustomerBalanceTransaction.create(
            customer_id,
            amount=-abs(amount_cents),  # Negative = credit
            currency="usd",
            description=description,
        )

        logger.info(
            "Credit granted: customer=%s amount=%s desc=%s",
            customer_id, amount_cents, description,
        )

        return {
            "transaction_id": txn.id,
            "amount": abs(txn.amount),
            "description": description,
        }

    except stripe.StripeError as e:
        logger.error("Stripe credit failed for %s: %s", customer_id, e)
        raise BillingError(f"Credit failed: {e}") from e
