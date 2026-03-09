"""Admin billing schemas for Stripe management — strict Pydantic models, no ``Any`` types."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

_ADMIN_CONFIG = ConfigDict(
    from_attributes=True,
    str_strip_whitespace=True,
    strict=True,
    ser_json_inf_nan="constants",
)


class StripeCustomerInfo(BaseModel):
    model_config = _ADMIN_CONFIG
    customer_id: str
    email: str | None
    name: str | None
    created: datetime
    default_payment_method: str | None


class StripeSubscriptionInfo(BaseModel):
    model_config = _ADMIN_CONFIG
    subscription_id: str
    status: str
    current_period_start: datetime
    current_period_end: datetime
    plan_amount: int  # cents
    plan_interval: str
    cancel_at_period_end: bool


class StripeInvoiceInfo(BaseModel):
    model_config = _ADMIN_CONFIG
    invoice_id: str
    status: str | None
    amount_due: int
    amount_paid: int
    currency: str
    created: datetime
    hosted_invoice_url: str | None


class TenantBillingResponse(BaseModel):
    model_config = _ADMIN_CONFIG
    customer: StripeCustomerInfo | None
    subscription: StripeSubscriptionInfo | None
    invoices: list[StripeInvoiceInfo]


class RefundRequest(BaseModel):
    model_config = _ADMIN_CONFIG
    payment_intent_id: str = Field(..., min_length=1)
    amount_cents: int | None = Field(
        default=None,
        gt=0,
        description="Amount in cents for partial refund. Omit for full refund.",
    )
    reason: str = Field(..., min_length=3, max_length=500)


class RefundResponse(BaseModel):
    model_config = _ADMIN_CONFIG
    refund_id: str
    amount: int
    status: str
    reason: str


class CancelSubscriptionRequest(BaseModel):
    model_config = _ADMIN_CONFIG
    at_period_end: bool = True
    reason: str = Field(..., min_length=3, max_length=500)


class GrantCreditRequest(BaseModel):
    model_config = _ADMIN_CONFIG
    amount_cents: int = Field(..., gt=0)
    description: str = Field(..., min_length=3, max_length=500)
