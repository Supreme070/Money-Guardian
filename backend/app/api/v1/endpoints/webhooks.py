"""Webhook endpoints for Stripe and Plaid.

These endpoints receive external events and process them asynchronously.
"""

import logging
import threading
import time
from collections import OrderedDict
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
from app.schemas.webhook import (
    PlaidWebhookBody,
    StripeCheckoutSessionData,
    StripeInvoiceData,
    StripeSubscriptionData,
)
from app.services.bank_connection_service import BankConnectionService

logger = logging.getLogger(__name__)

router = APIRouter()


# ---------------------------------------------------------------------------
# Webhook Idempotency Store
# ---------------------------------------------------------------------------

_IDEMPOTENCY_MAX_SIZE = 10_000
_IDEMPOTENCY_TTL_SECONDS = 86_400  # 24 hours

_idem_lock = threading.Lock()


class _IdempotencyStore:
    """Thread-safe in-memory store tracking processed webhook event IDs.

    Stores event_id -> timestamp so entries can be evicted after TTL.
    Uses an OrderedDict for LRU-style eviction when max size is reached.
    """

    def __init__(
        self, max_size: int = _IDEMPOTENCY_MAX_SIZE, ttl: int = _IDEMPOTENCY_TTL_SECONDS
    ) -> None:
        self._max_size = max_size
        self._ttl = ttl
        self._store: OrderedDict[str, float] = OrderedDict()

    def is_duplicate(self, event_id: str) -> bool:
        """Return True if this event_id was already processed."""
        with _idem_lock:
            if event_id in self._store:
                ts = self._store[event_id]
                if time.time() - ts < self._ttl:
                    return True
                # Expired entry, remove it
                del self._store[event_id]
            return False

    def mark_processed(self, event_id: str) -> None:
        """Record an event_id as processed."""
        with _idem_lock:
            self._store[event_id] = time.time()
            self._store.move_to_end(event_id)
            # Evict oldest entries if over capacity
            while len(self._store) > self._max_size:
                self._store.popitem(last=False)


_webhook_idempotency = _IdempotencyStore()


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
    - checkout.session.completed -> Activate Pro subscription
    - customer.subscription.updated -> Update tier/expiry
    - customer.subscription.deleted -> Downgrade to free
    - invoice.paid -> Extend subscription
    - invoice.payment_failed -> Mark payment issue
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

    event_id: str = event["id"]
    event_type: str = event["type"]
    raw_data: dict[str, object] = event["data"]["object"]

    # Idempotency: skip already-processed events
    if _webhook_idempotency.is_duplicate(event_id):
        logger.info("Stripe webhook already processed: %s (%s)", event_id, event_type)
        return {"status": "ok"}

    logger.info("Stripe webhook received: %s (%s)", event_type, event_id)

    if event_type == StripeEventType.CHECKOUT_COMPLETED:
        data = StripeCheckoutSessionData.model_validate(raw_data)
        await _handle_checkout_completed(db, data)
    elif event_type == StripeEventType.SUBSCRIPTION_UPDATED:
        data = StripeSubscriptionData.model_validate(raw_data)
        await _handle_subscription_updated(db, data)
    elif event_type == StripeEventType.SUBSCRIPTION_DELETED:
        data = StripeSubscriptionData.model_validate(raw_data)
        await _handle_subscription_deleted(db, data)
    elif event_type == StripeEventType.INVOICE_PAID:
        data = StripeInvoiceData.model_validate(raw_data)
        await _handle_invoice_paid(db, data)
    elif event_type == StripeEventType.INVOICE_FAILED:
        data = StripeInvoiceData.model_validate(raw_data)
        await _handle_invoice_failed(db, data)
    else:
        logger.debug("Unhandled Stripe event type: %s", event_type)

    # Mark event as processed for idempotency
    _webhook_idempotency.mark_processed(event_id)

    return {"status": "ok"}


