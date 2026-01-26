"""Base schemas with common configurations."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class BaseSchema(BaseModel):
    """Base schema with common configuration."""

    model_config = ConfigDict(
        from_attributes=True,  # Allow ORM model conversion
        str_strip_whitespace=True,  # Strip whitespace from strings
        strict=True,  # Strict type checking
    )


class TimestampSchema(BaseSchema):
    """Schema with timestamp fields."""

    created_at: datetime
    updated_at: datetime


class TenantSchema(BaseSchema):
    """Schema with tenant_id field."""

    tenant_id: UUID
