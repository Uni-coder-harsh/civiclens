"""
CivicLens AI Module — Extended Schemas for ONNX Detection Endpoint.
Adds detection-specific response schemas on top of the existing AI schemas.
"""

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


# ── Detection-specific response schemas (ONNX pipeline) ──────────────────────

class DetectionBoundingBox(BaseRequestSchema):
    x1: int
    y1: int
    x2: int
    y2: int
    width: int
    height: int


class DetectionItem(BaseRequestSchema):
    class_id: int
    class_name: str
    confidence: float
    bounding_box: DetectionBoundingBox


class DetectionModelInfo(BaseRequestSchema):
    name: str
    version: str
    runtime: str
    provider: str


class DetectionImageInfo(BaseRequestSchema):
    width: int
    height: int


class DetectionTimingMs(BaseRequestSchema):
    preprocess: float
    inference: float
    postprocess: float
    total: float


class DetectionSeverity(BaseRequestSchema):
    severity_label: str
    severity_score: float
    primary_class: str | None = None
    primary_confidence: float | None = None
    explanation: str
    detection_count: int


class DetectionResult(BaseRequestSchema):
    """
    Full ONNX/LocateAnything crack-detection result returned to Flutter and stored in DB.
    Conforms to the CivicLens detection API contract.
    """
    status: str                                   # "completed" | "failed"
    model: DetectionModelInfo
    image: DetectionImageInfo
    detections: list[DetectionItem]
    detection_count: int
    timing_ms: DetectionTimingMs
    severity: DetectionSeverity | None = None
    inference_log_id: uuid.UUID | None = None     # FK into ai_inference_logs
    annotated_image_url: str | None = None        # Supabase/MinIO URL if generated
    error_message: str | None = None


class EngineDebugResponse(BaseRequestSchema):
    """Diagnostic info about the loaded ONNX model (dev/staging only)."""
    model_path: str
    model_version: str
    input_name: str
    input_shape: list
    output_name: str
    output_shape: list
    class_names: dict
    provider: str
    conf_threshold: float
    iou_threshold: float
