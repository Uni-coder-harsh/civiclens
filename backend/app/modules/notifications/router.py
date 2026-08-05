import uuid
from fastapi import APIRouter, Depends, status
from app.modules.auth.constants import RoleEnum
from app.modules.auth.dependencies import RoleChecker, get_current_user
from app.modules.auth.model import User
from app.modules.notifications.dependencies import get_notification_service
from app.modules.notifications.schema import NotificationCreate, NotificationResponse
from app.modules.notifications.service import NotificationService


router = APIRouter(prefix="/notifications", tags=["Notifications"])
admin_only = RoleChecker([RoleEnum.ORG_ADMIN.value, RoleEnum.SUPER_ADMIN.value])


@router.post("", status_code=status.HTTP_201_CREATED, response_model=NotificationResponse)
async def create_notification(data: NotificationCreate, current_user: User = Depends(admin_only), service: NotificationService = Depends(get_notification_service)):
    return await service.create(data, current_user)


@router.get("/me", response_model=list[NotificationResponse])
async def my_notifications(current_user: User = Depends(get_current_user), service: NotificationService = Depends(get_notification_service)):
    return await service.list_for_current_user(current_user)


@router.patch("/{notification_id}/read", response_model=NotificationResponse)
async def mark_read(notification_id: uuid.UUID, current_user: User = Depends(get_current_user), service: NotificationService = Depends(get_notification_service)):
    return await service.mark_read(notification_id, current_user)
