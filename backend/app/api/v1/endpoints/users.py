"""User endpoints."""

from fastapi import APIRouter

from app.api.deps import CurrentUserDep, DbSessionDep
from app.schemas.user import UserResponse, UserUpdate

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
    # TODO: Also mark tenant as deleted

    db.add(user)
    await db.commit()

    return {"message": "Account deleted successfully"}
