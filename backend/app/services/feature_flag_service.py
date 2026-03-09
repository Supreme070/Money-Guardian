"""Feature flag service for creation, evaluation, and management.

Flags support:
- Global enable/disable
- Percentage-based rollout (deterministic hash of user_id)
- Tier targeting (e.g. only pro users)
- User-ID targeting (allowlist)
"""

import hashlib
import logging
from uuid import UUID

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.admin_user import AdminUser
from app.models.feature_flag import FeatureFlag
from app.schemas.admin_flags import (
    FeatureFlagCreateRequest,
    FeatureFlagUpdateRequest,
)

logger = logging.getLogger(__name__)


class FlagNotFoundError(Exception):
    """Raised when a feature flag is not found."""


class FlagKeyExistsError(Exception):
    """Raised when a feature flag key already exists."""


async def create_flag(
    db: AsyncSession,
    admin: AdminUser,
    request: FeatureFlagCreateRequest,
) -> FeatureFlag:
    """Create a new feature flag."""
    # Check for duplicate key
    existing = await db.execute(
        select(FeatureFlag).where(FeatureFlag.key == request.key)
    )
    if existing.scalar_one_or_none() is not None:
        raise FlagKeyExistsError(f"Flag key '{request.key}' already exists")

    flag = FeatureFlag(
        key=request.key,
        name=request.name,
        description=request.description,
        is_enabled=request.is_enabled,
        rollout_percentage=request.rollout_percentage,
        target_tiers=request.target_tiers,
        target_user_ids=request.target_user_ids,
        created_by=admin.id,
    )
    db.add(flag)
    await db.flush()

    logger.info("Feature flag created: key=%s by admin=%s", flag.key, admin.id)
    return flag


async def update_flag(
    db: AsyncSession,
    flag_id: UUID,
    request: FeatureFlagUpdateRequest,
) -> FeatureFlag:
    """Update an existing feature flag."""
    result = await db.execute(
        select(FeatureFlag).where(FeatureFlag.id == flag_id)
    )
    flag = result.scalar_one_or_none()
    if flag is None:
        raise FlagNotFoundError(f"Flag {flag_id} not found")

    update_data = request.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(flag, field, value)

    db.add(flag)
    await db.flush()

    logger.info("Feature flag updated: id=%s key=%s", flag.id, flag.key)
    return flag


async def delete_flag(db: AsyncSession, flag_id: UUID) -> None:
    """Delete a feature flag."""
    result = await db.execute(
        select(FeatureFlag).where(FeatureFlag.id == flag_id)
    )
    flag = result.scalar_one_or_none()
    if flag is None:
        raise FlagNotFoundError(f"Flag {flag_id} not found")

    await db.execute(delete(FeatureFlag).where(FeatureFlag.id == flag_id))
    await db.flush()

    logger.info("Feature flag deleted: id=%s key=%s", flag_id, flag.key)


async def list_flags(db: AsyncSession) -> list[FeatureFlag]:
    """List all feature flags ordered by creation date."""
    result = await db.execute(
        select(FeatureFlag).order_by(FeatureFlag.created_at.desc())
    )
    return list(result.scalars().all())


async def get_flag(db: AsyncSession, flag_id: UUID) -> FeatureFlag:
    """Get a single feature flag by ID."""
    result = await db.execute(
        select(FeatureFlag).where(FeatureFlag.id == flag_id)
    )
    flag = result.scalar_one_or_none()
    if flag is None:
        raise FlagNotFoundError(f"Flag {flag_id} not found")
    return flag


def _user_in_rollout(user_id: str, flag_key: str, percentage: int) -> bool:
    """Deterministic check if a user falls within rollout percentage.

    Uses SHA-256 hash of (flag_key + user_id) to produce a stable
    bucket value 0-99.
    """
    if percentage >= 100:
        return True
    if percentage <= 0:
        return False

    digest = hashlib.sha256(f"{flag_key}:{user_id}".encode()).hexdigest()
    bucket = int(digest[:8], 16) % 100
    return bucket < percentage


async def is_flag_enabled(
    db: AsyncSession,
    flag_key: str,
    user_id: str,
    user_tier: str,
) -> bool:
    """Evaluate whether a flag is enabled for a specific user.

    Evaluation order:
    1. Check is_enabled (global kill switch)
    2. Check target_user_ids (explicit allowlist)
    3. Check target_tiers (tier-based targeting)
    4. Check rollout_percentage (gradual rollout)
    """
    result = await db.execute(
        select(FeatureFlag).where(FeatureFlag.key == flag_key)
    )
    flag = result.scalar_one_or_none()
    if flag is None:
        return False

    # Global kill switch
    if not flag.is_enabled:
        return False

    # Explicit user-ID targeting (if set, only those users get the flag)
    if flag.target_user_ids is not None and len(flag.target_user_ids) > 0:
        if user_id not in flag.target_user_ids:
            return False

    # Tier targeting (if set, only those tiers get the flag)
    if flag.target_tiers is not None and len(flag.target_tiers) > 0:
        if user_tier not in flag.target_tiers:
            return False

    # Rollout percentage
    if not _user_in_rollout(user_id, flag_key, flag.rollout_percentage):
        return False

    return True


async def evaluate_flags_for_user(
    db: AsyncSession,
    user_id: str,
    user_tier: str,
) -> list[dict[str, str | bool]]:
    """Evaluate all flags for a given user.

    Returns a list of {key, enabled} for every flag.
    """
    flags = await list_flags(db)
    results: list[dict[str, str | bool]] = []

    for flag in flags:
        enabled = False
        if flag.is_enabled:
            # Check user ID targeting
            user_ok = True
            if flag.target_user_ids is not None and len(flag.target_user_ids) > 0:
                if user_id not in flag.target_user_ids:
                    user_ok = False

            # Check tier targeting
            tier_ok = True
            if flag.target_tiers is not None and len(flag.target_tiers) > 0:
                if user_tier not in flag.target_tiers:
                    tier_ok = False

            # Check rollout
            rollout_ok = _user_in_rollout(
                user_id, flag.key, flag.rollout_percentage,
            )

            enabled = user_ok and tier_ok and rollout_ok

        results.append({"key": flag.key, "enabled": enabled})

    return results
