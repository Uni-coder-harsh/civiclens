"""
CivicLens — ONNX YOLO Crack Detection Inference Service
ml-engine/locate_serve.py

FastAPI service that loads the ONNX YOLO11 model ONCE at startup and exposes
a /detect endpoint for the CivicLens backend to call.

Architecture:
    CivicLens FastAPI Backend (Railway)
        ↓  HTTP POST /detect
    This service (Railway / any server with CPU)
        ↓
    ONNX YOLO11 Crack Detector (640x640 input)
        ↓
    Normalized JSON → Backend → Flutter

Security:
    - Set LA_SERVICE_SECRET env var on both sides for shared-secret auth
    - File size capped to 20MB
    - MIME type validated
    - Image dimensions validated

Usage:
    python ml-engine/locate_serve.py

    # Or with uvicorn directly:
    uvicorn locate_serve:app --host 0.0.0.0 --port 8000

Environment variables:
    LA_SERVICE_SECRET   — Bearer token for authenticating backend requests
    MODEL_PATH          — Path to best.onnx (default: ml-engine/best.onnx)
    LA_MAX_IMAGE_MB     — Max upload size in MB (default: 20)
    PORT                — HTTP port (default: 8000)
"""
from __future__ import annotations

import io
import os
import logging
import time
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, File, Form, UploadFile, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import JSONResponse
from PIL import Image

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)
logger = logging.getLogger("locate_serve")

# ── Configuration (from environment) ─────────────────────────────────────────
LA_SERVICE_SECRET: str | None = os.getenv("LA_SERVICE_SECRET")
MODEL_PATH: str = os.getenv("MODEL_PATH", "ml-engine/best.onnx")
LA_MAX_IMAGE_MB: int = int(os.getenv("LA_MAX_IMAGE_MB", "20"))
PORT: int = int(os.getenv("PORT", "8000"))
MAX_IMAGE_BYTES = LA_MAX_IMAGE_MB * 1024 * 1024

ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}

