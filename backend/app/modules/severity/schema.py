import uuid
from decimal import Decimal
from pydantic import Field
from app.common.schemas import BaseRequestSchema, BaseResponseSchema
from app.modules.inspections.constants import DefectSeverity


class SeverityRuleCreate(BaseRequestSchema):
    class_name: str
    parameter_name: str = "confidence"
    operator: str = ">="
    threshold_value: Decimal = Field(..., ge=0)
    assigned_severity: DefectSeverity


class SeverityRuleResponse(BaseResponseSchema):
    class_name: str
    parameter_name: str
    operator: str
    threshold_value: Decimal
    assigned_severity: str


class SeverityAssessmentRequest(BaseRequestSchema):
    confidence: Decimal = Field(Decimal("0.75"), ge=0, le=1)
    class_name: str = "pothole"


class AssessmentResponse(BaseResponseSchema):
    inspection_item_id: uuid.UUID
    calculated_severity: str
    priority_score: Decimal
    reasoning_details: str | None = None


class SeverityOverride(BaseRequestSchema):
    assigned_severity: DefectSeverity
