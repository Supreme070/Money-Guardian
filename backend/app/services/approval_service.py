"""Approval workflow service for sensitive admin actions.

Actions requiring approval (for non-super_admin):
- tenant.delete
- user.purge
- bulk_100plus
- refund_over_100
- admin.mfa_disable
"""

import logging
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.admin_user import AdminUser
from app.models.approval_request import ApprovalRequest
from app.schemas.admin_approvals import (
    ApprovalCreateRequest,
    ApprovalListResponse,
    ApprovalResponse,
    ApprovalReviewRequest,
)
from app.services.admin_sse_service import publish_event

logger = logging.getLogger(__name__)

ACTIONS_REQUIRING_APPROVAL: set[str] = {
    "tenant.delete",
    "user.purge",
    "bulk_100plus",
    "refund_over_100",
    "admin.mfa_disable",
}

APPROVAL_EXPIRY_HOURS = 24


class ApprovalNotFoundError(Exception):
    pass


class ApprovalStateError(Exception):
    pass


def _build_response(approval: ApprovalRequest) -> ApprovalResponse:
    """Build an ApprovalResponse from a model with loaded relationships."""
    return ApprovalResponse(
        id=approval.id,
        requester_id=approval.requester_id,
        requester_email=approval.requester.email,
        requester_name=approval.requester.full_name,
        approver_id=approval.approver_id,
        action=approval.action,
        entity_type=approval.entity_type,
        entity_id=approval.entity_id,
        parameters=approval.parameters,
        status=approval.status,
        reason=approval.reason,
        review_note=approval.review_note,
        expires_at=approval.expires_at,
        reviewed_at=approval.reviewed_at,
        executed_at=approval.executed_at,
        created_at=approval.created_at,
        updated_at=approval.updated_at,
    )


async def create_approval(
    db: AsyncSession,
    *,
    requester: AdminUser,
    request: ApprovalCreateRequest,
) -> ApprovalRequest:
    """Create a new approval request.

    Sets expires_at to 24 hours from now and publishes an SSE event.
    """
    entity_id: UUID | None = None
    if request.entity_id is not None:
        entity_id = UUID(request.entity_id)

    approval = ApprovalRequest(
        requester_id=requester.id,
        action=request.action,
        entity_type=request.entity_type,
        entity_id=entity_id,
        parameters=request.parameters,
        status="pending",
        reason=request.reason,
        expires_at=datetime.now(timezone.utc) + timedelta(hours=APPROVAL_EXPIRY_HOURS),
    )
    db.add(approval)
    await db.flush()

    # Reload with requester relationship
    result = await db.execute(
        select(ApprovalRequest)
        .where(ApprovalRequest.id == approval.id)
        .join(ApprovalRequest.requester)
    )
    approval = result.scalar_one()
    # Eagerly load the requester
    await db.refresh(approval, ["requester"])

    logger.info(
        "Approval request created: id=%s action=%s by=%s",
        approval.id, request.action, requester.email,
    )

    await publish_event("approval.created", {
        "approval_id": str(approval.id),
        "action": request.action,
        "requester": requester.email,
    })

    return approval


async def review_approval(
    db: AsyncSession,
    *,
    approver: AdminUser,
    approval_id: UUID,
    review_request: ApprovalReviewRequest,
) -> ApprovalRequest:
    """Approve or reject an approval request.

    Only super_admin can approve/reject.
    """
    if approver.role != "super_admin":
        raise ApprovalStateError("Only super_admin can review approval requests")

    approval = await _get_approval_with_requester(db, approval_id)

    if approval.status != "pending":
        raise ApprovalStateError(
            f"Cannot review approval in '{approval.status}' state"
        )

    now = datetime.now(timezone.utc)
    if approval.expires_at < now:
        approval.status = "expired"
        await db.flush()
        raise ApprovalStateError("Approval request has expired")

    approval.status = review_request.status
    approval.approver_id = approver.id
    approval.review_note = review_request.review_note
    approval.reviewed_at = now
    await db.flush()

    # Reload with relationships
    await db.refresh(approval, ["requester", "approver"])

    logger.info(
        "Approval %s %s by %s",
        approval_id, review_request.status, approver.email,
    )

    await publish_event("approval.reviewed", {
        "approval_id": str(approval.id),
        "action": approval.action,
        "status": review_request.status,
        "approver": approver.email,
    })

    return approval


async def execute_approval(
    db: AsyncSession,
    *,
    approval_id: UUID,
) -> ApprovalRequest:
    """Execute an approved action.

    Sets executed_at timestamp. The actual operation logic is handled
    by the caller based on the approval's action/entity_type.
    """
    approval = await _get_approval_with_requester(db, approval_id)

    if approval.status != "approved":
        raise ApprovalStateError(
            f"Cannot execute approval in '{approval.status}' state"
        )

    approval.status = "executed"
    approval.executed_at = datetime.now(timezone.utc)
    await db.flush()

    await db.refresh(approval, ["requester", "approver"])

    logger.info("Approval %s executed: action=%s", approval_id, approval.action)

    await publish_event("approval.executed", {
        "approval_id": str(approval.id),
        "action": approval.action,
    })

    return approval


async def list_approvals(
    db: AsyncSession,
    *,
    status_filter: str | None = None,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[ApprovalRequest], int, int]:
    """List approval requests with optional status filter.

    Returns (approvals, total_count, pending_count).
    """
    query = (
        select(ApprovalRequest)
        .join(ApprovalRequest.requester)
        .order_by(ApprovalRequest.created_at.desc())
    )
    count_query = select(func.count(ApprovalRequest.id))

    if status_filter:
        query = query.where(ApprovalRequest.status == status_filter)
        count_query = count_query.where(ApprovalRequest.status == status_filter)

    total_count = (await db.execute(count_query)).scalar() or 0

    pending_count = (
        await db.execute(
            select(func.count(ApprovalRequest.id)).where(
                ApprovalRequest.status == "pending"
            )
        )
    ).scalar() or 0

    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)

    result = await db.execute(query)
    approvals = list(result.scalars().all())

    # Eagerly load requester for each approval
    for approval in approvals:
        await db.refresh(approval, ["requester"])

    return approvals, total_count, pending_count


async def get_approval(
    db: AsyncSession,
    approval_id: UUID,
) -> ApprovalRequest:
    """Get a single approval request by ID."""
    return await _get_approval_with_requester(db, approval_id)


async def _get_approval_with_requester(
    db: AsyncSession,
    approval_id: UUID,
) -> ApprovalRequest:
    """Fetch an approval request and eagerly load its requester."""
    result = await db.execute(
        select(ApprovalRequest).where(ApprovalRequest.id == approval_id)
    )
    approval = result.scalar_one_or_none()
    if not approval:
        raise ApprovalNotFoundError(f"Approval {approval_id} not found")
    await db.refresh(approval, ["requester", "approver"])
    return approval
