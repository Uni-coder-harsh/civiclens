"""
CivicLens AI Prediction Router

Endpoints:
  GET    /v1/prediction/models         — list registered AI models
  POST   /v1/prediction/models         — register a new AI model
  POST   /v1/prediction/predict        — submit manual analysis (legacy)
  GET    /v1/prediction/history        — inference history
  POST   /v1/prediction/detect         — ⭐ ONNX crack detection on uploaded image
  GET    /v1/prediction/debug          — model diagnostic (dev/staging only)
"""

import uuid
import logging
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from app.modules.ai.dependencies import get_ai_service, get_inference_engine
from app.modules.ai.schema import (
    AIModelCreate,
    AIModelResponse,
    AnalysisSubmit,
    DetectionResult,
    EngineDebugResponse,
    InferenceResponse,
)
from app.modules.ai.service import AIService
from app.modules.auth.constants import RoleEnum
from app.modules.auth.dependencies import RoleChecker, get_current_user
from app.modules.auth.model import User
from app.core.config import settings

logger = logging.getLogger("civiclens.ai.router")

router = APIRouter(prefix="/prediction", tags=["AI Intelligence"])
inspector_only = RoleChecker([RoleEnum.INSPECTOR.value, RoleEnum.ORG_ADMIN.value, RoleEnum.SUPER_ADMIN.value])

# Supported image MIME types
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}
MAX_IMAGE_SIZE_MB = 25
MAX_IMAGE_SIZE_BYTES = MAX_IMAGE_SIZE_MB * 1024 * 1024


@router.get("/models", response_model=list[AIModelResponse])
async def list_models(
    _: User = Depends(get_current_user),
    service: AIService = Depends(get_ai_service),
):
    """List all registered AI models."""
    return await service.list_models()


@router.post("/models", status_code=status.HTTP_201_CREATED, response_model=AIModelResponse)
async def register_model(
    data: AIModelCreate,
    _: User = Depends(inspector_only),
    service: AIService = Depends(get_ai_service),
):
    """Register a new AI model record."""
    return await service.register_model(data)


@router.post("/predict", response_model=InferenceResponse)
async def submit_prediction(
    data: AnalysisSubmit,
    _: User = Depends(inspector_only),
    service: AIService = Depends(get_ai_service),
):
    """Submit a manual analysis result (legacy endpoint)."""
    return await service.submit_analysis(data)


@router.get("/history", response_model=list[InferenceResponse])
async def prediction_history(
    media_id: uuid.UUID | None = None,
    _: User = Depends(get_current_user),
    service: AIService = Depends(get_ai_service),
):
    """Get inference history, optionally filtered by media_id."""
    return await service.history(media_id)


@router.post("/detect", response_model=DetectionResult, summary="ONNX Crack Detection")
async def detect_cracks(
    file: UploadFile = File(..., description="Road/infrastructure image (JPEG, PNG, WEBP, max 25 MB)"),
    media_id: uuid.UUID | None = Form(None, description="Optional: link this detection to an existing media record"),
    conf_threshold: float | None = Form(None, description="Override confidence threshold (0.0–1.0)"),
    iou_threshold: float | None = Form(None, description="Override IoU NMS threshold (0.0–1.0)"),
    current_user: User = Depends(get_current_user),
    service: AIService = Depends(get_ai_service),
):
    """
    **Primary ONNX crack detection endpoint.**

    Accepts an uploaded road or infrastructure image, runs YOLO11 ONNX inference,
    and returns structured detection results including bounding boxes and class labels.

    - Authenticates the requesting user.
    - Validates image format, MIME type, and file size.
    - Runs inference via the singleton `CrackONNXInferenceEngine`.
    - Persists detection results to the database.
    - Returns a `DetectionResult` that Flutter can consume to render bounding boxes.

    **Classes detected:**
    - `D00_Longitudinal_Crack`
    - `D10_Transverse_Crack`
    - `D20_Alligator_Crack`
    - `D30_Other_Corruption`
    - `D40_Pothole`
    """

    # ── Validate content type ────────────────────────────────────────────────
    content_type = (file.content_type or "").lower()
    if content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported image format '{content_type}'. Accepted: JPEG, PNG, WEBP.",
        )

    # ── Read and size-check the file ─────────────────────────────────────────
    image_bytes = await file.read()
    if len(image_bytes) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty.",
        )
    if len(image_bytes) > MAX_IMAGE_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Image exceeds maximum allowed size of {MAX_IMAGE_SIZE_MB} MB.",
        )

    # ── Validate actual image readability ────────────────────────────────────
    try:
        from io import BytesIO
        from PIL import Image
        img = Image.open(BytesIO(image_bytes))
        img.verify()  # Raises on corrupted files
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="File could not be decoded as a valid image. It may be corrupted or not an image.",
        )

    # ── Get engine singleton ─────────────────────────────────────────────────
    engine = get_inference_engine()

    # ── Threshold validation ─────────────────────────────────────────────────
    if conf_threshold is not None and not (0.0 < conf_threshold < 1.0):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="conf_threshold must be between 0 and 1.")
    if iou_threshold is not None and not (0.0 < iou_threshold < 1.0):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="iou_threshold must be between 0 and 1.")

    logger.info(
        f"[detect] user={current_user.id} file={file.filename!r} "
        f"size={len(image_bytes)//1024}KB media_id={media_id}"
    )

    # ── Run detection ────────────────────────────────────────────────────────
    result = await service.run_detection(
        engine=engine,
        image_data=image_bytes,
        media_id=media_id,
        conf_threshold=conf_threshold,
        iou_threshold=iou_threshold,
    )

    if result.status == "failed":
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=result.error_message or "Inference failed.",
        )

    logger.info(
        f"[detect] ✅ {result.detection_count} detections in {result.timing_ms.total:.0f}ms "
        f"(log_id={result.inference_log_id})"
    )
    return result


@router.get(
    "/debug",
    response_model=EngineDebugResponse,
    summary="ONNX Engine Diagnostics (dev only)",
    include_in_schema=settings.DEBUG,
)
async def engine_debug(
    _: User = Depends(get_current_user),
):
    """
    Returns diagnostic information about the loaded ONNX model.
    Only visible in debug/development mode.
    """
    engine = get_inference_engine()
    if engine is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Inference engine is not loaded. Check MODEL_PATH configuration.",
        )
    return EngineDebugResponse(
        model_path=engine.model_path,
        model_version=engine.version,
        input_name=engine.input_name,
        input_shape=list(engine.input_shape),
        output_name=engine.output_name,
        output_shape=list(engine.output_shape),
        class_names={str(k): v for k, v in engine.class_names.items()},
        provider=engine.provider,
        conf_threshold=engine.conf_threshold,
        iou_threshold=engine.iou_threshold,
    )
