"""Webhook event dashboard schemas.

Strict Pydantic models -- no ``Any`` types.
"""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

_WEBHOOK_CONFIG = ConfigDict(
    from_attributes=True,
    str_strip_whitespace=True,
    strict=True,
    ser_json_inf_nan="constants",
)


class WebhookEventResponse(BaseModel):
    model_config = _WEBHOOK_CONFIG
    id: UUID
    provider: str
    event_type: str
    event_id: str
    payload_hash: str | None = None
    status: str
    processing_time_ms: int | None = None
    error_message: str | None = None
    created_at: datetime


class WebhookEventListResponse(BaseModel):
    model_config = _WEBHOOK_CONFIG
    events: list[WebhookEventResponse]
    total_count: int


class WebhookStatsResponse(BaseModel):
    model_config = _WEBHOOK_CONFIG
    total_events: int
    by_provider: dict[str, int]
    by_status: dict[str, int]
    avg_processing_time_ms: float
