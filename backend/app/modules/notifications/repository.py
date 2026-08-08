import uuid
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.common.repositories import BaseRepository
from app.modules.notifications.model import Notification, NotificationTemplate


class NotificationRepository(BaseRepository[Notification]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(Notification, db_session)

    async def list_for_user(self, user_id: uuid.UUID, unread_only: bool = False) -> list[Notification]:
        query = (
            select(Notification)
            .where(Notification.recipient_id == user_id)
            .where(Notification.is_deleted == False)
        )
        if unread_only:
            query = query.where(Notification.sent_at.is_(None))
        result = await self.session.execute(query.order_by(Notification.created_at.desc()))
        return list(result.scalars().all())


class NotificationTemplateRepository(BaseRepository[NotificationTemplate]):
    def __init__(self, db_session: AsyncSession):
        super().__init__(NotificationTemplate, db_session)