# ── Global engine singleton ───────────────────────────────────────────────────
_engine = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load ONNX YOLO model ONCE at startup. Keep in memory for all requests."""
    global _engine
    import sys
    from pathlib import Path
    # Allow importing the engine when running from repo root or ml-engine/
    for p in [str(Path(__file__).parent), str(Path(__file__).parent.parent)]:
        if p not in sys.path:
            sys.path.insert(0, p)

    from src.inference.engine import CrackONNXInferenceEngine

    model_path = MODEL_PATH
    if not os.path.isabs(model_path):
        model_path = str(Path(__file__).parent / model_path.lstrip("ml-engine/"))
        if not os.path.exists(model_path):
            model_path = MODEL_PATH  # fallback to original

    logger.info(f"[Startup] Loading ONNX model from {model_path}...")
    t0 = time.perf_counter()
    try:
        _engine = CrackONNXInferenceEngine(
            model_path=model_path,
            provider="CPUExecutionProvider",
            conf_threshold=0.25,
            iou_threshold=0.45,
            input_size=640,
            version="crack-detector-v1",
        )
        load_ms = (time.perf_counter() - t0) * 1000
        logger.info(f"[Startup] Model ready. Load time: {load_ms:.0f}ms")
    except Exception as e:
        logger.error(f"[Startup] FAILED to load model: {e}")
        _engine = None
    yield
    logger.info("[Shutdown] ONNX inference service stopping.")


# ── FastAPI app ───────────────────────────────────────────────────────────────
app = FastAPI(
    title="CivicLens ONNX Crack Detection Service",
    description="CPU inference endpoint for road crack/damage detection. Called by CivicLens backend.",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url=None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST", "GET"],
    allow_headers=["Authorization", "Content-Type"],
)

# ── Auth ──────────────────────────────────────────────────────────────────────
bearer_scheme = HTTPBearer(auto_error=False)


def verify_auth(credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme)):
    """Require Bearer token if LA_SERVICE_SECRET is configured."""
    if LA_SERVICE_SECRET:
        if credentials is None or credentials.credentials != LA_SERVICE_SECRET:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or missing authentication token.",
                headers={"WWW-Authenticate": "Bearer"},
            )


# ── Health check ──────────────────────────────────────────────────────────────
@app.get("/health")
async def health():
    """Health probe — returns model status without auth."""
    engine_ok = _engine is not None
    return {
        "status": "ok" if engine_ok else "degraded",
        "model": "civiclens-crack-detector-onnx",
        "engine_loaded": engine_ok,
    }


# ── Main inference endpoint ───────────────────────────────────────────────────
@app.post("/detect", dependencies=[Depends(verify_auth)])
async def detect(
    image: UploadFile = File(..., description="Road/bridge image to inspect"),
    conf_threshold: Optional[float] = Form(default=None, description="Confidence threshold override"),
    iou_threshold: Optional[float] = Form(default=None, description="IOU threshold override"),
    annotate: bool = Form(default=False, description="Include base64-encoded annotated image"),
):
    """
    Run ONNX YOLO crack detection on the provided image.

    The engine handles letterboxing to 640x640 internally and maps
    bounding boxes back to original image coordinates.

    Returns normalized CivicLens detection JSON with bounding boxes.
    """
    t_req_start = time.perf_counter()

    # ── Model availability ────────────────────────────────────────────────────
    if _engine is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="ONNX model is not loaded.",
        )

    # ── Validate file size ────────────────────────────────────────────────────
    raw_bytes = await image.read()
    if len(raw_bytes) > MAX_IMAGE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Image exceeds {LA_MAX_IMAGE_MB}MB limit.",
        )

    # ── Validate MIME type ────────────────────────────────────────────────────
    content_type = image.content_type or ""
    if content_type not in ALLOWED_MIME_TYPES and not content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported image type: {content_type}. Accepted: JPEG, PNG, WebP, HEIC.",
        )

    # ── Validate image can be opened ──────────────────────────────────────────
    try:
        pil_img = Image.open(io.BytesIO(raw_bytes)).convert("RGB")
        img_w, img_h = pil_img.size
        if img_w < 32 or img_h < 32:
            raise ValueError(f"Image too small: {img_w}x{img_h}")
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Cannot open image: {e}",
        )

    # ── Run inference ─────────────────────────────────────────────────────────
    logger.info(f"[/detect] {image.filename} | {img_w}x{img_h}")
    try:
        result = _engine.detect(
            raw_bytes,
            conf_threshold=conf_threshold,
            iou_threshold=iou_threshold,
        )
    except Exception as e:
        logger.exception(f"[/detect] Inference error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Inference failed: {str(e)}",
        )

    # ── Optional annotated image (base64) ─────────────────────────────────────
    if annotate and result["detection_count"] > 0:
        try:
            import base64
            ann_img = _engine.annotate(pil_img, result["detections"])
            buf = io.BytesIO()
            ann_img.save(buf, format="JPEG", quality=92)
            result["annotated_image_b64"] = base64.b64encode(buf.getvalue()).decode()
        except Exception as e:
            logger.warning(f"[/detect] Annotation failed: {e}")

    total_api_ms = round((time.perf_counter() - t_req_start) * 1000, 2)
    result["api_latency_ms"] = total_api_ms

    return JSONResponse(content=result)


# ── Performance benchmark endpoint ────────────────────────────────────────────
@app.post("/benchmark", dependencies=[Depends(verify_auth)])
async def benchmark(image: UploadFile = File(...)):
    """
    Run 5 consecutive inferences on the same image to measure
    warm inference latency and throughput.
    """
    if _engine is None:
        raise HTTPException(status_code=503, detail="Model not loaded.")

    raw_bytes = await image.read()

    timings = []
    for i in range(5):
        result = _engine.detect(raw_bytes)
        timings.append(result["timing_ms"]["total"])

    return {
        "benchmark_runs": 5,
        "timings_ms": timings,
        "avg_inference_ms": round(sum(timings) / len(timings), 2),
        "min_ms": round(min(timings), 2),
        "max_ms": round(max(timings), 2),
        "image": result["image"],
    }


# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "locate_serve:app",
        host="0.0.0.0",
        port=PORT,
        log_level="info",
    )
