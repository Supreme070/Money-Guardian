"""Service for managing bulk operations."""

import logging
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.admin_user import AdminUser
from app.models.bulk_operation import BulkOperation

logger = logging.getLogger(__name__)


class BulkOperationNotFoundError(Exception):
    """Raised when a bulk operation is not found."""


class BulkOperationNotCancellableError(Exception):
    """Raised when a bulk operation cannot be cancelled."""


async def create_bulk_operation(
    db: AsyncSession,
    *,
    admin: AdminUser,
    operation_type: str,
    target_count: int,
    parameters: dict[str, str | int | bool | list[str] | None] | None = None,
) -> BulkOperation:
    """Create a new bulk operation record."""
    operation = BulkOperation(
        admin_user_id=admin.id,
        operation_type=operation_type,
        target_count=target_count,
        parameters=parameters,
        status="pending",
    )
    db.add(operation)
    await db.flush()

    logger.info(
        "Bulk operation created: id=%s type=%s targets=%d admin=%s",
        operation.id, operation_type, target_count, admin.email,
    )
    return operation


async def list_operations(
    db: AsyncSession,
    *,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[BulkOperation], int]:
    """List bulk operations with pagination."""
    count_query = select(func.count(BulkOperation.id))
    total_count = (await db.execute(count_query)).scalar() or 0

    offset = (page - 1) * page_size
    query = (
        select(BulkOperation)
        .order_by(BulkOperation.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    result = await db.execute(query)
    operations = list(result.scalars().all())

    return operations, total_count


async def get_operation(
    db: AsyncSession,
    operation_id: UUID,
) -> BulkOperation:
    """Get a single bulk operation by ID."""
    result = await db.execute(
        select(BulkOperation).where(BulkOperation.id == operation_id)
    )
    operation = result.scalar_one_or_none()
    if not operation:
        raise BulkOperationNotFoundError(f"Operation {operation_id} not found")
    return operation


async def cancel_operation(
    db: AsyncSession,
    operation_id: UUID,
) -> BulkOperation:
    """Cancel a pending or running bulk operation."""
    operation = await get_operation(db, operation_id)

    if operation.status not in ("pending", "running"):
        raise BulkOperationNotCancellableError(
            f"Cannot cancel operation with status '{operation.status}'"
        )

    operation.status = "cancelled"
    operation.completed_at = datetime.now(timezone.utc)
    db.add(operation)
    await db.flush()

    logger.info("Bulk operation cancelled: id=%s", operation_id)
    return operation
