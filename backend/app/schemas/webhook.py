"""Webhook payload schemas - strictly typed, no Any.

Pydantic models for Stripe and Plaid webhook event data objects.
These replace raw `dict` access with validated, typed fields.
"""

from typing import Literal

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Stripe Webhook Data Models
# ---------------------------------------------------------------------------

class StripeCheckoutSessionData(BaseModel):
    """Data from checkout.session.completed event.

    Maps the Stripe CheckoutSession object fields we actually use.
    Extra fields from Stripe are silently ignored (model_config default).
    """

    model_config = {"extra": "ignore"}

    customer: str | None = Field(
        default=None,
        description="Stripe customer ID (cus_xxx)",
    )
    subscription: str | None = Field(
        default=None,
        description="Stripe subscription ID (sub_xxx)",
    )
    client_reference_id: str | None = Field(
        default=None,
        description="Our tenant_id, passed when creating the checkout session",
    )


class StripeSubscriptionData(BaseModel):
    """Data from customer.subscription.updated / deleted events.

    Maps the Stripe Subscription object fields we actually use.
    """

    model_config = {"extra": "ignore"}

    customer: str | None = Field(
        default=None,
        description="Stripe customer ID",
    )
    status: str | None = Field(
        default=None,
        description="Subscription status: active, trialing, past_due, canceled, etc.",
    )
    current_period_end: int | None = Field(
        default=None,
        description="Unix timestamp for end of current billing period",
    )


class StripeInvoiceData(BaseModel):
    """Data from invoice.paid / invoice.payment_failed events.

    Maps the Stripe Invoice object fields we actually use.
    """

    model_config = {"extra": "ignore"}

    customer: str | None = Field(
        default=None,
        description="Stripe customer ID",
    )


# ---------------------------------------------------------------------------
# Plaid Webhook Models
# ---------------------------------------------------------------------------

class PlaidWebhookError(BaseModel):
    """Error object nested inside Plaid ITEM/ERROR webhooks."""

    model_config = {"extra": "ignore"}

    error_code: str = Field(default="UNKNOWN")
    error_message: str = Field(default="Unknown error")
    error_type: str | None = Field(default=None)


class PlaidWebhookBody(BaseModel):
    """Top-level Plaid webhook request body.

    Plaid webhooks always include webhook_type, webhook_code, and
    (for most events) item_id. The error field is present only on
    ITEM/ERROR events.
    """

    model_config = {"extra": "ignore"}

    webhook_type: str = Field(
        default="",
        description="Category: TRANSACTIONS, ITEM, etc.",
    )
    webhook_code: str = Field(
        default="",
        description="Event code: DEFAULT_UPDATE, ERROR, etc.",
    )
    item_id: str | None = Field(
        default=None,
        description="Plaid item ID associated with this event",
    )
    error: PlaidWebhookError | None = Field(
        default=None,
        description="Error details (only present on ITEM/ERROR events)",
    )
