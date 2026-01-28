"""Webhook endpoints for Stripe and Plaid.

These endpoints receive external events and process them asynchronously.
"""

import logging
from datetime import datetime, timezone

import stripe
from fastapi import APIRouter, HTTPException, Header, Request, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import DbSessionDep
from app.core.config import settings
from app.models.tenant import Tenant
from app.models.user import User
from app.models.bank_connection import BankConnection
from app.services.bank_connection_service import BankConnectionService

logger = logging.getLogger(__name__)

router = APIRouter()


# ---------------------------------------------------------------------------
# Stripe Webhooks
# ---------------------------------------------------------------------------

class StripeEventType:
    """Stripe event types we handle."""

    CHECKOUT_COMPLETED: str = "checkout.session.completed"
    SUBSCRIPTION_UPDATED: str = "customer.subscription.updated"
    SUBSCRIPTION_DELETED: str = "customer.subscription.deleted"
    INVOICE_PAID: str = "invoice.paid"
    INVOICE_FAILED: str = "invoice.payment_failed"


@router.post("/stripe", status_code=status.HTTP_200_OK)
async def stripe_webhook(
    request: Request,
    db: DbSessionDep,
    stripe_signature: str = Header(..., alias="stripe-signature"),
) -> dict[str, str]:
    """
    Receive Stripe webhook events.

    Handles:
    - checkout.session.completed → Activate Pro subscription
    - customer.subscription.updated → Update tier/expiry
    - customer.subscription.deleted → Downgrade to free
    - invoice.paid → Extend subscription
    - invoice.payment_failed → Mark payment issue
    """
    if not settings.stripe_webhook_secret:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Stripe webhooks not configured",
        )

    body = await request.body()

    try:
        event = stripe.Webhook.construct_event(
            payload=body,
            sig_header=stripe_signature,
            secret=settings.stripe_webhook_secret,
        )
    except stripe.error.SignatureVerificationError:
        logger.warning("Stripe webhook signature verification failed")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid signature",
        )
    except ValueError:
        logger.warning("Stripe webhook invalid payload")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid payload",
        )

    event_type: str = event["type"]
    event_data: dict = event["data"]["object"]

    logger.info("Stripe webhook received: %s", event_type)

    if event_type == StripeEventType.CHECKOUT_COMPLETED:
        await _handle_checkout_completed(db, event_data)
    elif event_type == StripeEventType.SUBSCRIPTION_UPDATED:
        await _handle_subscription_updated(db, event_data)
    elif event_type == StripeEventType.SUBSCRIPTION_DELETED:
        await _handle_subscription_deleted(db, event_data)
    elif event_type == StripeEventType.INVOICE_PAID:
        await _handle_invoice_paid(db, event_data)
    elif event_type == StripeEventType.INVOICE_FAILED:
        await _handle_invoice_failed(db, event_data)
    else:
        logger.debug("Unhandled Stripe event type: %s", event_type)

    return {"status": "ok"}


async def _handle_checkout_completed(
    db: AsyncSession,
    data: dict,
) -> None:
    """Activate Pro subscription after successful checkout."""
    customer_id: str | None = data.get("customer")
    subscription_id: str | None = data.get("subscription")
    client_reference_id: str | None = data.get("client_reference_id")  # tenant_id

    if not client_reference_id:
        logger.error("Checkout completed without client_reference_id (tenant_id)")
        return

    # Update tenant
    await db.execute(
        update(Tenant)
        .where(Tenant.id == client_reference_id)
        .values(
            tier="pro",
            stripe_customer_id=customer_id,
        )
    )

    # Update user subscription tier
    await db.execute(
        update(User)
        .where(User.tenant_id == client_reference_id)
        .values(subscription_tier="pro")
    )

    await db.commit()
    logger.info("Pro activated for tenant %s", client_reference_id)


async def _handle_subscription_updated(
    db: AsyncSession,
    data: dict,
) -> None:
    """Handle subscription plan changes."""
    customer_id: str | None = data.get("customer")
    status_value: str | None = data.get("status")
    current_period_end: int | None = data.get("current_period_end")

    if not customer_id:
        return

    result = await db.execute(
        select(Tenant).where(Tenant.stripe_customer_id == customer_id)
    )
    tenant = result.scalar_one_or_none()
    if not tenant:
        logger.warning("Stripe customer %s not found in tenants", customer_id)
        return

    # Map Stripe status to tier
    tier = "pro" if status_value in ("active", "trialing") else "free"
    expires_at = (
        datetime.fromtimestamp(current_period_end, tz=timezone.utc)
        if current_period_end
        else None
    )

    tenant.tier = tier
    await db.execute(
        update(User)
        .where(User.tenant_id == tenant.id)
        .values(
            subscription_tier=tier,
            subscription_expires_at=expires_at,
        )
    )
    await db.commit()
    logger.info("Subscription updated for tenant %s: tier=%s", tenant.id, tier)


