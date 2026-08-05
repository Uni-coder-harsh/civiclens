from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.infrastructure.database import get_db_session
from app.modules.ai.repository import AIInferenceRepository, AIModelRepository, AIPredictionRepository
from app.modules.ai.service import AIService


def get_ai_service(db: AsyncSession = Depends(get_db_session)) -> AIService:
    return AIService(AIModelRepository(db), AIInferenceRepository(db), AIPredictionRepository(db))
