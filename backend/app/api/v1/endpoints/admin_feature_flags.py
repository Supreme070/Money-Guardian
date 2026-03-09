"""Admin feature flag management + user-facing flag evaluation.

Admin endpoints require ``feature_flags.manage`` permission.
The user-facing ``/feature-flags`` endpoint uses normal user auth.
"""

import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUserDep
from app.core.rate_limit import limiter
from app.db.session import get_db
from app.models.admin_user import AdminUser
from app.schemas.admin_flags import (
    FeatureFlagCreateRequest,
    FeatureFlagEvaluation,
    FeatureFlagListResponse,
    FeatureFlagResponse,
    FeatureFlagUpdateRequest,
)
from app.services import audit_service
from app.services.feature_flag_service import (
    FlagKeyExistsError,
    FlagNotFoundError,
    create_flag,
    delete_flag,
    evaluate_flags_for_user,
    get_flag,
    list_flags,
    update_flag,
)
from app.services.rbac_service import require_permission

logger = logging.getLogger(__name__)

router = APIRouter()


# ---------------------------------------------------------------------------
# Admin endpoints (feature_flags.manage)
# ---------------------------------------------------------------------------


@router.post("/admin/feature-flags", response_model=FeatureFlagResponse, tags=["Admin Feature Flags"])
@limiter.limit("5/minute")
async def admin_create_flag(
    request: Request,
    body: FeatureFlagCreateRequest,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("feature_flags.manage")),
) -> FeatureFlagResponse:
    """Create a new feature flag."""
    try:
        flag = await create_flag(db, admin, body)
    except FlagKeyExistsError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Flag key '{body.key}' already exists",
        )

    ip = request.client.host if request.client else ""
    ua = request.headers.get("User-Agent", "")[:500]
    await audit_service.log_action(
        db,
        admin_user_id=admin.id,
        action="feature_flag.create",
        entity_type="feature_flag",
        entity_id=flag.id,
        details={"key": flag.key, "is_enabled": flag.is_enabled},
        ip_address=ip,
        user_agent=ua,
    )

    return FeatureFlagResponse.model_validate(flag)


@router.get("/admin/feature-flags", response_model=FeatureFlagListResponse, tags=["Admin Feature Flags"])
@limiter.limit("5/minute")
async def admin_list_flags(
    request: Request,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("feature_flags.manage")),
) -> FeatureFlagListResponse:
    """List all feature flags."""
    flags = await list_flags(db)
    return FeatureFlagListResponse(
        flags=[FeatureFlagResponse.model_validate(f) for f in flags],
        total_count=len(flags),
    )


@router.get("/admin/feature-flags/{flag_id}", response_model=FeatureFlagResponse, tags=["Admin Feature Flags"])
@limiter.limit("5/minute")
async def admin_get_flag(
    request: Request,
    flag_id: UUID,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("feature_flags.manage")),
) -> FeatureFlagResponse:
    """Get a single feature flag."""
    try:
        flag = await get_flag(db, flag_id)
    except FlagNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Feature flag not found",
        )
    return FeatureFlagResponse.model_validate(flag)


@router.put("/admin/feature-flags/{flag_id}", response_model=FeatureFlagResponse, tags=["Admin Feature Flags"])
@limiter.limit("5/minute")
async def admin_update_flag(
    request: Request,
    flag_id: UUID,
    body: FeatureFlagUpdateRequest,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("feature_flags.manage")),
) -> FeatureFlagResponse:
    """Update a feature flag."""
    try:
        flag = await update_flag(db, flag_id, body)
    except FlagNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Feature flag not found",
        )

    ip = request.client.host if request.client else ""
    ua = request.headers.get("User-Agent", "")[:500]
    await audit_service.log_action(
        db,
        admin_user_id=admin.id,
        action="feature_flag.update",
        entity_type="feature_flag",
        entity_id=flag.id,
        details=body.model_dump(exclude_unset=True),
        ip_address=ip,
        user_agent=ua,
    )

    return FeatureFlagResponse.model_validate(flag)


@router.delete("/admin/feature-flags/{flag_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Admin Feature Flags"])
@limiter.limit("5/minute")
async def admin_delete_flag(
    request: Request,
    flag_id: UUID,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("feature_flags.manage")),
) -> None:
    """Delete a feature flag."""
    try:
        await delete_flag(db, flag_id)
    except FlagNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Feature flag not found",
        )

    ip = request.client.host if request.client else ""
    ua = request.headers.get("User-Agent", "")[:500]
    await audit_service.log_action(
        db,
        admin_user_id=admin.id,
        action="feature_flag.delete",
        entity_type="feature_flag",
        entity_id=flag_id,
        details={},
        ip_address=ip,
        user_agent=ua,
    )


# ---------------------------------------------------------------------------
# User-facing endpoint (normal user auth)
# ---------------------------------------------------------------------------


@router.get("/feature-flags", response_model=list[FeatureFlagEvaluation], tags=["Feature Flags"])
@limiter.limit("30/minute")
async def user_evaluate_flags(
    request: Request,
    current_user: CurrentUserDep,
    db: AsyncSession = Depends(get_db),
) -> list[FeatureFlagEvaluation]:
    """Evaluate all feature flags for the current user.

    Returns which flags are enabled/disabled for this specific user
    based on their tier, user ID, and rollout percentage.
    """
    evaluations = await evaluate_flags_for_user(
        db,
        user_id=str(current_user.user_id),
        user_tier=current_user.user.subscription_tier,
    )
    return [
        FeatureFlagEvaluation(
            key=str(e["key"]),
            enabled=bool(e["enabled"]),
        )
        for e in evaluations
    ]
