import uuid
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.common.repositories import BaseRepository
from app.modules.severity.model import AutomatedAssessment, SeverityRule


class SeverityRuleRepository(BaseRepository[SeverityRule]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(SeverityRule, db_session)


class AssessmentRepository(BaseRepository[AutomatedAssessment]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(AutomatedAssessment, db_session)

    async def get_by_item(self, item_id: uuid.UUID) -> AutomatedAssessment | None:
        result = await self.session.execute(
            select(AutomatedAssessment).where(AutomatedAssessment.inspection_item_id == item_id)
        )
        return result.scalar_one_or_none()
