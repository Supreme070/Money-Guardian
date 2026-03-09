"""Admin billing management endpoints.

Provides Stripe billing visibility and management: view tenant billing
data, issue refunds, cancel subscriptions, and grant account credits.
"""

import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.rate_limit import limiter
from app.db.session import get_db
from app.models.admin_user import AdminUser
from app.schemas.admin_billing import (
    CancelSubscriptionRequest,
    GrantCreditRequest,
    RefundRequest,
    RefundResponse,
    TenantBillingResponse,
)
from app.services import admin_billing_service, audit_service
from app.services.admin_billing_service import (
    BillingError,
    NoStripeCustomerError,
    TenantNotFoundError,
)
from app.services.rbac_service import require_permission

logger = logging.getLogger(__name__)

router = APIRouter()


def _get_client_info(request: Request) -> tuple[str, str]:
    """Extract IP address and user agent from request."""
    ip = request.client.host if request.client else ""
    ua = request.headers.get("User-Agent", "")[:500]
    return ip, ua


@router.get("/tenants/{tenant_id}", response_model=TenantBillingResponse)
@limiter.limit("10/minute")
async def get_tenant_billing(
    request: Request,
    tenant_id: UUID,
    admin: AdminUser = Depends(require_permission("billing.manage")),
    db: AsyncSession = Depends(get_db),
) -> TenantBillingResponse:
    """Get billing info for a tenant (Stripe customer, subscription, invoices)."""
    try:
        return await admin_billing_service.get_tenant_billing(
            str(tenant_id), db,
        )
    except TenantNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tenant not found",
        )
    except BillingError as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(e),
        )


@router.post("/refund", response_model=RefundResponse)
@limiter.limit("5/minute")
async def issue_refund(
    request: Request,
    body: RefundRequest,
    admin: AdminUser = Depends(require_permission("billing.manage")),
    db: AsyncSession = Depends(get_db),
) -> RefundResponse:
    """Issue a full or partial refund for a payment intent."""
    try:
        result = await admin_billing_service.refund_payment(
            payment_intent_id=body.payment_intent_id,
            amount_cents=body.amount_cents,
            reason=body.reason,
        )
    except BillingError as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(e),
        )

    ip, ua = _get_client_info(request)
    await audit_service.log_action(
        db,
        admin_user_id=admin.id,
        action="billing.refund",
        entity_type="payment",
        details={
            "payment_intent_id": body.payment_intent_id,
            "amount_cents": body.amount_cents,
            "reason": body.reason,
            "refund_id": result["refund_id"],
        },
        ip_address=ip,
        user_agent=ua,
    )
    await db.commit()

    return RefundResponse(
        refund_id=str(result["refund_id"]),
        amount=int(result["amount"]),
        status=str(result["status"]),
        reason=body.reason,
    )


@router.post("/subscriptions/{subscription_id}/cancel")
@limiter.limit("5/minute")
async def cancel_subscription(
    request: Request,
    subscription_id: str,
    body: CancelSubscriptionRequest,
    admin: AdminUser = Depends(require_permission("billing.manage")),
    db: AsyncSession = Depends(get_db),
) -> dict[str, str | bool]:
    """Cancel a Stripe subscription (immediately or at period end)."""
    try:
        result = await admin_billing_service.cancel_subscription(
            subscription_id=subscription_id,
            at_period_end=body.at_period_end,
        )
    except BillingError as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(e),
        )

    ip, ua = _get_client_info(request)
    await audit_service.log_action(
        db,
        admin_user_id=admin.id,
        action="billing.cancel_subscription",
        entity_type="subscription",
        details={
            "subscription_id": subscription_id,
            "at_period_end": body.at_period_end,
            "reason": body.reason,
        },
        ip_address=ip,
        user_agent=ua,
    )
    await db.commit()

    return result


@router.post("/customers/{customer_id}/credit")
@limiter.limit("5/minute")
async def grant_credit(
    request: Request,
    customer_id: str,
    body: GrantCreditRequest,
    admin: AdminUser = Depends(require_permission("billing.manage")),
    db: AsyncSession = Depends(get_db),
) -> dict[str, str | int]:
    """Grant account credit to a Stripe customer."""
    try:
        result = await admin_billing_service.grant_credit(
            customer_id=customer_id,
            amount_cents=body.amount_cents,
            description=body.description,
        )
    except BillingError as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(e),
        )

    ip, ua = _get_client_info(request)
    await audit_service.log_action(
        db,
        admin_user_id=admin.id,
        action="billing.grant_credit",
        entity_type="customer",
        details={
            "customer_id": customer_id,
            "amount_cents": body.amount_cents,
            "description": body.description,
        },
        ip_address=ip,
        user_agent=ua,
    )
    await db.commit()

    return result
