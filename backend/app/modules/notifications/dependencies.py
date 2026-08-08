from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.infrastructure.database import get_db_session
from app.modules.notifications.repository import NotificationRepository
from app.modules.notifications.service import NotificationService


def get_notification_service(db: AsyncSession = Depends(get_db_session)) -> NotificationService:
    return NotificationService(NotificationRepository(db))
