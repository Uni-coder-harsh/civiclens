from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.infrastructure.database import get_db_session
from app.modules.analytics.repository import AnalyticsRepository
from app.modules.analytics.service import AnalyticsService


def get_analytics_service(db: AsyncSession = Depends(get_db_session)) -> AnalyticsService:
    return AnalyticsService(AnalyticsRepository(db))
