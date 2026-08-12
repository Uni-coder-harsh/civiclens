"""
CivicLens AI Module — Dependency Injection.

Provides:
  - get_ai_service()         → existing repo-backed AIService
  - get_inference_engine()   → singleton CrackONNXInferenceEngine (loaded once at startup)
"""

import logging
import sys
import os
from typing import Optional
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.infrastructure.database import get_db_session
from app.modules.ai.repository import AIInferenceRepository, AIModelRepository, AIPredictionRepository
from app.modules.ai.service import AIService
from app.core.config import settings

logger = logging.getLogger("civiclens.ai.dependencies")

# ── ONNX Engine Singleton ─────────────────────────────────────────────────────
_inference_engine = None


def get_inference_engine():
    """
    Returns the singleton CrackONNXInferenceEngine.
    The engine is lazily initialized on first call and kept in memory for all subsequent requests.
    Raises RuntimeError if the model cannot be loaded.
    """
    global _inference_engine
    if _inference_engine is not None:
        return _inference_engine

    # Resolve ml-engine path relative to the backend working directory
    model_path = settings.MODEL_PATH
    if not os.path.isabs(model_path):
        # Resolve relative to the project root (one level above backend/)
        project_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
        model_path = os.path.join(project_root, model_path)

    # Add ml-engine to sys.path so the engine module is importable
    ml_engine_path = os.path.join(project_root, "ml-engine")
    if ml_engine_path not in sys.path:
        sys.path.insert(0, ml_engine_path)

    try:
        # ── Download model from Supabase/CDN if not present locally (Railway support) ──
        if not os.path.exists(model_path):
            download_url = settings.MODEL_DOWNLOAD_URL
            if download_url:
                logger.info(f"[ONNXEngine] Model not found locally. Downloading from {download_url} ...")
                import urllib.request
                os.makedirs(os.path.dirname(model_path) or ".", exist_ok=True)
                urllib.request.urlretrieve(download_url, model_path)
                logger.info(f"[ONNXEngine] Model downloaded to {model_path} ({os.path.getsize(model_path)//1024//1024} MB)")
            else:
                logger.warning(f"[ONNXEngine] Model not found at {model_path} and MODEL_DOWNLOAD_URL is not set. Inference unavailable.")
                _inference_engine = None
                return _inference_engine

        from src.inference.engine import CrackONNXInferenceEngine
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
        logger.error(f"[ONNXEngine] Failed to load engine: {e}")
        _inference_engine = None

    return _inference_engine


# ── Existing AI Service DI ────────────────────────────────────────────────────

def get_ai_service(db: AsyncSession = Depends(get_db_session)) -> AIService:
    return AIService(AIModelRepository(db), AIInferenceRepository(db), AIPredictionRepository(db))
