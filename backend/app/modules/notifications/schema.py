import uuid
from datetime import datetime
from pydantic import Field
from app.common.schemas import BaseRequestSchema, BaseResponseSchema
from app.modules.notifications.constants import NotificationChannel


class NotificationCreate(BaseRequestSchema):
    recipient_id: uuid.UUID
    channel: NotificationChannel = NotificationChannel.WEB
    subject: str | None = Field(default=None, max_length=255)
    body: str = Field(..., min_length=1)


class NotificationResponse(BaseResponseSchema):
    recipient_id: uuid.UUID
    template_id: uuid.UUID | None = None
    channel: str
    subject: str | None = None
    body: str
    status: str
    sent_at: datetime | None = None
    failure_reason: str | None = None
