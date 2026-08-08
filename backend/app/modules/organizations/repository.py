import uuid
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.common.repositories import BaseRepository
from app.modules.organizations.model import Organization, OrganizationMembership


class OrganizationRepository(BaseRepository[Organization]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(Organization, db_session)


class MembershipRepository(BaseRepository[OrganizationMembership]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(OrganizationMembership, db_session)

    async def get_by_user(self, user_id: uuid.UUID) -> OrganizationMembership | None:
        query = (
            select(OrganizationMembership)
            .where(OrganizationMembership.user_id == user_id)
            .where(OrganizationMembership.is_deleted == False)
            .limit(1)
        )
        result = await self.session.execute(query)
        return result.scalar_one_or_none()

    async def get_member(self, organization_id: uuid.UUID, user_id: uuid.UUID) -> OrganizationMembership | None:
        query = (
            select(OrganizationMembership)
            .where(OrganizationMembership.organization_id == organization_id)
            .where(OrganizationMembership.user_id == user_id)
            .where(OrganizationMembership.is_deleted == False)
        )
        result = await self.session.execute(query)
        return result.scalar_one_or_none()

    async def list_members(self, organization_id: uuid.UUID) -> list[OrganizationMembership]:
        query = (
            select(OrganizationMembership)
            .where(OrganizationMembership.organization_id == organization_id)
            .where(OrganizationMembership.is_deleted == False)
        )
        result = await self.session.execute(query)
        return list(result.scalars().all())