async def _handle_checkout_completed(
    db: AsyncSession,
    data: StripeCheckoutSessionData,
) -> None:
    """Activate Pro subscription after successful checkout."""
    if not data.client_reference_id:
        logger.error("Checkout completed without client_reference_id (tenant_id)")
        return

    # Update tenant
    await db.execute(
        update(Tenant)
        .where(Tenant.id == data.client_reference_id)
        .values(
            tier="pro",
            stripe_customer_id=data.customer,
        )
    )

    # Update user subscription tier
    await db.execute(
        update(User)
        .where(User.tenant_id == data.client_reference_id)
        .values(subscription_tier="pro")
    )

    await db.commit()
    logger.info("Pro activated for tenant %s", data.client_reference_id)


async def _handle_subscription_updated(
    db: AsyncSession,
    data: StripeSubscriptionData,
) -> None:
    """Handle subscription plan changes."""
    if not data.customer:
        return

    result = await db.execute(
        select(Tenant).where(Tenant.stripe_customer_id == data.customer)
    )
    tenant = result.scalar_one_or_none()
    if not tenant:
        logger.warning("Stripe customer %s not found in tenants", data.customer)
        return

    # Map Stripe status to tier
    tier = "pro" if data.status in ("active", "trialing") else "free"
    expires_at = (
        datetime.fromtimestamp(data.current_period_end, tz=timezone.utc)
        if data.current_period_end
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
    data: StripeSubscriptionData,
) -> None:
    """Downgrade to free when subscription is cancelled."""
    if not data.customer:
        return

    result = await db.execute(
        select(Tenant).where(Tenant.stripe_customer_id == data.customer)
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
    data: StripeInvoiceData,
) -> None:
    """Confirm payment - extend subscription period."""
    if not data.customer:
        return

    # Subscription is active - Stripe subscription.updated handles the period
    logger.info("Invoice paid for customer %s", data.customer)


async def _handle_invoice_failed(
    db: AsyncSession,
    data: StripeInvoiceData,
) -> None:
    """Handle failed payment - Stripe retries automatically."""
    logger.warning("Invoice payment failed for customer %s", data.customer)


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


async def _verify_plaid_webhook(request: Request, body_bytes: bytes) -> PlaidWebhookBody:
    """
    Verify Plaid webhook signature using their JWT verification.

    Plaid signs webhooks with a JWT in the 'Plaid-Verification' header.
    The JWT is signed with a key from Plaid's JWKS endpoint, and the body
    hash is included in the JWT claims.

    Args:
        request: The FastAPI request object.
        body_bytes: The raw request body bytes.

    Returns:
        The parsed and validated PlaidWebhookBody.

    Raises:
        HTTPException: If verification fails.
    """
    import hashlib
    import time
    from jose import jwt as jose_jwt, JWTError as JoseJWTError
    import httpx

    verification_header = request.headers.get("plaid-verification")

    if not verification_header:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing Plaid-Verification header",
        )

    try:
        # Step 1: Decode the JWT header to get the key ID (kid)
        unverified_header = jose_jwt.get_unverified_header(verification_header)
        kid: str = unverified_header["kid"]

        # Step 2: Fetch Plaid's JWKS (JSON Web Key Set) to get the public key
        plaid_host = (
            "sandbox" if settings.plaid_environment == "sandbox" else "production"
        )
        async with httpx.AsyncClient(timeout=10.0) as client:
            jwks_response = await client.post(
                f"https://{plaid_host}.plaid.com/webhook_verification_key/get",
                json={
                    "client_id": settings.plaid_client_id,
                    "secret": settings.plaid_secret,
                    "key_id": kid,
                },
            )
            jwks_response.raise_for_status()
            jwks_data: dict[str, object] = jwks_response.json()
            key = jwks_data["key"]

        # Step 3: Verify the JWT and extract claims
        claims: dict[str, object] = jose_jwt.decode(
            verification_header,
            key,
            algorithms=["ES256"],
        )

        # Step 4: Check that the JWT hasn't expired (5 min window)
        issued_at = int(claims.get("iat", 0))
        if abs(time.time() - issued_at) > 300:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Plaid webhook JWT expired",
            )

        # Step 5: Verify body hash matches
        expected_hash = str(claims.get("request_body_sha256", ""))
        actual_hash = hashlib.sha256(body_bytes).hexdigest()
        if expected_hash != actual_hash:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Plaid webhook body hash mismatch",
            )

    except JoseJWTError as e:
        logger.warning("Plaid webhook JWT verification failed: %s", e)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Plaid webhook signature verification failed",
        )
    except httpx.HTTPError as e:
        logger.error("Failed to fetch Plaid JWKS: %s", e)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Cannot verify Plaid webhook at this time",
        )

    return PlaidWebhookBody.model_validate_json(body_bytes)


