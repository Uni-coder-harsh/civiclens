from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.infrastructure.database import get_db_session
from app.modules.auth.repository import UserRepository
from app.modules.organizations.repository import MembershipRepository, OrganizationRepository
from app.modules.organizations.service import OrganizationService


def get_organization_service(db: AsyncSession = Depends(get_db_session)) -> OrganizationService:
    return OrganizationService(
        org_repo=OrganizationRepository(db),
        membership_repo=MembershipRepository(db),
        user_repo=UserRepository(db),
    )
