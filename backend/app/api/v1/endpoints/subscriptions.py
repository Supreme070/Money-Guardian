"""Subscription endpoints - all tenant-scoped."""

from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUserDep, DbSessionDep
from app.schemas.subscription import (
    SubscriptionCreate,
    SubscriptionListResponse,
    SubscriptionResponse,
    SubscriptionUpdate,
    AIFlagSummaryResponse,
    AnalyzeResponse,
)
from app.services.subscription_service import (
    SubscriptionNotFoundError,
    SubscriptionService,
)
from app.services.tier_service import TierService
from app.services.ai_flag_service import AIFlagService, get_flag_summary

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
    Free tier limited to 5 manual subscriptions.
    """
    # Check tier limits before creating
    tier_service = TierService(db)
    check_result = await tier_service.check_can_add_subscription(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
    )

    if not check_result.allowed:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={
                "message": check_result.reason,
                "upgrade_required": check_result.upgrade_required,
                "current_count": check_result.current_count,
                "limit": check_result.limit,
            },
        )

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


@router.post("/analyze", response_model=AnalyzeResponse)
async def analyze_subscriptions(
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> AnalyzeResponse:
    """
    Analyze all subscriptions and apply AI flags.

    Scans subscriptions for:
    - Unused: Not used in 30+ days
    - Duplicate: Similar to another subscription
    - Price Increase: Amount increased from previous
    - Trial Ending: Free trial ending within 7 days
    - Forgotten: Added 90+ days ago with no interaction

    Returns the count of flagged subscriptions.
    """
    service = AIFlagService(db)

    flagged_count = await service.apply_flags(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
    )

    message = (
        f"Analysis complete. Found {flagged_count} subscription{'s' if flagged_count != 1 else ''} "
        "that may need attention."
        if flagged_count > 0
        else "Analysis complete. All subscriptions look good!"
    )

    return AnalyzeResponse(
        flagged_count=flagged_count,
        message=message,
    )


@router.get("/flags/summary", response_model=AIFlagSummaryResponse)
async def get_ai_flag_summary(
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> AIFlagSummaryResponse:
    """
    Get AI flag summary for current user's subscriptions.

    Returns breakdown of flags by type and potential savings.
    """
    summary = await get_flag_summary(
        db=db,
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
    )

    return AIFlagSummaryResponse(
        total_subscriptions=summary.total_subscriptions,
        flagged_count=summary.flagged_count,
        unused_count=summary.unused_count,
        duplicate_count=summary.duplicate_count,
        price_increase_count=summary.price_increase_count,
        trial_ending_count=summary.trial_ending_count,
        forgotten_count=summary.forgotten_count,
        potential_monthly_savings=float(summary.potential_monthly_savings),
    )
