import uuid
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from geoalchemy2.functions import ST_DWithin, ST_MakeEnvelope, ST_MakePoint, ST_SetSRID
from app.common.repositories import BaseRepository
from app.modules.infrastructure.model import InfrastructureAsset


class InfrastructureAssetRepository(BaseRepository[InfrastructureAsset]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(InfrastructureAsset, db_session)

    async def search(
        self,
        organization_id: uuid.UUID,
        skip: int = 0,
        limit: int = 100,
        asset_type: str | None = None,
        status: str | None = None,
    ) -> list[InfrastructureAsset]:
        query = (
            select(InfrastructureAsset)
            .where(InfrastructureAsset.organization_id == organization_id)
            .where(InfrastructureAsset.is_deleted == False)
        )
        if asset_type:
            query = query.where(InfrastructureAsset.type == asset_type)
        if status:
            query = query.where(InfrastructureAsset.status == status)
        result = await self.session.execute(query.offset(skip).limit(limit))
        return list(result.scalars().all())

    async def nearby(self, organization_id: uuid.UUID, lat: float, lon: float, radius_m: float) -> list[InfrastructureAsset]:
        point = ST_SetSRID(ST_MakePoint(lon, lat), 4326)
        query = (
            select(InfrastructureAsset)
            .where(InfrastructureAsset.organization_id == organization_id)
            .where(InfrastructureAsset.is_deleted == False)
            .where(ST_DWithin(InfrastructureAsset.geometry, point, radius_m))
        )
        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def within_bbox(
        self,
        organization_id: uuid.UUID,
        min_lon: float,
        min_lat: float,
        max_lon: float,
        max_lat: float,
    ) -> list[InfrastructureAsset]:
        envelope = ST_MakeEnvelope(min_lon, min_lat, max_lon, max_lat, 4326)
        query = (
            select(InfrastructureAsset)
            .where(InfrastructureAsset.organization_id == organization_id)
            .where(InfrastructureAsset.is_deleted == False)
            .where(InfrastructureAsset.geometry.ST_Within(envelope))
        )
        result = await self.session.execute(query)
        return list(result.scalars().all())
