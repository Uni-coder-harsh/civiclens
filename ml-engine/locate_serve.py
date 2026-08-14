"""
CivicLens — LocateAnything-3B Inference Service
ml-engine/locate_serve.py

FastAPI service that loads LocateAnything-3B ONCE at startup and exposes
a /detect endpoint for the CivicLens backend to call.

Architecture:
    CivicLens FastAPI Backend (Railway)
        ↓  HTTP POST /detect
    This service (Lightning AI GPU)
        ↓
    LocateAnything-3B
        ↓
    Normalized JSON → Backend → Flutter

Security:
    - Set LA_SERVICE_SECRET env var on both sides for shared-secret auth
    - File size capped to 20MB
    - MIME type validated
    - Image dimensions validated

Usage (Lightning Studio):
    export LA_SERVICE_SECRET=your-secret-here
    python ml-engine/locate_serve.py

    # Or with uvicorn directly:
    uvicorn ml-engine.locate_serve:app --host 0.0.0.0 --port 8000

Environment variables:
    LA_SERVICE_SECRET   — Bearer token for authenticating backend requests
    LA_DEVICE           — "cuda" (default) or "cpu"
    LA_DTYPE            — "bfloat16" (default) or "float16"
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
LA_DEVICE: str = os.getenv("LA_DEVICE", "cuda")
LA_DTYPE: str = os.getenv("LA_DTYPE", "bfloat16")
LA_MAX_IMAGE_MB: int = int(os.getenv("LA_MAX_IMAGE_MB", "20"))
PORT: int = int(os.getenv("PORT", "8000"))
MAX_IMAGE_BYTES = LA_MAX_IMAGE_MB * 1024 * 1024

ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}

# ── Global engine singleton ───────────────────────────────────────────────────
_engine: "LocateAnythingEngine | None" = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load LocateAnything-3B ONCE at startup. Keep in VRAM for all requests."""
    global _engine
    import sys
    from pathlib import Path
    # Allow importing the engine when running from repo root or ml-engine/
    for p in [str(Path(__file__).parent), str(Path(__file__).parent.parent)]:
        if p not in sys.path:
            sys.path.insert(0, p)

    from src.locate_anything import LocateAnythingEngine
    logger.info(f"[Startup] Loading LocateAnything-3B on {LA_DEVICE} ({LA_DTYPE})...")
    _engine = LocateAnythingEngine(device=LA_DEVICE, dtype_str=LA_DTYPE)
    try:
        _engine.load()
        logger.info(f"[Startup] Model ready. Load time: {_engine._load_time_ms:.0f}ms")
    except Exception as e:
        logger.error(f"[Startup] FAILED to load model: {e}")
        # Don't crash the service — return 503 on requests if model not loaded
        _engine = None
    yield
    logger.info("[Shutdown] LocateAnything service stopping.")


# ── FastAPI app ───────────────────────────────────────────────────────────────
app = FastAPI(
    title="CivicLens LocateAnything-3B Inference Service",
    description="GPU inference endpoint for crack/damage localization. Called by CivicLens backend.",
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
    engine_ok = _engine is not None and _engine.is_loaded()
    return {
        "status": "ok" if engine_ok else "degraded",
        "model": "nvidia/LocateAnything-3B",
        "engine_loaded": engine_ok,
    }


# ── Main inference endpoint ───────────────────────────────────────────────────
@app.post("/detect", dependencies=[Depends(verify_auth)])
async def detect(
    image: UploadFile = File(..., description="Road/bridge image to inspect"),
    inspection_mode: str = Form(default="road", description="road | bridge | general_infrastructure"),
    prompt: Optional[str] = Form(default=None, description="Optional custom prompt override"),
    multi_prompt: bool = Form(default=False, description="Run multiple prompts and merge detections"),
    annotate: bool = Form(default=False, description="Include base64-encoded annotated image"),
):
    """
    Run LocateAnything-3B on the provided image.

    Returns normalized CivicLens detection JSON with bounding boxes.
    """
    t_req_start = time.perf_counter()

    # ── Model availability ────────────────────────────────────────────────────
    if _engine is None or not _engine.is_loaded():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="LocateAnything model is not loaded. GPU may be unavailable.",
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
    logger.info(f"[/detect] {image.filename} | {img_w}x{img_h} | mode={inspection_mode} | multi={multi_prompt}")
    try:
        if multi_prompt:
            result = _engine.detect_multi_prompt(pil_img, inspection_mode=inspection_mode)
        else:
            result = _engine.detect(pil_img, prompt=prompt, inspection_mode=inspection_mode)
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

    # ── Remove verbose debug fields from API response ─────────────────────────
    result.pop("raw_output", None)
    result.pop("raw_outputs", None)

    total_api_ms = round((time.perf_counter() - t_req_start) * 1000, 2)
    result["api_latency_ms"] = total_api_ms

    return JSONResponse(content=result)


# ── Performance benchmark endpoint ────────────────────────────────────────────
@app.post("/benchmark", dependencies=[Depends(verify_auth)])
async def benchmark(image: UploadFile = File(...)):
    """
    Phase 16: Run 5 consecutive inferences on the same image to measure
    warm inference latency and throughput.
    """
    if _engine is None or not _engine.is_loaded():
        raise HTTPException(status_code=503, detail="Model not loaded.")

    raw_bytes = await image.read()
    pil_img = Image.open(io.BytesIO(raw_bytes)).convert("RGB")

    timings = []
    for i in range(5):
        result = _engine.detect(pil_img)
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
