from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.infrastructure.database import get_db_session
from app.modules.inspections.repository import InspectionItemRepository, InspectionMediaRepository, InspectionRepository
from app.modules.inspections.service import InspectionService


def get_inspection_service(db: AsyncSession = Depends(get_db_session)) -> InspectionService:
    return InspectionService(InspectionRepository(db), InspectionItemRepository(db), InspectionMediaRepository(db))
