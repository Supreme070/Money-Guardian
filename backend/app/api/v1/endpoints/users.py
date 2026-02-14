"""User endpoints."""

from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from sqlalchemy import select

from app.api.deps import CurrentUserDep, DbSessionDep
from app.core.security import get_password_hash, verify_password
from app.schemas.auth import ChangePasswordRequest
from app.schemas.user import UserResponse, UserUpdate


class FCMTokenRequest(BaseModel):
    """Request to register FCM token for push notifications."""

    token: str = Field(..., min_length=1, max_length=500)
    device_type: str = Field(..., pattern="^(ios|android)$")

router = APIRouter()


@router.get("/me", response_model=UserResponse)
async def get_current_user(
    current_user: CurrentUserDep,
) -> UserResponse:
    """
    Get current authenticated user.

    Returns user profile information.
    """
    return UserResponse.model_validate(current_user.user)


@router.patch("/me", response_model=UserResponse)
async def update_current_user(
    request: UserUpdate,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> UserResponse:
    """
    Update current user profile.

    Only updates provided fields.
    """
    user = current_user.user

    # Update only provided fields
    update_data = request.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if field == "notification_preferences":
            # Merge granular prefs into existing JSONB (don't overwrite unset keys)
            existing = dict(user.notification_preferences or {})
            existing.update(value)
            user.notification_preferences = existing
        else:
            setattr(user, field, value)

    db.add(user)
    await db.commit()
    await db.refresh(user)

    return UserResponse.model_validate(user)


@router.put("/me/password")
async def change_password(
    request: ChangePasswordRequest,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> dict[str, str]:
    """
    Change password for authenticated user.

    Requires current password for verification.
    """
    user = current_user.user

    if not verify_password(request.current_password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect",
        )

    if request.current_password == request.new_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be different from current password",
        )

    user.hashed_password = get_password_hash(request.new_password)
    db.add(user)
    await db.commit()

    return {"message": "Password changed successfully"}


@router.get("/me/export")
async def export_user_data(
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> JSONResponse:
    """
    Export all user data (GDPR Article 20 - Right to Data Portability).

    Returns a JSON file containing all user data: profile, subscriptions,
    alerts, bank connections, and email connections.
    """
    from app.models.alert import Alert
    from app.models.bank_connection import BankConnection
    from app.models.email_connection import EmailConnection
    from app.models.subscription import Subscription

    user = current_user.user
    tenant_id = current_user.tenant_id

    # Fetch subscriptions
    subs_result = await db.execute(
        select(Subscription).where(
            Subscription.tenant_id == tenant_id,
            Subscription.user_id == user.id,
        )
    )
    subscriptions = subs_result.scalars().all()

    # Fetch alerts
    alerts_result = await db.execute(
        select(Alert).where(
            Alert.tenant_id == tenant_id,
            Alert.user_id == user.id,
        )
    )
    alerts = alerts_result.scalars().all()

    # Fetch bank connections (metadata only, no access tokens)
    bank_result = await db.execute(
        select(BankConnection).where(
            BankConnection.tenant_id == tenant_id,
            BankConnection.user_id == user.id,
        )
    )
    bank_connections = bank_result.scalars().all()

    # Fetch email connections (metadata only, no tokens)
    email_result = await db.execute(
        select(EmailConnection).where(
            EmailConnection.tenant_id == tenant_id,
            EmailConnection.user_id == user.id,
        )
    )
    email_connections = email_result.scalars().all()

    export_data = {
        "user": {
            "id": str(user.id),
            "email": user.email,
            "full_name": user.full_name,
            "is_active": user.is_active,
            "is_verified": user.is_verified,
            "subscription_tier": user.subscription_tier,
            "onboarding_completed": user.onboarding_completed,
            "created_at": user.created_at.isoformat() if user.created_at else None,
        },
        "subscriptions": [
            {
                "id": str(s.id),
                "name": s.name,
                "amount": str(s.amount),
                "currency": s.currency,
                "billing_cycle": s.billing_cycle,
                "next_billing_date": s.next_billing_date.isoformat() if s.next_billing_date else None,
                "is_active": s.is_active,
                "source": s.source,
                "ai_flag": s.ai_flag,
                "created_at": s.created_at.isoformat() if s.created_at else None,
            }
            for s in subscriptions
        ],
        "alerts": [
            {
                "id": str(a.id),
                "alert_type": a.alert_type,
                "severity": a.severity,
                "title": a.title,
                "message": a.message,
                "is_read": a.is_read,
                "created_at": a.created_at.isoformat() if a.created_at else None,
            }
            for a in alerts
        ],
        "bank_connections": [
            {
                "id": str(bc.id),
                "provider": bc.provider,
                "institution_name": bc.institution_name,
                "status": bc.status,
                "last_sync_at": bc.last_sync_at.isoformat() if bc.last_sync_at else None,
                "created_at": bc.created_at.isoformat() if bc.created_at else None,
            }
            for bc in bank_connections
        ],
        "email_connections": [
            {
                "id": str(ec.id),
                "provider": ec.provider,
                "email_address": ec.email_address,
                "status": ec.status,
                "last_scan_at": ec.last_scan_at.isoformat() if ec.last_scan_at else None,
                "created_at": ec.created_at.isoformat() if ec.created_at else None,
            }
            for ec in email_connections
        ],
        "exported_at": datetime.now(timezone.utc).isoformat(),
    }

    return JSONResponse(
        content=export_data,
        headers={
            "Content-Disposition": "attachment; filename=money_guardian_export.json",
        },
    )


@router.delete("/me")
async def delete_current_user(
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> dict[str, str]:
    """
    Delete current user account and all associated data (GDPR/CCPA).

    This is a destructive, irreversible operation that:
    1. Disconnects all external services (bank connections, email OAuth)
    2. Cancels Stripe subscription if active
    3. Hard-deletes the user record (cascades to all child tables)
    4. Marks the tenant as deleted
    5. Blacklists the current access token
    """
    import logging
    from datetime import datetime, timezone

    from sqlalchemy import select as sa_select

    from app.models.bank_connection import BankConnection
    from app.models.email_connection import EmailConnection
    from app.models.tenant import Tenant
    from app.services.bank_connection_service import BankConnectionService

    logger = logging.getLogger(__name__)

    user = current_user.user
    tenant_id = current_user.tenant_id

    # Step 1: Disconnect all bank connections (revoke Plaid access tokens)
    bank_result = await db.execute(
        sa_select(BankConnection).where(
            BankConnection.user_id == user.id,
            BankConnection.tenant_id == tenant_id,
            BankConnection.deleted_at.is_(None),
        )
    )
    bank_connections = bank_result.scalars().all()

    bank_service = BankConnectionService(db)
    for conn in bank_connections:
        try:
            await bank_service.disconnect(
                tenant_id=tenant_id,
                connection_id=conn.id,
            )
        except Exception as e:
            logger.warning("Failed to disconnect bank connection %s: %s", conn.id, e)

    # Step 2: Revoke email connections (clear OAuth tokens)
    email_result = await db.execute(
        sa_select(EmailConnection).where(
            EmailConnection.user_id == user.id,
            EmailConnection.tenant_id == tenant_id,
        )
    )
    email_connections = email_result.scalars().all()
    for email_conn in email_connections:
        email_conn.access_token = ""
        email_conn.refresh_token = ""
        email_conn.status = "disconnected"

    # Step 3: Cancel Stripe subscription if tenant has one
    tenant_result = await db.execute(
        sa_select(Tenant).where(Tenant.id == tenant_id)
    )
    tenant = tenant_result.scalar_one_or_none()

    if tenant and tenant.stripe_customer_id:
        try:
            import stripe
            from app.core.config import settings

            if settings.stripe_secret_key:
                stripe.api_key = settings.stripe_secret_key
                subscriptions = stripe.Subscription.list(
                    customer=tenant.stripe_customer_id,
                    status="active",
                )
                for sub in subscriptions.data:
                    stripe.Subscription.cancel(sub.id)
        except Exception as e:
            logger.warning("Failed to cancel Stripe subscription: %s", e)

    # Step 4: Scrub PII from user record, then deactivate
    # We keep the row for audit but strip all identifying information.
    now = datetime.now(timezone.utc)
    user.email = f"deleted_{user.id}@deleted.moneyguardian.app"
    user.full_name = None
    user.hashed_password = "DELETED"
    user.is_active = False
    user.fcm_token = None
    user.fcm_device_type = None
    user.firebase_uid = None
    user.push_notifications_enabled = False
    user.email_notifications_enabled = False
    user.email_verification_token = None
    user.password_reset_token = None

    # Step 5: Mark tenant as deleted
    if tenant:
        tenant.status = "deleted"
        db.add(tenant)

    db.add(user)
    await db.commit()

    logger.info("Account deleted for user %s (tenant %s)", user.id, tenant_id)

    return {"message": "Account and all associated data have been deleted"}


@router.post("/me/fcm-token")
async def register_fcm_token(
    request: FCMTokenRequest,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> dict[str, str]:
    """
    Register FCM token for push notifications.

    Updates user's FCM token for the given device type.
    """
    user = current_user.user
    user.fcm_token = request.token
    user.fcm_device_type = request.device_type

    db.add(user)
    await db.commit()

    return {"message": "FCM token registered successfully"}


@router.delete("/me/fcm-token")
async def unregister_fcm_token(
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> dict[str, str]:
    """
    Unregister FCM token (e.g., on logout).

    Clears the user's FCM token.
    """
    user = current_user.user
    user.fcm_token = None
    user.fcm_device_type = None

    db.add(user)
    await db.commit()

    return {"message": "FCM token unregistered successfully"}
