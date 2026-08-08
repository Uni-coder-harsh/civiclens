from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.infrastructure.database import get_db_session
from app.modules.passport.repository import DegradationHistoryRepository, PassportRepository
from app.modules.passport.service import PassportService


def get_passport_service(db: AsyncSession = Depends(get_db_session)) -> PassportService:
    return PassportService(PassportRepository(db), DegradationHistoryRepository(db))