async def _handle_subscription_deleted(
    db: AsyncSession,
    data: dict,
) -> None:
    """Downgrade to free when subscription is cancelled."""
    customer_id: str | None = data.get("customer")
    if not customer_id:
        return

    result = await db.execute(
        select(Tenant).where(Tenant.stripe_customer_id == customer_id)
    )
    tenant = result.scalar_one_or_none()
    if not tenant:
        return

    tenant.tier = "free"
    await db.execute(
        update(User)
        .where(User.tenant_id == tenant.id)
        .values(
            subscription_tier="free",
            subscription_expires_at=None,
        )
    )
    await db.commit()
    logger.info("Subscription cancelled for tenant %s, downgraded to free", tenant.id)


async def _handle_invoice_paid(
    db: AsyncSession,
    data: dict,
) -> None:
    """Confirm payment - extend subscription period."""
    customer_id: str | None = data.get("customer")
    if not customer_id:
        return

    # Subscription is active - Stripe subscription.updated handles the period
    logger.info("Invoice paid for customer %s", customer_id)


async def _handle_invoice_failed(
    db: AsyncSession,
    data: dict,
) -> None:
    """Handle failed payment - Stripe retries automatically."""
    customer_id: str | None = data.get("customer")
    logger.warning("Invoice payment failed for customer %s", customer_id)


# ---------------------------------------------------------------------------
# Plaid Webhooks
# ---------------------------------------------------------------------------

class PlaidWebhookType:
    """Plaid webhook types we handle."""

    TRANSACTIONS_DEFAULT_UPDATE: str = "DEFAULT_UPDATE"
    TRANSACTIONS_INITIAL_UPDATE: str = "INITIAL_UPDATE"
    TRANSACTIONS_HISTORICAL_UPDATE: str = "HISTORICAL_UPDATE"
    TRANSACTIONS_SYNC_UPDATES_AVAILABLE: str = "SYNC_UPDATES_AVAILABLE"
    ITEM_ERROR: str = "ERROR"
    ITEM_PENDING_EXPIRATION: str = "PENDING_EXPIRATION"


class PlaidWebhookCategory:
    """Plaid webhook categories."""

    TRANSACTIONS: str = "TRANSACTIONS"
    ITEM: str = "ITEM"


@router.post("/plaid", status_code=status.HTTP_200_OK)
async def plaid_webhook(
    request: Request,
    db: DbSessionDep,
) -> dict[str, str]:
    """
    Receive Plaid webhook events.

    Handles:
    - TRANSACTIONS: Trigger transaction sync
    - ITEM errors: Mark connection as errored
    - ITEM pending expiration: Alert user to re-authenticate
    """
    body = await request.json()

    webhook_type: str = body.get("webhook_type", "")
    webhook_code: str = body.get("webhook_code", "")
    item_id: str | None = body.get("item_id")

    logger.info("Plaid webhook received: %s/%s for item %s", webhook_type, webhook_code, item_id)

    if not item_id:
        return {"status": "ok"}

    # Find the connection by item_id
    result = await db.execute(
        select(BankConnection).where(
            BankConnection.item_id == item_id,
            BankConnection.deleted_at.is_(None),
        )
    )
    connection = result.scalar_one_or_none()

    if not connection:
        logger.warning("Plaid webhook for unknown item_id: %s", item_id)
        return {"status": "ok"}

    if webhook_type == PlaidWebhookCategory.TRANSACTIONS:
        if webhook_code in (
            PlaidWebhookType.TRANSACTIONS_DEFAULT_UPDATE,
            PlaidWebhookType.TRANSACTIONS_INITIAL_UPDATE,
            PlaidWebhookType.TRANSACTIONS_HISTORICAL_UPDATE,
            PlaidWebhookType.TRANSACTIONS_SYNC_UPDATES_AVAILABLE,
        ):
            # Trigger async transaction sync
            try:
                from app.tasks.banking_tasks import sync_bank_transactions
                sync_bank_transactions.delay(str(connection.id))
            except ImportError:
                # Celery not available, sync inline
                service = BankConnectionService(db)
                await service.sync_transactions(
                    tenant_id=connection.tenant_id,
                    user_id=connection.user_id,
                    connection_id=connection.id,
                )

    elif webhook_type == PlaidWebhookCategory.ITEM:
        if webhook_code == PlaidWebhookType.ITEM_ERROR:
            error = body.get("error", {})
            connection.status = "error"
            connection.error_code = error.get("error_code", "UNKNOWN")
            connection.error_message = error.get("error_message", "Unknown error")
            await db.commit()
            logger.warning(
                "Plaid item error for connection %s: %s",
                connection.id,
                connection.error_code,
            )

        elif webhook_code == PlaidWebhookType.ITEM_PENDING_EXPIRATION:
            connection.status = "pending_expiration"
            connection.error_message = "Bank connection will expire soon. Please re-authenticate."
            await db.commit()
            logger.info(
                "Plaid item pending expiration for connection %s",
                connection.id,
            )

    return {"status": "ok"}
