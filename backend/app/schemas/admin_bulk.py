"""Schemas for admin bulk operations."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class BulkUserStatusRequest(BaseModel):
    """Request to change status for multiple users."""

    user_ids: list[str] = Field(..., min_length=1, max_length=500)
    new_status: Literal["active", "suspended", "deleted"] = Field(...)
    reason: str = Field(..., min_length=3, max_length=500)


class BulkTierOverrideRequest(BaseModel):
    """Request to override tier for multiple tenants."""

    tenant_ids: list[str] = Field(..., min_length=1, max_length=500)
    new_tier: str = Field(..., min_length=1, max_length=20)
    reason: str = Field(..., min_length=3, max_length=500)


class BulkNotificationRequest(BaseModel):
    """Request to send notification to multiple users."""

    user_ids: list[str] = Field(..., min_length=1, max_length=1000)
    notification_type: Literal["push", "email", "both"] = Field(...)
    title: str = Field(..., min_length=1, max_length=255)
    body: str = Field(..., min_length=1, max_length=2000)


class BulkOperationResponse(BaseModel):
    """Response for a single bulk operation."""

    id: str
    admin_user_id: str | None
    operation_type: str
    target_count: int
    processed_count: int
    failed_count: int
    status: str
    parameters: dict[str, str | int | bool | list[str] | None] | None = None
    result_url: str | None = None
    error_message: str | None = None
    started_at: datetime | None = None
    completed_at: datetime | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class BulkOperationListResponse(BaseModel):
    """Paginated list of bulk operations."""

    operations: list[BulkOperationResponse]
    total_count: int
