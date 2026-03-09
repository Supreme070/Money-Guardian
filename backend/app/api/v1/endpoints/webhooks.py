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
from app.schemas.webhook import (
    PlaidWebhookBody,
    SNSMessage,
    SNSNotificationPayload,
    StripeCheckoutSessionData,
    StripeInvoiceData,
    StripeSubscriptionData,
)
from app.core.redis_dedup import is_duplicate, mark_processed
from app.services.bank_connection_service import BankConnectionService

logger = logging.getLogger(__name__)

router = APIRouter()

_STRIPE_DEDUP_PREFIX = "mg:webhook_dedup:stripe:"
_PLAID_DEDUP_PREFIX = "mg:webhook_dedup:plaid:"
_STRIPE_DEDUP_TTL = 86_400  # 24 hours
_PLAID_DEDUP_TTL = 300  # 5 minutes (matches Plaid's retry window)


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
    except stripe.SignatureVerificationError:
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

    # Idempotency: skip already-processed events (Redis-backed)
    if await is_duplicate(event_id, prefix=_STRIPE_DEDUP_PREFIX, ttl=_STRIPE_DEDUP_TTL):
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
    await mark_processed(event_id, prefix=_STRIPE_DEDUP_PREFIX, ttl=_STRIPE_DEDUP_TTL)

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

    # Idempotency: dedup by item_id + webhook_code (Redis-backed)
    plaid_dedup_key = f"{body.item_id}:{body.webhook_code}"
    if await is_duplicate(plaid_dedup_key, prefix=_PLAID_DEDUP_PREFIX, ttl=_PLAID_DEDUP_TTL):
        logger.info("Plaid webhook already processed: %s", plaid_dedup_key)
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


# ---------------------------------------------------------------------------
# AWS SNS / SES Bounce & Complaint Webhooks
# ---------------------------------------------------------------------------

_SNS_DEDUP_PREFIX = "mg:webhook_dedup:sns:"
_SNS_DEDUP_TTL = 86_400  # 24 hours


@router.post("/ses-notifications", status_code=status.HTTP_200_OK)
async def ses_notifications(
    request: Request,
    db: DbSessionDep,
) -> dict[str, str]:
    """
    Receive AWS SNS notifications for SES bounces and complaints.

    Handles:
    - SubscriptionConfirmation: Auto-confirms the SNS subscription
    - Notification (Bounce/Permanent): Suppresses email for that user
    - Notification (Complaint): Suppresses email for that user
    """
    import json as json_module

    body = await request.body()
    sns_message = SNSMessage.model_validate_json(body)

    # Handle SNS subscription confirmation
    if sns_message.Type == "SubscriptionConfirmation":
        if sns_message.SubscribeURL:
            import httpx

            async with httpx.AsyncClient(timeout=10.0) as client:
                await client.get(sns_message.SubscribeURL)
            logger.info("SNS subscription confirmed: %s", sns_message.MessageId)
        return {"status": "ok"}

    if sns_message.Type != "Notification":
        logger.debug("Ignoring SNS message type: %s", sns_message.Type)
        return {"status": "ok"}

    # Dedup by MessageId
    if await is_duplicate(sns_message.MessageId, prefix=_SNS_DEDUP_PREFIX, ttl=_SNS_DEDUP_TTL):
        return {"status": "ok"}

    # Parse the inner SES notification
    try:
        inner = json_module.loads(sns_message.Message)
        notification = SNSNotificationPayload.model_validate(inner)
    except (json_module.JSONDecodeError, Exception) as e:
        logger.warning("Failed to parse SNS notification message: %s", e)
        return {"status": "ok"}

    if notification.notificationType == "Bounce" and notification.bounce:
        if notification.bounce.bounceType == "Permanent":
            for recipient in notification.bounce.bouncedRecipients:
                await _suppress_user_email(db, recipient.emailAddress, "hard_bounce")
            logger.warning(
                "SES permanent bounce — suppressed %d recipient(s)",
                len(notification.bounce.bouncedRecipients),
            )
        else:
            logger.info("SES transient bounce (type=%s), not suppressing", notification.bounce.bounceType)

    elif notification.notificationType == "Complaint" and notification.complaint:
        for recipient in notification.complaint.complainedRecipients:
            await _suppress_user_email(db, recipient.emailAddress, "complaint")
        logger.warning(
            "SES complaint — suppressed %d recipient(s)",
            len(notification.complaint.complainedRecipients),
        )

    elif notification.notificationType == "Delivery":
        logger.debug("SES delivery confirmation")

    await mark_processed(sns_message.MessageId, prefix=_SNS_DEDUP_PREFIX, ttl=_SNS_DEDUP_TTL)
    return {"status": "ok"}


async def _suppress_user_email(db: AsyncSession, email: str, reason: str) -> None:
    """Suppress email sending for a user by email address."""
    result = await db.execute(
        select(User).where(User.email == email)
    )
    user = result.scalar_one_or_none()
    if user:
        user.email_suppressed = True
        user.email_suppressed_reason = reason
        await db.commit()
        logger.info("Email suppressed for %s (reason=%s)", email, reason)
    else:
        logger.warning("SNS notification for unknown email: %s", email)
