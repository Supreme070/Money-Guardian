"""Subscription endpoints - all tenant-scoped."""

from uuid import UUID

import orjson
from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUserDep, DbSessionDep
from app.core.cache import cache_delete, cache_get, cache_set
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

# Cache TTLs in seconds
_SUBS_CACHE_TTL = 600  # 10 minutes


async def _invalidate_sub_caches(tenant_id: UUID, user_id: UUID) -> None:
    """Invalidate subscription list and pulse caches after any mutation."""
    await cache_delete(f"subs:{tenant_id}:{user_id}")
    await cache_delete(f"pulse:{tenant_id}:{user_id}")


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

    await _invalidate_sub_caches(current_user.tenant_id, current_user.user_id)

    return SubscriptionResponse.model_validate(subscription)


@router.get("", response_model=SubscriptionListResponse)
async def list_subscriptions(
    current_user: CurrentUserDep,
    db: DbSessionDep,
    include_inactive: bool = False,
    include_deleted: bool = False,
) -> SubscriptionListResponse:
    """
    List all subscriptions for current user.

    Returns subscriptions with monthly/yearly totals.

    Args:
        include_inactive: Include cancelled/inactive subscriptions.
        include_deleted: Include soft-deleted subscriptions (for history view).
    """
    # Only cache the default (active-only, non-deleted) list
    cache_key = f"subs:{current_user.tenant_id}:{current_user.user_id}"
    is_default_query = not include_inactive and not include_deleted
    if is_default_query:
        cached = await cache_get(cache_key)
        if cached is not None:
            return SubscriptionListResponse.model_validate(orjson.loads(cached))

    service = SubscriptionService(db)

    result = await service.list(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        include_inactive=include_inactive,
        include_deleted=include_deleted,
    )

    if is_default_query:
        await cache_set(cache_key, result.model_dump(mode="json"), _SUBS_CACHE_TTL)

    return result


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

    await _invalidate_sub_caches(current_user.tenant_id, current_user.user_id)

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

    await _invalidate_sub_caches(current_user.tenant_id, current_user.user_id)


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

    await _invalidate_sub_caches(current_user.tenant_id, current_user.user_id)

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
