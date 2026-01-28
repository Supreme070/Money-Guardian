"""User endpoints."""

from fastapi import APIRouter
from pydantic import BaseModel, Field

from app.api.deps import CurrentUserDep, DbSessionDep
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
        setattr(user, field, value)

    db.add(user)
    await db.commit()
    await db.refresh(user)

    return UserResponse.model_validate(user)


@router.delete("/me")
async def delete_current_user(
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> dict[str, str]:
    """
    Delete current user account.

    Soft deletes user and marks tenant as deleted.
    """
    user = current_user.user
    user.is_active = False

    # Soft-delete the tenant as well
    from sqlalchemy import select as sa_select
    from app.models.tenant import Tenant

    tenant_result = await db.execute(
        sa_select(Tenant).where(Tenant.id == current_user.tenant_id)
    )
    tenant = tenant_result.scalar_one_or_none()
    if tenant:
        tenant.status = "deleted"
        db.add(tenant)

    db.add(user)
    await db.commit()

    return {"message": "Account deleted successfully"}


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
