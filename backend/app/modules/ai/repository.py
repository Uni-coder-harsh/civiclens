import uuid
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.common.repositories import BaseRepository
from app.modules.ai.model import AIInferenceLog, AIModel, AIPrediction


class AIModelRepository(BaseRepository[AIModel]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(AIModel, db_session)


class AIInferenceRepository(BaseRepository[AIInferenceLog]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(AIInferenceLog, db_session)

    async def list_by_media(self, media_id: uuid.UUID) -> list[AIInferenceLog]:
        result = await self.session.execute(select(AIInferenceLog).where(AIInferenceLog.media_id == media_id))
        return list(result.scalars().all())


class AIPredictionRepository(BaseRepository[AIPrediction]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(AIPrediction, db_session)
