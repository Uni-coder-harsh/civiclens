import uuid
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.common.repositories import BaseRepository
from app.modules.inspections.model import Inspection, InspectionItem, InspectionMedia


class InspectionRepository(BaseRepository[Inspection]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(Inspection, db_session)

    async def list_filtered(self, status: str | None = None, inspector_id: uuid.UUID | None = None) -> list[Inspection]:
        query = select(Inspection).where(Inspection.is_deleted == False)
        if status:
            query = query.where(Inspection.status == status)
        if inspector_id:
            query = query.where(Inspection.inspector_id == inspector_id)
        result = await self.session.execute(query)
        return list(result.scalars().all())


class InspectionItemRepository(BaseRepository[InspectionItem]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(InspectionItem, db_session)


class InspectionMediaRepository(BaseRepository[InspectionMedia]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(InspectionMedia, db_session)
