"""Admin notification endpoints.

Allows admins to send push/email notifications to users, tiers, or all
users, and to view notification history.
"""

import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.rate_limit import limiter
from app.db.session import get_db
from app.models.admin_user import AdminUser
from app.schemas.admin_notifications import (
    NotificationListResponse,
    NotificationResponse,
    SendNotificationRequest,
)
from app.services import admin_notification_service, audit_service
from app.services.rbac_service import require_permission

logger = logging.getLogger(__name__)

router = APIRouter()


def _get_client_info(request: Request) -> tuple[str, str]:
    """Extract IP address and user agent from request."""
    ip = request.client.host if request.client else ""
    ua = request.headers.get("User-Agent", "")[:500]
    return ip, ua


@router.post("/", response_model=NotificationResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("10/minute")
async def send_notification(
    request: Request,
    body: SendNotificationRequest,
    admin: AdminUser = Depends(require_permission("notifications.send")),
    db: AsyncSession = Depends(get_db),
) -> NotificationResponse:
    """Send a notification to users, a tier, or all users."""
    # Validate target-specific fields
    if body.target_type == "user" and not body.target_ids:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="target_ids is required when target_type is 'user'",
        )
    if body.target_type == "tier" and not body.target_tier:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="target_tier is required when target_type is 'tier'",
        )

    notification = await admin_notification_service.send_notification(
        db, admin=admin, request=body,
    )

    ip, ua = _get_client_info(request)
    await audit_service.log_action(
        db,
        admin_user_id=admin.id,
        action="notification.send",
        entity_type="admin_notification",
        entity_id=notification.id,
        details={
            "notification_type": body.notification_type,
            "target_type": body.target_type,
            "target_count": len(notification.target_ids),
            "title": body.title,
        },
        ip_address=ip,
        user_agent=ua,
    )
    await db.commit()

    return NotificationResponse(
        id=notification.id,
        admin_user_id=notification.admin_user_id,
        notification_type=notification.notification_type,
        target_type=notification.target_type,
        target_ids=notification.target_ids,
        target_tier=notification.target_tier,
        title=notification.title,
        body=notification.body,
        sent_count=notification.sent_count,
        failed_count=notification.failed_count,
        status=notification.status,
        created_at=notification.created_at,
    )


@router.get("/", response_model=NotificationListResponse)
@limiter.limit("10/minute")
async def list_notifications(
    request: Request,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    admin: AdminUser = Depends(require_permission("notifications.send")),
    db: AsyncSession = Depends(get_db),
) -> NotificationListResponse:
    """List all admin notifications with pagination."""
    notifications, total_count = await admin_notification_service.list_notifications(
        db, page=page, page_size=page_size,
    )

    return NotificationListResponse(
        notifications=[
            NotificationResponse(
                id=n.id,
                admin_user_id=n.admin_user_id,
                notification_type=n.notification_type,
                target_type=n.target_type,
                target_ids=n.target_ids,
                target_tier=n.target_tier,
                title=n.title,
                body=n.body,
                sent_count=n.sent_count,
                failed_count=n.failed_count,
                status=n.status,
                created_at=n.created_at,
            )
            for n in notifications
        ],
        total_count=total_count,
    )


@router.get("/{notification_id}", response_model=NotificationResponse)
@limiter.limit("10/minute")
async def get_notification(
    request: Request,
    notification_id: UUID,
    admin: AdminUser = Depends(require_permission("notifications.send")),
    db: AsyncSession = Depends(get_db),
) -> NotificationResponse:
    """Get a single notification detail."""
    notification = await admin_notification_service.get_notification(
        db, notification_id,
    )
    if notification is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found",
        )

    return NotificationResponse(
        id=notification.id,
        admin_user_id=notification.admin_user_id,
        notification_type=notification.notification_type,
        target_type=notification.target_type,
        target_ids=notification.target_ids,
        target_tier=notification.target_tier,
        title=notification.title,
        body=notification.body,
        sent_count=notification.sent_count,
        failed_count=notification.failed_count,
        status=notification.status,
        created_at=notification.created_at,
    )
