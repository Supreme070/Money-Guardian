"""Alert endpoints - all tenant-scoped."""

from datetime import datetime, timezone
from uuid import UUID

import orjson
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select, func

from app.api.deps import CurrentUserDep, DbSessionDep
from app.core.cache import cache_delete, cache_get, cache_set
from app.models.alert import Alert
from app.schemas.alert import AlertListResponse, AlertMarkRead, AlertResponse

router = APIRouter()

# Cache TTLs in seconds
_ALERTS_CACHE_TTL = 120  # 2 minutes


async def _invalidate_alert_caches(tenant_id: UUID, user_id: UUID) -> None:
    """Invalidate alert list and pulse caches after mutation."""
    await cache_delete(f"alerts:{tenant_id}:{user_id}")
    # Pulse shows unread_alerts_count, so invalidate it too
    await cache_delete(f"pulse:{tenant_id}:{user_id}")


@router.get("", response_model=AlertListResponse)
async def list_alerts(
    current_user: CurrentUserDep,
    db: DbSessionDep,
    unread_only: bool = False,
) -> AlertListResponse:
    """
    List all alerts for current user.

    CRITICAL: Filtered by tenant_id from JWT.
    """
    # Only cache the default (all non-dismissed) list
    cache_key = f"alerts:{current_user.tenant_id}:{current_user.user_id}"
    if not unread_only:
        cached = await cache_get(cache_key)
        if cached is not None:
            return AlertListResponse.model_validate(orjson.loads(cached))

    query = select(Alert).where(
        Alert.tenant_id == current_user.tenant_id,
        Alert.user_id == current_user.user_id,
        Alert.is_dismissed == False,
    )

    if unread_only:
        query = query.where(Alert.is_read == False)

    query = query.order_by(Alert.created_at.desc())

    result = await db.execute(query)
    alerts = list(result.scalars().all())

    # Calculate counts
    unread_count = sum(1 for a in alerts if not a.is_read)
    critical_count = sum(1 for a in alerts if a.severity == "critical")

    response = AlertListResponse(
        alerts=[AlertResponse.model_validate(a) for a in alerts],
        total_count=len(alerts),
        unread_count=unread_count,
        critical_count=critical_count,
    )

    if not unread_only:
        await cache_set(cache_key, response.model_dump(mode="json"), _ALERTS_CACHE_TTL)

    return response


@router.get("/{alert_id}", response_model=AlertResponse)
async def get_alert(
    alert_id: UUID,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> AlertResponse:
    """
    Get alert by ID.

    CRITICAL: Filtered by tenant_id from JWT.
    """
    result = await db.execute(
        select(Alert).where(
            Alert.id == alert_id,
            Alert.tenant_id == current_user.tenant_id,
        )
    )
    alert = result.scalar_one_or_none()

    if alert is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Alert {alert_id} not found",
        )

    return AlertResponse.model_validate(alert)


@router.post("/mark-read")
async def mark_alerts_read(
    request: AlertMarkRead,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> dict[str, int]:
    """
    Mark alerts as read.

    CRITICAL: Only marks alerts belonging to user's tenant.
    """
    now = datetime.now(timezone.utc)
    updated_count = 0

    for alert_id in request.alert_ids:
        result = await db.execute(
            select(Alert).where(
                Alert.id == alert_id,
                Alert.tenant_id == current_user.tenant_id,
                Alert.user_id == current_user.user_id,
            )
        )
        alert = result.scalar_one_or_none()

        if alert is not None and not alert.is_read:
            alert.is_read = True
            alert.read_at = now
            db.add(alert)
            updated_count += 1

    await db.commit()

    if updated_count > 0:
        await _invalidate_alert_caches(current_user.tenant_id, current_user.user_id)

    return {"marked_read": updated_count}


@router.post("/{alert_id}/dismiss")
async def dismiss_alert(
    alert_id: UUID,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> dict[str, str]:
    """
    Dismiss an alert.

    CRITICAL: Only dismisses alerts belonging to user's tenant.
    """
    result = await db.execute(
        select(Alert).where(
            Alert.id == alert_id,
            Alert.tenant_id == current_user.tenant_id,
            Alert.user_id == current_user.user_id,
        )
    )
    alert = result.scalar_one_or_none()

    if alert is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Alert {alert_id} not found",
        )

    alert.is_dismissed = True
    alert.dismissed_at = datetime.now(timezone.utc)
    db.add(alert)
    await db.commit()

    await _invalidate_alert_caches(current_user.tenant_id, current_user.user_id)

    return {"message": "Alert dismissed"}
