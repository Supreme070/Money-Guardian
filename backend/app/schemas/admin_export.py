"""Schemas for admin data export."""

from typing import Literal

from pydantic import BaseModel, Field


class ExportRequest(BaseModel):
    """Request to export data as CSV."""

    export_type: Literal["users", "subscriptions", "audit_log"] = Field(...)
    format: Literal["csv"] = Field(default="csv")
    filters: dict[str, str] | None = Field(default=None)


class ExportResponse(BaseModel):
    """Response after requesting an export."""

    export_id: str
    status: str
    download_url: str | None = None