@router.post("/plaid", status_code=status.HTTP_200_OK)
async def plaid_webhook(
    request: Request,
    db: DbSessionDep,
) -> dict[str, str]:
    """
    Receive Plaid webhook events.

    Verifies the Plaid-Verification JWT signature before processing.

    Handles:
    - TRANSACTIONS: Trigger transaction sync
    - ITEM errors: Mark connection as errored
    - ITEM pending expiration: Alert user to re-authenticate
    """
    body_bytes = await request.body()
    body: PlaidWebhookBody = await _verify_plaid_webhook(request, body_bytes)

    logger.info(
        "Plaid webhook received: %s/%s for item %s",
        body.webhook_type,
        body.webhook_code,
        body.item_id,
    )

    if not body.item_id:
        return {"status": "ok"}

    # Find the connection by item_id
    result = await db.execute(
        select(BankConnection).where(
            BankConnection.item_id == body.item_id,
            BankConnection.deleted_at.is_(None),
        )
    )
    connection = result.scalar_one_or_none()

    if not connection:
        logger.warning("Plaid webhook for unknown item_id: %s", body.item_id)
        return {"status": "ok"}

    if body.webhook_type == PlaidWebhookCategory.TRANSACTIONS:
        if body.webhook_code in (
            PlaidWebhookType.TRANSACTIONS_DEFAULT_UPDATE,
            PlaidWebhookType.TRANSACTIONS_INITIAL_UPDATE,
            PlaidWebhookType.TRANSACTIONS_HISTORICAL_UPDATE,
            PlaidWebhookType.TRANSACTIONS_SYNC_UPDATES_AVAILABLE,
        ):
            # Trigger async transaction sync
            try:
                from app.tasks.banking_tasks import sync_bank_transactions

                sync_bank_transactions.delay(
                    str(connection.id),
                    str(connection.tenant_id),
                    str(connection.user_id),
                )
            except ImportError:
                # Celery not available, sync inline
                service = BankConnectionService(db)
                await service.sync_transactions(
                    tenant_id=connection.tenant_id,
                    user_id=connection.user_id,
                    connection_id=connection.id,
                )

    elif body.webhook_type == PlaidWebhookCategory.ITEM:
        if body.webhook_code == PlaidWebhookType.ITEM_ERROR:
            error = body.error
            connection.status = "error"
            connection.error_code = error.error_code if error else "UNKNOWN"
            connection.error_message = error.error_message if error else "Unknown error"
            await db.commit()
            logger.warning(
                "Plaid item error for connection %s: %s",
                connection.id,
                connection.error_code,
            )

        elif body.webhook_code == PlaidWebhookType.ITEM_PENDING_EXPIRATION:
            connection.status = "pending_expiration"
            connection.error_message = (
                "Bank connection will expire soon. Please re-authenticate."
            )
            await db.commit()
            logger.info(
                "Plaid item pending expiration for connection %s",
                connection.id,
            )

    return {"status": "ok"}
