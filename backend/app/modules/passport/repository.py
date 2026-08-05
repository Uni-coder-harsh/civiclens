import uuid
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.common.repositories import BaseRepository
from app.modules.passport.model import AssetDegradationHistory, InfrastructurePassport


class PassportRepository(BaseRepository[InfrastructurePassport]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(InfrastructurePassport, db_session)

    async def get_by_asset(self, asset_id: uuid.UUID) -> InfrastructurePassport | None:
        result = await self.session.execute(
            select(InfrastructurePassport)
            .where(InfrastructurePassport.asset_id == asset_id)
            .where(InfrastructurePassport.is_deleted == False)
        )
        return result.scalar_one_or_none()


class DegradationHistoryRepository(BaseRepository[AssetDegradationHistory]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(AssetDegradationHistory, db_session)

    async def list_by_passport(self, passport_id: uuid.UUID) -> list[AssetDegradationHistory]:
        result = await self.session.execute(
            select(AssetDegradationHistory).where(AssetDegradationHistory.passport_id == passport_id)
        )
        return list(result.scalars().all())
