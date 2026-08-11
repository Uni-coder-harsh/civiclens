"""
CivicLens AI Service — Orchestrates ONNX inference + DB persistence.
"""

import uuid
import logging
from decimal import Decimal
from datetime import datetime, timezone
from io import BytesIO
from typing import Optional, Any

from PIL import Image

from app.modules.ai.model import AIInferenceLog, AIModel, AIPrediction
from app.modules.ai.repository import AIInferenceRepository, AIModelRepository, AIPredictionRepository
from app.modules.ai.schema import AIModelCreate, AnalysisSubmit, DetectionResult

logger = logging.getLogger("civiclens.ai.service")

# Sentinel value used for inferring without a linked media_id
_NULL_UUID = uuid.UUID("00000000-0000-0000-0000-000000000000")


class AIService:
    def __init__(
        self,
        model_repo: AIModelRepository,
        inference_repo: AIInferenceRepository,
        prediction_repo: AIPredictionRepository,
    ):
        self.model_repo = model_repo
        self.inference_repo = inference_repo
        self.prediction_repo = prediction_repo

    async def list_models(self) -> list[AIModel]:
        return list(await self.model_repo.list())

    async def register_model(self, data: AIModelCreate) -> AIModel:
        return await self.model_repo.create(AIModel(**data.model_dump()))

    async def submit_analysis(self, data: AnalysisSubmit) -> AIInferenceLog:
        log = AIInferenceLog(
            model_id=data.model_id,
            media_id=data.media_id,
            inference_duration_ms=data.inference_duration_ms,
            status="SUCCESS",
        )
        await self.inference_repo.create(log)
        for item in data.predictions:
            bbox = item.bounding_box
            prediction = AIPrediction(
                inference_log_id=log.id,
                class_name=item.class_name,
                confidence=item.confidence,
                bbox_x_center=bbox.x_center,
                bbox_y_center=bbox.y_center,
                bbox_width=bbox.width,
                bbox_height=bbox.height,
            )
            await self.prediction_repo.create(prediction)
        return log

    async def history(self, media_id: uuid.UUID | None = None) -> list[AIInferenceLog]:
        if media_id:
            return await self.inference_repo.list_by_media(media_id)
        return list(await self.inference_repo.list())

    async def run_detection(
        self,
        engine: Any,
        image_data: bytes,
        media_id: Optional[uuid.UUID] = None,
        conf_threshold: Optional[float] = None,
        iou_threshold: Optional[float] = None,
    ) -> DetectionResult:
        """
        Orchestrates:
          1. ONNX inference via CrackONNXInferenceEngine
          2. Persists AIInferenceLog + AIPrediction records to Neon DB
          3. Returns a DetectionResult schema

        The original image_data bytes are NOT modified.
        """
        if engine is None:
            return DetectionResult(
                status="failed",
                model={"name": "civiclens-crack-detector", "version": "unavailable", "runtime": "onnxruntime", "provider": "none"},
                image={"width": 0, "height": 0},
                detections=[],
                detection_count=0,
                timing_ms={"preprocess": 0, "inference": 0, "postprocess": 0, "total": 0},
                error_message="Inference engine is unavailable. Check model path and configuration.",
            )

        # ── 1. Run ONNX inference ────────────────────────────────────────────
        try:
            raw = engine.detect(
                image_data,
                conf_threshold=conf_threshold,
                iou_threshold=iou_threshold,
            )
        except Exception as e:
            logger.error(f"[AIService] Inference failed: {e}")
            return DetectionResult(
                status="failed",
                model={"name": "civiclens-crack-detector", "version": engine.version, "runtime": "onnxruntime", "provider": engine.provider},
                image={"width": 0, "height": 0},
                detections=[],
                detection_count=0,
                timing_ms={"preprocess": 0, "inference": 0, "postprocess": 0, "total": 0},
                error_message="Inference failed. The image may be corrupted or in an unsupported format.",
            )

        orig_w = raw["image"]["width"]
        orig_h = raw["image"]["height"]
        duration_ms = int(raw["timing_ms"]["total"])
        detections = raw["detections"]

        # ── 2. Persist to DB ──────────────────────────────────────────────────
        log_id: Optional[uuid.UUID] = None
        try:
            # Try to find an existing registered model record for this version
            models = await self.model_repo.list()
            model_record = next(
                (m for m in models if m.version == engine.version), None
            )

            if model_record is None:
                # Auto-register the model if not yet in DB
                model_record = await self.model_repo.create(
                    AIModel(
                        name="civiclens-crack-detector",
                        version=engine.version,
                        file_path=engine.model_path,
                        is_active=True,
                    )
                )

            _media_id = media_id if media_id else _NULL_UUID
            log = AIInferenceLog(
                model_id=model_record.id,
                media_id=_media_id,
                inference_duration_ms=duration_ms,
                status="SUCCESS",
            )
            await self.inference_repo.create(log)
            log_id = log.id

            # Persist individual detections
            for det in detections:
                bb = det["bounding_box"]
                # Store normalized coords [0,1] per existing schema convention
                x_center_n = ((bb["x1"] + bb["x2"]) / 2.0) / orig_w if orig_w > 0 else 0.0
                y_center_n = ((bb["y1"] + bb["y2"]) / 2.0) / orig_h if orig_h > 0 else 0.0
                width_n = bb["width"] / orig_w if orig_w > 0 else 0.0
                height_n = bb["height"] / orig_h if orig_h > 0 else 0.0

                pred = AIPrediction(
                    inference_log_id=log.id,
                    class_name=det["class_name"],
                    confidence=Decimal(str(round(det["confidence"], 4))),
                    bbox_x_center=Decimal(str(round(x_center_n, 5))),
                    bbox_y_center=Decimal(str(round(y_center_n, 5))),
                    bbox_width=Decimal(str(round(width_n, 5))),
                    bbox_height=Decimal(str(round(height_n, 5))),
                )
                await self.prediction_repo.create(pred)

        except Exception as db_err:
            logger.warning(f"[AIService] DB persistence failed (inference result still returned): {db_err}")

        # ── 3. Build response ─────────────────────────────────────────────────
        return DetectionResult(
            status=raw["status"],
            model=raw["model"],
            image=raw["image"],
            detections=raw["detections"],
            detection_count=raw["detection_count"],
            timing_ms=raw["timing_ms"],
            inference_log_id=log_id,
        )
