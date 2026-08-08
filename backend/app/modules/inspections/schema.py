import uuid
from datetime import datetime
from pydantic import Field
from app.common.schemas import BaseRequestSchema, BaseResponseSchema
from app.modules.infrastructure.schema import GeoPoint
from app.modules.inspections.constants import DefectSeverity, InspectionStatus, MediaType


class InspectionCreate(BaseRequestSchema):
    asset_id: uuid.UUID
    inspector_id: uuid.UUID | None = None
    scheduled_at: datetime
    status: InspectionStatus = InspectionStatus.SCHEDULED


class InspectionStatusUpdate(BaseRequestSchema):
    status: InspectionStatus


class InspectionResponse(BaseResponseSchema):
    asset_id: uuid.UUID
    inspector_id: uuid.UUID | None
    scheduled_at: datetime
    started_at: datetime | None = None
    completed_at: datetime | None = None
    status: str
    summary_report_url: str | None = None


class InspectionItemCreate(BaseRequestSchema):
    location: GeoPoint
    description: str | None = None
    detected_severity: DefectSeverity = DefectSeverity.MINOR
    notes: str | None = None


class InspectionItemResponse(BaseResponseSchema):
    inspection_id: uuid.UUID
    description: str | None = None
    detected_severity: str
    assigned_severity: str | None = None
    notes: str | None = None


class MediaCreate(BaseRequestSchema):
    media_type: MediaType
    file_url: str = Field(..., min_length=1, max_length=1024)
    file_size_bytes: int = Field(..., ge=0)
    mime_type: str = Field(..., min_length=1, max_length=100)


class MediaResponse(BaseResponseSchema):
    inspection_item_id: uuid.UUID
    media_type: str
    file_url: str
    file_size_bytes: int
    mime_type: str
