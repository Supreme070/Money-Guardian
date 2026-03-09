"""Admin bulk operations endpoints.

Allows admins with 'bulk_operations' permission to execute batch
user status changes, tier overrides, and notifications via Celery.
"""

import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints.admin_auth import get_current_admin
from app.core.rate_limit import limiter
from app.db.session import get_db
from app.models.admin_user import AdminUser
from app.schemas.admin_bulk import (
    BulkNotificationRequest,
    BulkOperationListResponse,
    BulkOperationResponse,
    BulkTierOverrideRequest,
    BulkUserStatusRequest,
)
from app.services import audit_service
from app.services.bulk_operation_service import (
    BulkOperationNotCancellableError,
    BulkOperationNotFoundError,
    cancel_operation,
    create_bulk_operation,
    get_operation,
    list_operations,
)
from app.services.rbac_service import require_permission

logger = logging.getLogger(__name__)

router = APIRouter()


def _operation_to_response(op) -> BulkOperationResponse:
    """Convert a BulkOperation model to response schema."""
    return BulkOperationResponse(
        id=str(op.id),
        admin_user_id=str(op.admin_user_id) if op.admin_user_id else None,
        operation_type=op.operation_type,
        target_count=op.target_count,
        processed_count=op.processed_count,
        failed_count=op.failed_count,
        status=op.status,
        parameters=op.parameters,
        result_url=op.result_url,
        error_message=op.error_message,
        started_at=op.started_at,
        completed_at=op.completed_at,
        created_at=op.created_at,
    )


@router.post("/user-status", response_model=BulkOperationResponse)
@limiter.limit("5/minute")
async def bulk_user_status(
    request: Request,
    body: BulkUserStatusRequest,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("bulk_operations")),
) -> BulkOperationResponse:
    """Bulk change user status (active/suspended/deleted).

    Creates a bulk operation record and dispatches a Celery task.
    """
    from app.tasks.bulk_tasks import execute_bulk_user_status

    operation = await create_bulk_operation(
        db,
        admin=admin,
        operation_type="user_status",
        target_count=len(body.user_ids),
        parameters={
            "user_ids": body.user_ids,
            "new_status": body.new_status,
            "reason": body.reason,
        },
    )

    ip = request.client.host if request.client else ""
    ua = request.headers.get("User-Agent", "")[:500]
    await audit_service.log_action(
        db,
        admin_user_id=admin.id,
        action="bulk.user_status",
        entity_type="bulk_operation",
        entity_id=operation.id,
        details={
            "target_count": len(body.user_ids),
            "new_status": body.new_status,
            "reason": body.reason,
        },
        ip_address=ip,
        user_agent=ua,
    )
    await db.commit()

    # Dispatch Celery task
    execute_bulk_user_status.delay(str(operation.id))

    return _operation_to_response(operation)


@router.post("/tier-override", response_model=BulkOperationResponse)
@limiter.limit("5/minute")
async def bulk_tier_override(
    request: Request,
    body: BulkTierOverrideRequest,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("bulk_operations")),
) -> BulkOperationResponse:
    """Bulk override tenant tier.

    Creates a bulk operation record and dispatches a Celery task.
    """
    from app.tasks.bulk_tasks import execute_bulk_tier_override

    operation = await create_bulk_operation(
        db,
        admin=admin,
        operation_type="tier_override",
        target_count=len(body.tenant_ids),
        parameters={
            "tenant_ids": body.tenant_ids,
            "new_tier": body.new_tier,
            "reason": body.reason,
        },
    )

    ip = request.client.host if request.client else ""
    ua = request.headers.get("User-Agent", "")[:500]
    await audit_service.log_action(
        db,
        admin_user_id=admin.id,
        action="bulk.tier_override",
        entity_type="bulk_operation",
        entity_id=operation.id,
        details={
            "target_count": len(body.tenant_ids),
            "new_tier": body.new_tier,
            "reason": body.reason,
        },
        ip_address=ip,
        user_agent=ua,
    )
    await db.commit()

    execute_bulk_tier_override.delay(str(operation.id))

    return _operation_to_response(operation)


@router.post("/notification", response_model=BulkOperationResponse)
@limiter.limit("5/minute")
async def bulk_notification(
    request: Request,
    body: BulkNotificationRequest,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("bulk_operations")),
) -> BulkOperationResponse:
    """Bulk send notifications to users.

    Creates a bulk operation record and dispatches a Celery task.
    """
    from app.tasks.bulk_tasks import execute_bulk_notification

    operation = await create_bulk_operation(
        db,
        admin=admin,
        operation_type="notification",
        target_count=len(body.user_ids),
        parameters={
            "user_ids": body.user_ids,
            "notification_type": body.notification_type,
            "title": body.title,
            "body": body.body,
        },
    )

    ip = request.client.host if request.client else ""
    ua = request.headers.get("User-Agent", "")[:500]
    await audit_service.log_action(
        db,
        admin_user_id=admin.id,
        action="bulk.notification",
        entity_type="bulk_operation",
        entity_id=operation.id,
        details={
            "target_count": len(body.user_ids),
            "notification_type": body.notification_type,
            "title": body.title,
        },
        ip_address=ip,
        user_agent=ua,
    )
    await db.commit()

    execute_bulk_notification.delay(str(operation.id))

    return _operation_to_response(operation)


@router.get("/", response_model=BulkOperationListResponse)
@limiter.limit("10/minute")
async def list_bulk_operations(
    request: Request,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("bulk_operations")),
) -> BulkOperationListResponse:
    """List all bulk operations with pagination."""
    operations, total = await list_operations(db, page=page, page_size=page_size)
    return BulkOperationListResponse(
        operations=[_operation_to_response(op) for op in operations],
        total_count=total,
    )


@router.get("/{operation_id}", response_model=BulkOperationResponse)
@limiter.limit("10/minute")
async def get_bulk_operation(
    request: Request,
    operation_id: UUID,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("bulk_operations")),
) -> BulkOperationResponse:
    """Get detail for a single bulk operation."""
    try:
        operation = await get_operation(db, operation_id)
        return _operation_to_response(operation)
    except BulkOperationNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bulk operation not found",
        )


@router.post("/{operation_id}/cancel", response_model=BulkOperationResponse)
@limiter.limit("5/minute")
async def cancel_bulk_operation(
    request: Request,
    operation_id: UUID,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("bulk_operations")),
) -> BulkOperationResponse:
    """Cancel a pending or running bulk operation."""
    try:
        operation = await cancel_operation(db, operation_id)

        ip = request.client.host if request.client else ""
        ua = request.headers.get("User-Agent", "")[:500]
        await audit_service.log_action(
            db,
            admin_user_id=admin.id,
            action="bulk.cancel",
            entity_type="bulk_operation",
            entity_id=operation_id,
            ip_address=ip,
            user_agent=ua,
        )
        await db.commit()

        return _operation_to_response(operation)
    except BulkOperationNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bulk operation not found",
        )
    except BulkOperationNotCancellableError as e:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(e),
        )
