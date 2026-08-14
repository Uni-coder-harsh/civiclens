"""
CivicLens AI Service — Orchestrates ONNX inference + DB persistence.
Supports multiple AI providers via AI_PROVIDER config:
  - "onnx"           → existing local CrackONNXInferenceEngine (default)
  - "locateanything" → remote Lightning GPU LocateAnything-3B service
"""

import uuid
import logging
from decimal import Decimal
from datetime import datetime, timezone
from io import BytesIO
from typing import Optional, Any

from PIL import Image

from app.core.config import settings
from app.modules.ai.model import AIInferenceLog, AIModel, AIPrediction
from app.modules.ai.repository import AIInferenceRepository, AIModelRepository, AIPredictionRepository
from app.modules.ai.schema import AIModelCreate, AnalysisSubmit, DetectionResult
from app.modules.ai.severity import compute_severity

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
        inspection_mode: str = "road",
    ) -> DetectionResult:
        """
        Orchestrates AI inference. Routes to the configured AI_PROVIDER:
          - "onnx"           → CrackONNXInferenceEngine (local ONNX, default)
          - "locateanything" → LocateAnythingClient → Lightning GPU

        In both cases:
          1. Runs inference
          2. Persists AIInferenceLog + AIPrediction records to DB
          3. Returns a DetectionResult schema
        """
        # ── Provider routing ──────────────────────────────────────────────────
        if settings.AI_PROVIDER == "locateanything" and settings.LA_INFERENCE_URL:
            return await self._run_locateanything(image_data, media_id, inspection_mode)

        # Default: ONNX engine
        return await self._run_onnx(engine, image_data, media_id, conf_threshold, iou_threshold)

    async def _run_locateanything(
        self,
        image_data: bytes,
        media_id: Optional[uuid.UUID],
        inspection_mode: str = "road",
    ) -> DetectionResult:
        """Call the remote LocateAnything-3B Lightning service."""
        from app.modules.ai.locate_anything_client import LocateAnythingClient
        try:
            client = LocateAnythingClient()
            result = await client.detect_and_normalize(
                image_bytes=image_data,
                inspection_mode=inspection_mode,
            )
        except Exception as e:
            logger.error(f"[AIService] LocateAnything call failed: {e}")
            return DetectionResult(
                status="failed",
                model={"name": "LocateAnything-3B", "version": "nvidia/LocateAnything-3B", "runtime": "transformers", "provider": "lightning_gpu"},
                image={"width": 0, "height": 0},
                detections=[],
                detection_count=0,
                timing_ms={"preprocess": 0, "inference": 0, "postprocess": 0, "total": 0},
                error_message=f"LocateAnything inference failed: {e}",
            )

        # Persist to DB (best-effort)
        try:
            await self._persist_detections(
                model_name="LocateAnything-3B",
                model_version="nvidia/LocateAnything-3B",
                media_id=media_id,
                duration_ms=int(result.timing_ms.total if hasattr(result.timing_ms, "total") else result.timing_ms.get("total", 0)),
                detections=[d.model_dump() if hasattr(d, "model_dump") else d for d in result.detections],
                orig_w=result.image.width if hasattr(result.image, "width") else result.image.get("width", 0),
                orig_h=result.image.height if hasattr(result.image, "height") else result.image.get("height", 0),
            )
        except Exception as db_err:
            logger.warning(f"[AIService] DB persistence failed for LA result: {db_err}")

        severity = compute_severity(
            [d.model_dump() if hasattr(d, "model_dump") else d for d in result.detections],
            result.image.width if hasattr(result.image, "width") else result.image.get("width", 0),
            result.image.height if hasattr(result.image, "height") else result.image.get("height", 0),
        )

        return DetectionResult(
            status=result.status,
            model=result.model,
            image=result.image,
            detections=result.detections,
            detection_count=result.detection_count,
            timing_ms=result.timing_ms,
            severity=severity,
            inference_log_id=result.inference_log_id,
            annotated_image_url=result.annotated_image_url,
            error_message=result.error_message,
        )

    async def _run_onnx(
        self,
        engine: Any,
        image_data: bytes,
        media_id: Optional[uuid.UUID],
        conf_threshold: Optional[float],
        iou_threshold: Optional[float],
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
        severity = compute_severity(detections, orig_w, orig_h)
        return DetectionResult(
            status=raw["status"],
            model=raw["model"],
            image=raw["image"],
            detections=raw["detections"],
            detection_count=raw["detection_count"],
            timing_ms=raw["timing_ms"],
            inference_log_id=log_id,
            severity=severity,
        )

    async def _persist_detections(
        self,
        model_name: str,
        model_version: str,
        media_id: Optional[uuid.UUID],
        duration_ms: int,
        detections: list[dict],
        orig_w: int,
        orig_h: int,
    ) -> None:
        """Shared DB persistence helper for both ONNX and LocateAnything results."""
        models = await self.model_repo.list()
        model_record = next((m for m in models if m.version == model_version), None)
        if model_record is None:
            model_record = await self.model_repo.create(
                AIModel(name=model_name, version=model_version, file_path="remote", is_active=True)
            )

        _media_id = media_id if media_id else _NULL_UUID
        log = AIInferenceLog(
            model_id=model_record.id,
            media_id=_media_id,
            inference_duration_ms=duration_ms,
            status="SUCCESS",
        )
        await self.inference_repo.create(log)

        for det in detections:
            bb = det.get("bounding_box", {})
            x_center_n = ((bb.get("x1", 0) + bb.get("x2", 0)) / 2.0) / orig_w if orig_w > 0 else 0.0
            y_center_n = ((bb.get("y1", 0) + bb.get("y2", 0)) / 2.0) / orig_h if orig_h > 0 else 0.0
            width_n = bb.get("width", 0) / orig_w if orig_w > 0 else 0.0
            height_n = bb.get("height", 0) / orig_h if orig_h > 0 else 0.0

            pred = AIPrediction(
                inference_log_id=log.id,
                class_name=det.get("class_name") or det.get("label", "damage"),
                confidence=Decimal(str(round(float(det.get("confidence") or det.get("grounding_score") or 0.0), 4))),
                bbox_x_center=Decimal(str(round(x_center_n, 5))),
                bbox_y_center=Decimal(str(round(y_center_n, 5))),
                bbox_width=Decimal(str(round(width_n, 5))),
                bbox_height=Decimal(str(round(height_n, 5))),
            )
            await self.prediction_repo.create(pred)
