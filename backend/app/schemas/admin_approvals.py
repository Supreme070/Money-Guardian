"""Approval workflow schemas.

Strict Pydantic models -- no ``Any`` types.
"""

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

_APPROVAL_CONFIG = ConfigDict(
    from_attributes=True,
    str_strip_whitespace=True,
    strict=True,
    ser_json_inf_nan="constants",
)


# ---------------------------------------------------------------------------
# Requests
# ---------------------------------------------------------------------------


class ApprovalCreateRequest(BaseModel):
    model_config = _APPROVAL_CONFIG
    action: str = Field(..., min_length=1, max_length=100)
    entity_type: str = Field(..., min_length=1, max_length=50)
    entity_id: str | None = Field(default=None, max_length=36)
    parameters: dict[str, str | int | bool | None] | None = None
    reason: str = Field(..., min_length=3, max_length=2000)


class ApprovalReviewRequest(BaseModel):
    model_config = _APPROVAL_CONFIG
    status: Literal["approved", "rejected"]
    review_note: str | None = Field(default=None, max_length=2000)


# ---------------------------------------------------------------------------
# Responses
# ---------------------------------------------------------------------------


class ApprovalResponse(BaseModel):
    model_config = _APPROVAL_CONFIG
    id: UUID
    requester_id: UUID
    requester_email: str
    requester_name: str
    approver_id: UUID | None = None
    action: str
    entity_type: str
    entity_id: UUID | None = None
    parameters: dict[str, str | int | bool | None] | None = None
    status: str
    reason: str
    review_note: str | None = None
    expires_at: datetime
    reviewed_at: datetime | None = None
    executed_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class ApprovalListResponse(BaseModel):
    model_config = _APPROVAL_CONFIG
    requests: list[ApprovalResponse]
    total_count: int
    pending_count: int
