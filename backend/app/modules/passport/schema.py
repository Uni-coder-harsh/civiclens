import uuid
from datetime import datetime
from decimal import Decimal
from app.common.schemas import BaseRequestSchema, BaseResponseSchema


class PassportResponse(BaseResponseSchema):
    asset_id: uuid.UUID
    passport_number: str
    structural_health_index: Decimal
    last_inspected_at: datetime | None = None
    next_inspection_due: datetime | None = None
    degradation_rate: Decimal


class DegradationHistoryResponse(BaseResponseSchema):
    passport_id: uuid.UUID
    health_index: Decimal
    change_reason: str


class PassportExport(BaseRequestSchema):
    passport: PassportResponse
    history: list[DegradationHistoryResponse]
