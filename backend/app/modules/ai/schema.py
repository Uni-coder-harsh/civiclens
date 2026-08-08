import uuid
from decimal import Decimal
from pydantic import Field
from app.common.schemas import BaseRequestSchema, BaseResponseSchema


class AIModelCreate(BaseRequestSchema):
    name: str
    version: str
    file_path: str
    is_active: bool = False
    accuracy_metrics: dict | None = None


class AIModelResponse(BaseResponseSchema):
    name: str
    version: str
    file_path: str
    is_active: bool
    accuracy_metrics: dict | None = None


class BoundingBox(BaseRequestSchema):
    x_center: Decimal = Field(..., ge=0, le=1)
    y_center: Decimal = Field(..., ge=0, le=1)
    width: Decimal = Field(..., ge=0, le=1)
    height: Decimal = Field(..., ge=0, le=1)


class PredictionCreate(BaseRequestSchema):
    class_name: str
    confidence: Decimal = Field(..., ge=0, le=1)
    bounding_box: BoundingBox


class AnalysisSubmit(BaseRequestSchema):
    model_id: uuid.UUID
    media_id: uuid.UUID
    inference_duration_ms: int = Field(..., ge=0)
    predictions: list[PredictionCreate] = []


class PredictionResponse(BaseResponseSchema):
    inference_log_id: uuid.UUID
    class_name: str
    confidence: Decimal
    bbox_x_center: Decimal
    bbox_y_center: Decimal
    bbox_width: Decimal
    bbox_height: Decimal


class InferenceResponse(BaseResponseSchema):
    model_id: uuid.UUID
    media_id: uuid.UUID
    inference_duration_ms: int
    status: str
    error_message: str | None = None
