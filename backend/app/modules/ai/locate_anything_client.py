"""
CivicLens AI Module — LocateAnything-3B HTTP Client
backend/app/modules/ai/locate_anything_client.py

Thin HTTP client that calls the remote LocateAnything-3B inference service
running on Lightning AI GPU. The CivicLens FastAPI backend calls this client;
it does NOT load the 3B model locally.

Architecture:
    Flutter → FastAPI Backend (Railway) → This client → Lightning GPU → LocateAnything-3B

The client normalizes the LA response into the existing CivicLens
DetectionResult schema so the rest of the system is model-agnostic.
"""
from __future__ import annotations

import logging
from typing import Any, Optional
from io import BytesIO

import httpx

from app.core.config import settings
from app.modules.ai.schema import DetectionResult

logger = logging.getLogger(__name__)


class LocateAnythingClient:
    """
    HTTP client for the remote LocateAnything-3B inference service.
    Instantiate once and reuse across requests (connection pooling).
    """

    def __init__(
        self,
        base_url: Optional[str] = None,
        secret: Optional[str] = None,
        timeout: int = 60,
    ):
        self._base_url = (base_url or settings.LA_INFERENCE_URL or "").rstrip("/")
        self._secret = secret or settings.LA_SERVICE_SECRET
        self._timeout = timeout or settings.LA_TIMEOUT_SECONDS

        if not self._base_url:
            raise ValueError(
                "LA_INFERENCE_URL is not configured. "
                "Set it in your Railway environment variables once the Lightning service is deployed."
            )

    # ── Health ────────────────────────────────────────────────────────────────

    async def health(self) -> dict[str, Any]:
        """Check if the Lightning inference service is alive."""
        try:
            async with httpx.AsyncClient(timeout=10) as client:
                resp = await client.get(f"{self._base_url}/health")
                resp.raise_for_status()
                return resp.json()
        except Exception as e:
            logger.warning(f"[LAClient] Health check failed: {e}")
            return {"status": "unreachable", "error": str(e)}

    # ── Main inference ────────────────────────────────────────────────────────

    async def detect(
        self,
        image_bytes: bytes,
        filename: str = "image.jpg",
        inspection_mode: str = "road",
        prompt: Optional[str] = None,
        multi_prompt: bool = False,
    ) -> dict[str, Any]:
        """
        Send image to Lightning LocateAnything service and return raw result dict.
        The result is already normalized into CivicLens format by the service.

        Raises:
            httpx.HTTPStatusError  — non-2xx from service (e.g. 503 model not loaded)
            httpx.TimeoutException — inference took longer than timeout
            ValueError             — invalid response format
        """
        headers = {}
        if self._secret:
            headers["Authorization"] = f"Bearer {self._secret}"

        data = {
            "inspection_mode": inspection_mode,
            "multi_prompt": str(multi_prompt).lower(),
        }
        if prompt:
            data["prompt"] = prompt

        files = {"image": (filename, image_bytes, "image/jpeg")}

        logger.info(f"[LAClient] POST {self._base_url}/detect | mode={inspection_mode} | size={len(image_bytes)} bytes")
        async with httpx.AsyncClient(timeout=self._timeout) as client:
            resp = await client.post(
                f"{self._base_url}/detect",
                headers=headers,
                data=data,
                files=files,
            )

        if resp.status_code == 503:
            raise RuntimeError("LocateAnything model is not loaded on the GPU server (503). Try again in 30s.")
        if resp.status_code == 401:
            raise PermissionError("LA_SERVICE_SECRET mismatch. Check backend and Lightning env vars.")

        resp.raise_for_status()
        result = resp.json()
        logger.info(f"[LAClient] Response: {result.get('detection_count', 0)} detections in {result.get('timing_ms', {}).get('total', '?')}ms")
        return result

    # ── Normalized adapter ────────────────────────────────────────────────────

    async def detect_and_normalize(
        self,
        image_bytes: bytes,
        filename: str = "image.jpg",
        inspection_mode: str = "road",
        prompt: Optional[str] = None,
    ) -> DetectionResult:
        """
        Call the LA service and adapt the response to the existing CivicLens
        DetectionResult schema (same structure returned by the ONNX engine).

        This is the method that service.py should call when AI_PROVIDER=locateanything.
        """
        try:
            raw = await self.detect(image_bytes, filename, inspection_mode, prompt)
        except Exception as e:
            logger.error(f"[LAClient] Detection failed: {e}")
            return DetectionResult(
                status="failed",
                model={
                    "name": "LocateAnything-3B",
                    "version": "nvidia/LocateAnything-3B",
                    "runtime": "transformers",
                    "provider": "lightning_gpu",
                },
                image={"width": 0, "height": 0},
                detections=[],
                detection_count=0,
                timing_ms={"preprocess": 0, "inference": 0, "postprocess": 0, "total": 0},
                error_message=str(e),
            )

        # ── Adapt LA detection format to ONNX-compatible DetectionItem format ──
        # LA uses: {"label": "crack", "bounding_box": {...}, "grounding_score": ...}
        # ONNX uses: {"class_id": 0, "class_name": "...", "confidence": ..., "bounding_box": {...}}
        adapted_detections = []
        for i, det in enumerate(raw.get("detections", [])):
            bb = det.get("bounding_box", {})
            adapted_detections.append({
                "class_id": i,
                "class_name": det.get("label") or det.get("class_name", "damage"),
                "confidence": det.get("grounding_score") or det.get("confidence", 0.0),
                "bounding_box": {
                    "x1": bb.get("x1", 0),
                    "y1": bb.get("y1", 0),
                    "x2": bb.get("x2", 0),
                    "y2": bb.get("y2", 0),
                    "width": bb.get("width", 0),
                    "height": bb.get("height", 0),
                },
            })

        timing = raw.get("timing_ms", {})
        return DetectionResult(
            status=raw.get("status", "completed"),
            model={
                "name": "LocateAnything-3B",
                "version": "nvidia/LocateAnything-3B",
                "runtime": "transformers",
                "provider": raw.get("model", {}).get("provider", "lightning_gpu"),
            },
            image=raw.get("image", {"width": 0, "height": 0}),
            detections=adapted_detections,
            detection_count=len(adapted_detections),
            timing_ms={
                "preprocess": timing.get("preprocess", 0),
                "inference": timing.get("inference", 0),
                "postprocess": timing.get("postprocess", 0),
                "total": timing.get("total", 0),
            },
        )
