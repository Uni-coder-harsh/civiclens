"""
CivicLens AI Module — Dependency Injection.

Provides:
  - get_ai_service()         → existing repo-backed AIService
  - get_inference_engine()   → singleton CrackONNXInferenceEngine (loaded once at startup)
"""

import logging
import os
from typing import Optional
from pathlib import Path
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.infrastructure.database import get_db_session
from app.modules.ai.repository import AIInferenceRepository, AIModelRepository, AIPredictionRepository
from app.modules.ai.service import AIService
from app.core.config import settings

logger = logging.getLogger("civiclens.ai.dependencies")

# ── ONNX Engine Singleton ─────────────────────────────────────────────────────
_inference_engine = None


def _resolve_runtime_root() -> Path:
    """
    Find the root where runtime assets should live.

    Local dev has ``ml-engine/src/inference/engine.py`` at the repository root.
    Railway's backend Docker image only contains the backend app under /app, so
    we fall back to the deployment root and download the model there.
    """
    current = Path(__file__).resolve()
    for parent in current.parents:
        if (parent / "ml-engine" / "src" / "inference" / "engine.py").exists():
            return parent
    for parent in current.parents:
        if (parent / "alembic.ini").exists():
            return parent
    return current.parents[3]


def get_inference_engine():
    """
    Returns the singleton CrackONNXInferenceEngine.
    The engine is lazily initialized on first call and kept in memory for all subsequent requests.
    Raises RuntimeError if the model cannot be loaded.
    """
    global _inference_engine
    if _inference_engine is not None:
        return _inference_engine

    # Resolve model path relative to the repo root locally, or /app in Railway.
    model_path = settings.MODEL_PATH
    runtime_root = _resolve_runtime_root()
    if not os.path.isabs(model_path):
        model_path = str(runtime_root / model_path)

    try:
        # ── Download model from Supabase/CDN if not present locally (Railway support) ──
        if not os.path.exists(model_path):
            download_url = settings.MODEL_DOWNLOAD_URL
            if download_url:
                logger.info(f"[ONNXEngine] Model not found locally. Downloading from HuggingFace CDN ...")
                import urllib.request
                import shutil
                os.makedirs(os.path.dirname(model_path) or ".", exist_ok=True)
                # Use urlopen so HTTP 302 redirects (HuggingFace CDN) are followed correctly
                with urllib.request.urlopen(download_url, timeout=120) as response, \
                     open(model_path, "wb") as out_file:
                    shutil.copyfileobj(response, out_file)
                logger.info(f"[ONNXEngine] Model downloaded to {model_path} ({os.path.getsize(model_path)//1024//1024} MB)")
            else:
                logger.warning(f"[ONNXEngine] Model not found at {model_path} and MODEL_DOWNLOAD_URL is not set. Inference unavailable.")
                _inference_engine = None
                return _inference_engine

        from app.modules.ai.onnx_engine import CrackONNXInferenceEngine
        _inference_engine = CrackONNXInferenceEngine(
            model_path=model_path,
            provider=settings.MODEL_PROVIDER,
            conf_threshold=settings.MODEL_CONFIDENCE_THRESHOLD,
            iou_threshold=settings.MODEL_IOU_THRESHOLD,
            input_size=settings.MODEL_INPUT_SIZE,
            version=settings.MODEL_VERSION,
        )
        logger.info(f"[ONNXEngine] Singleton loaded: {model_path}")
    except FileNotFoundError:
        logger.warning(f"[ONNXEngine] Model not found at {model_path}. Inference will be unavailable.")
        _inference_engine = None
    except Exception as e:
        logger.exception(f"[ONNXEngine] Failed to load engine: {e}")
        _inference_engine = None

    return _inference_engine


# ── Existing AI Service DI ────────────────────────────────────────────────────

def get_ai_service(db: AsyncSession = Depends(get_db_session)) -> AIService:
    return AIService(AIModelRepository(db), AIInferenceRepository(db), AIPredictionRepository(db))
