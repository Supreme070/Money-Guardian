"""Subscription endpoints - all tenant-scoped."""

from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUserDep, DbSessionDep
from app.schemas.subscription import (
    SubscriptionCreate,
    SubscriptionListResponse,
    SubscriptionResponse,
    SubscriptionUpdate,
)
from app.services.subscription_service import (
    SubscriptionNotFoundError,
    SubscriptionService,
)

router = APIRouter()


@router.post(
    "",
    response_model=SubscriptionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_subscription(
    request: SubscriptionCreate,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> SubscriptionResponse:
    """
    Create a new subscription.

    Subscription is scoped to user's tenant.
    """
    service = SubscriptionService(db)

    subscription = await service.create(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        request=request,
    )

    return SubscriptionResponse.model_validate(subscription)


@router.get("", response_model=SubscriptionListResponse)
async def list_subscriptions(
    current_user: CurrentUserDep,
    db: DbSessionDep,
    include_inactive: bool = False,
) -> SubscriptionListResponse:
    """
    List all subscriptions for current user.

    Returns subscriptions with monthly/yearly totals.
    """
    service = SubscriptionService(db)

    return await service.list(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        include_inactive=include_inactive,
    )


@router.get("/{subscription_id}", response_model=SubscriptionResponse)
async def get_subscription(
    subscription_id: UUID,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> SubscriptionResponse:
    """
    Get subscription by ID.

    Only returns subscription if it belongs to user's tenant.
    """
    service = SubscriptionService(db)

    try:
        subscription = await service.get_by_id(
            tenant_id=current_user.tenant_id,
            subscription_id=subscription_id,
        )
    except SubscriptionNotFoundError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )

    return SubscriptionResponse.model_validate(subscription)


@router.patch("/{subscription_id}", response_model=SubscriptionResponse)
async def update_subscription(
    subscription_id: UUID,
    request: SubscriptionUpdate,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> SubscriptionResponse:
    """
    Update subscription.

    Only updates subscription if it belongs to user's tenant.
    """
    service = SubscriptionService(db)

    try:
        subscription = await service.update(
            tenant_id=current_user.tenant_id,
            subscription_id=subscription_id,
            request=request,
        )
    except SubscriptionNotFoundError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )

    return SubscriptionResponse.model_validate(subscription)


@router.delete("/{subscription_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_subscription(
    subscription_id: UUID,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> None:
    """
    Delete subscription.

    Soft deletes subscription if it belongs to user's tenant.
    """
    service = SubscriptionService(db)

    try:
        await service.delete(
            tenant_id=current_user.tenant_id,
            subscription_id=subscription_id,
        )
    except SubscriptionNotFoundError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
