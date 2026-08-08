import uuid
from datetime import datetime, timezone
from app.core.exceptions import ResourceNotFoundException
from app.modules.auth.model import User
from app.modules.infrastructure.service import point_wkt
from app.modules.inspections.constants import InspectionStatus
from app.modules.inspections.model import Inspection, InspectionItem, InspectionMedia
from app.modules.inspections.repository import InspectionItemRepository, InspectionMediaRepository, InspectionRepository
from app.modules.inspections.schema import InspectionCreate, InspectionItemCreate, InspectionStatusUpdate, MediaCreate


class InspectionService:
    def __init__(self, inspection_repo: InspectionRepository, item_repo: InspectionItemRepository, media_repo: InspectionMediaRepository):
        self.inspection_repo = inspection_repo
        self.item_repo = item_repo
        self.media_repo = media_repo

    async def create(self, data: InspectionCreate, user: User) -> Inspection:
        inspection = Inspection(
            asset_id=data.asset_id,
            inspector_id=data.inspector_id or user.id,
            scheduled_at=data.scheduled_at,
            status=data.status.value,
            created_by=user.id,
        )
        return await self.inspection_repo.create(inspection)

    async def list(self, status: str | None = None, inspector_id: uuid.UUID | None = None) -> list[Inspection]:
        return await self.inspection_repo.list_filtered(status, inspector_id)

    async def get(self, inspection_id: uuid.UUID) -> Inspection:
        inspection = await self.inspection_repo.get_by_id(inspection_id)
        if not inspection:
            raise ResourceNotFoundException(message="Inspection not found.")
        return inspection

    async def update_status(self, inspection_id: uuid.UUID, data: InspectionStatusUpdate, user: User) -> Inspection:
        inspection = await self.get(inspection_id)
        inspection.status = data.status.value
        now = datetime.now(timezone.utc)
        if data.status == InspectionStatus.IN_PROGRESS and not inspection.started_at:
            inspection.started_at = now
        if data.status == InspectionStatus.COMPLETED:
            inspection.completed_at = now
        inspection.updated_by = user.id
        return await self.inspection_repo.update(inspection)

    async def add_item(self, inspection_id: uuid.UUID, data: InspectionItemCreate, user: User) -> InspectionItem:
        await self.get(inspection_id)
        item = InspectionItem(
            inspection_id=inspection_id,
            location_geometry=point_wkt(data.location.lat, data.location.lon),
            description=data.description,
            detected_severity=data.detected_severity.value,
            notes=data.notes,
            created_by=user.id,
        )
        return await self.item_repo.create(item)

    async def add_media(self, item_id: uuid.UUID, data: MediaCreate, user: User) -> InspectionMedia:
        item = await self.item_repo.get_by_id(item_id)
        if not item:
            raise ResourceNotFoundException(message="Inspection item not found.")
        media = InspectionMedia(
            inspection_item_id=item_id,
            media_type=data.media_type.value,
            file_url=data.file_url,
            file_size_bytes=data.file_size_bytes,
            mime_type=data.mime_type,
            created_by=user.id,
        )
        return await self.media_repo.create(media)
