import uuid
from datetime import datetime
from pydantic import BaseModel, ConfigDict

class BaseRequestSchema(BaseModel):
    """Base Pydantic schema for all incoming request payloads."""
    model_config = ConfigDict(
        from_attributes=True,
        populate_by_name=True,
        str_strip_whitespace=True
    )

class BaseResponseSchema(BaseModel):
    """Base Pydantic schema for all outgoing API response payloads."""
    id: uuid.UUID
    created_at: datetime
    updated_at: datetime
    version: int

    model_config = ConfigDict(
        from_attributes=True,
        populate_by_name=True
    )
