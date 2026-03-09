"""Health score and advanced analytics schemas for admin portal.

Strict Pydantic models -- no ``Any`` types.
"""

from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


_HEALTH_CONFIG = ConfigDict(
    from_attributes=True,
    str_strip_whitespace=True,
    strict=True,
    ser_json_inf_nan="constants",
)


# ---------------------------------------------------------------------------
# Health Scores
# ---------------------------------------------------------------------------


class HealthScoreResponse(BaseModel):
    model_config = _HEALTH_CONFIG

    user_id: UUID
    tenant_id: UUID
    score: int
    risk_level: str
    factors: dict[str, int | float | str]
    snapshot_date: date
    created_at: datetime


class HealthScoreListResponse(BaseModel):
    model_config = _HEALTH_CONFIG

    scores: list[HealthScoreResponse]
    total_count: int


class HealthScoreFilters(BaseModel):
    model_config = _HEALTH_CONFIG

    risk_level: str | None = None
    min_score: int | None = Field(default=None, ge=0, le=100)
    max_score: int | None = Field(default=None, ge=0, le=100)


# ---------------------------------------------------------------------------
# Cohort Analytics
# ---------------------------------------------------------------------------


class CohortData(BaseModel):
    model_config = _HEALTH_CONFIG

    cohort_month: str  # "2026-01"
    month_offset: int
    retention_rate: float
    user_count: int


class CohortResponse(BaseModel):
    model_config = _HEALTH_CONFIG

    cohorts: list[CohortData]


# ---------------------------------------------------------------------------
# Conversion Funnel
# ---------------------------------------------------------------------------


class FunnelStep(BaseModel):
    model_config = _HEALTH_CONFIG

    name: str
    count: int
    conversion_rate: float


class FunnelResponse(BaseModel):
    model_config = _HEALTH_CONFIG

    steps: list[FunnelStep]
    total_started: int


# ---------------------------------------------------------------------------
# Retention Curves
# ---------------------------------------------------------------------------


class RetentionPoint(BaseModel):
    model_config = _HEALTH_CONFIG

    day: int
    retention_rate: float
    user_count: int


class RetentionResponse(BaseModel):
    model_config = _HEALTH_CONFIG

    points: list[RetentionPoint]
