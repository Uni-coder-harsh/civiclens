from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.infrastructure.database import get_db_session
from app.modules.infrastructure.repository import InfrastructureAssetRepository
from app.modules.infrastructure.service import InfrastructureService
from app.modules.organizations.repository import MembershipRepository


def get_infrastructure_service(db: AsyncSession = Depends(get_db_session)) -> InfrastructureService:
    return InfrastructureService(InfrastructureAssetRepository(db), MembershipRepository(db))
