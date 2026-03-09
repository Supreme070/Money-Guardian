"""Feature flag schemas for admin portal.

Strict Pydantic models -- no ``Any`` types.
"""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


_FLAG_CONFIG = ConfigDict(
    from_attributes=True,
    str_strip_whitespace=True,
    strict=True,
    ser_json_inf_nan="constants",
)


class FeatureFlagCreateRequest(BaseModel):
    model_config = _FLAG_CONFIG

    key: str = Field(
        ..., min_length=1, max_length=100, pattern=r"^[a-z0-9_]+$",
    )
    name: str = Field(..., min_length=1, max_length=255)
    description: str | None = None
    is_enabled: bool = False
    rollout_percentage: int = Field(default=100, ge=0, le=100)
    target_tiers: list[str] | None = None
    target_user_ids: list[str] | None = None


class FeatureFlagUpdateRequest(BaseModel):
    model_config = _FLAG_CONFIG

    name: str | None = Field(default=None, max_length=255)
    description: str | None = None
    is_enabled: bool | None = None
    rollout_percentage: int | None = Field(default=None, ge=0, le=100)
    target_tiers: list[str] | None = None
    target_user_ids: list[str] | None = None


class FeatureFlagResponse(BaseModel):
    model_config = _FLAG_CONFIG

    id: UUID
    key: str
    name: str
    description: str | None
    is_enabled: bool
    rollout_percentage: int
    target_tiers: list[str] | None
    target_user_ids: list[str] | None
    created_by: UUID | None
    created_at: datetime
    updated_at: datetime


class FeatureFlagListResponse(BaseModel):
    model_config = _FLAG_CONFIG

    flags: list[FeatureFlagResponse]
    total_count: int


class FeatureFlagEvaluation(BaseModel):
    """User-facing flag evaluation result."""

    model_config = _FLAG_CONFIG

    key: str
    enabled: bool
