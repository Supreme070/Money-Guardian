"""Admin data export endpoints.

Allows admins with 'analytics.view' permission to export users,
subscriptions, and audit log data as CSV files.
"""

import logging
from pathlib import Path
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints.admin_auth import get_current_admin
from app.core.rate_limit import limiter
from app.db.session import get_db
from app.models.admin_user import AdminUser
from app.schemas.admin_export import ExportRequest, ExportResponse
from app.services import audit_service
from app.services.bulk_operation_service import (
    BulkOperationNotFoundError,
    create_bulk_operation,
    get_operation,
)
from app.services.rbac_service import require_permission

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/", response_model=ExportResponse)
@limiter.limit("5/minute")
async def request_export(
    request: Request,
    body: ExportRequest,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("analytics.view")),
) -> ExportResponse:
    """Request a data export.

    Creates a bulk operation record and dispatches a Celery export task.
    The export is processed asynchronously; poll the operation status
    or use the download endpoint once complete.
    """
    from app.tasks.export_tasks import export_data

    operation = await create_bulk_operation(
        db,
        admin=admin,
        operation_type="export",
        target_count=1,
        parameters={
            "export_type": body.export_type,
            "format": body.format,
        },
    )

    ip = request.client.host if request.client else ""
    ua = request.headers.get("User-Agent", "")[:500]
    await audit_service.log_action(
        db,
        admin_user_id=admin.id,
        action="export.request",
        entity_type="bulk_operation",
        entity_id=operation.id,
        details={
            "export_type": body.export_type,
            "format": body.format,
        },
        ip_address=ip,
        user_agent=ua,
    )
    await db.commit()

    # Dispatch Celery task
    export_data.delay(
        str(operation.id),
        body.export_type,
        body.filters,
    )

    return ExportResponse(
        export_id=str(operation.id),
        status="pending",
    )


@router.get("/{export_id}/download")
@limiter.limit("10/minute")
async def download_export(
    request: Request,
    export_id: UUID,
    db: AsyncSession = Depends(get_db),
    admin: AdminUser = Depends(require_permission("analytics.view")),
) -> FileResponse:
    """Download a completed export file.

    Returns 404 if the export doesn't exist,
    409 if it hasn't completed yet,
    and the CSV file if ready.
    """
    try:
        operation = await get_operation(db, export_id)
    except BulkOperationNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Export not found",
        )

    if operation.status != "completed":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Export is not ready (status: {operation.status})",
        )

    if not operation.result_url:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Export file path not found",
        )

    filepath = Path(operation.result_url)
    if not filepath.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Export file no longer available",
        )

    # Determine filename from the operation parameters
    params = operation.parameters or {}
    export_type = params.get("export_type", "data")
    filename = f"{export_type}_export.csv"

    return FileResponse(
        path=str(filepath),
        filename=filename,
        media_type="text/csv",
    )
