"""Unified admin search schemas.

Strict Pydantic models -- no ``Any`` types.
"""

from pydantic import BaseModel, ConfigDict, Field

_SEARCH_CONFIG = ConfigDict(
    from_attributes=True,
    str_strip_whitespace=True,
    strict=True,
    ser_json_inf_nan="constants",
)


class SearchRequest(BaseModel):
    model_config = _SEARCH_CONFIG
    query: str = Field(..., min_length=2, max_length=255)
    entity_types: list[str] | None = Field(
        default=None,
        description="Filter to specific entity types: user, tenant, subscription, audit_log",
    )


class SearchResult(BaseModel):
    model_config = _SEARCH_CONFIG
    entity_type: str
    entity_id: str
    title: str
    subtitle: str
    match_field: str


class SearchResponse(BaseModel):
    model_config = _SEARCH_CONFIG
    results: list[SearchResult]
    total_count: int
