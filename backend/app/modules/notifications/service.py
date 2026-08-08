import uuid
from datetime import datetime, timezone
from app.core.exceptions import ResourceNotFoundException
from app.core.logging import logger
from app.modules.auth.model import User
from app.modules.notifications.constants import NotificationStatus
from app.modules.notifications.model import Notification
from app.modules.notifications.repository import NotificationRepository
from app.modules.notifications.schema import NotificationCreate


class NotificationService:
    def __init__(self, notification_repo: NotificationRepository):
        self.notification_repo = notification_repo

    async def create(self, data: NotificationCreate, user: User) -> Notification:
        notification = Notification(
            recipient_id=data.recipient_id,
            channel=data.channel.value,
            subject=data.subject,
            body=data.body,
            status=NotificationStatus.SENT.value,
            sent_at=datetime.now(timezone.utc),
            created_by=user.id,
        )
        logger.info(f"Mock notification dispatched to {data.recipient_id}: {data.subject or data.body[:60]}")
        return await self.notification_repo.create(notification)

    async def list_for_current_user(self, user: User) -> list[Notification]:
        return await self.notification_repo.list_for_user(user.id)

    async def mark_read(self, notification_id: uuid.UUID, user: User) -> Notification:
        notification = await self.notification_repo.get_by_id(notification_id)
        if not notification or notification.recipient_id != user.id:
            raise ResourceNotFoundException(message="Notification not found.")
        notification.status = NotificationStatus.SENT.value
        notification.sent_at = notification.sent_at or datetime.now(timezone.utc)
        notification.updated_by = user.id
        return await self.notification_repo.update(notification)
