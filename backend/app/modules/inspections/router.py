import uuid
from fastapi import APIRouter, Depends, status
from app.modules.auth.constants import RoleEnum
from app.modules.auth.dependencies import RoleChecker, get_current_user
from app.modules.auth.model import User
from app.modules.inspections.dependencies import get_inspection_service
from app.modules.inspections.schema import (
    InspectionCreate,
    InspectionItemCreate,
    InspectionItemResponse,
    InspectionResponse,
    InspectionStatusUpdate,
    MediaCreate,
    MediaResponse,
)
from app.modules.inspections.service import InspectionService


router = APIRouter(prefix="/inspection", tags=["Inspection"])
admin_only = RoleChecker([RoleEnum.ORG_ADMIN.value, RoleEnum.SUPER_ADMIN.value])
inspector_only = RoleChecker([RoleEnum.INSPECTOR.value, RoleEnum.ORG_ADMIN.value, RoleEnum.SUPER_ADMIN.value])


@router.post("/inspections", status_code=status.HTTP_201_CREATED, response_model=InspectionResponse)
async def create_inspection(data: InspectionCreate, current_user: User = Depends(admin_only), service: InspectionService = Depends(get_inspection_service)):
    return await service.create(data, current_user)


@router.get("/inspections", response_model=list[InspectionResponse])
async def list_inspections(status_filter: str | None = None, inspector_id: uuid.UUID | None = None, _: User = Depends(get_current_user), service: InspectionService = Depends(get_inspection_service)):
    return await service.list(status_filter, inspector_id)


@router.get("/inspections/{inspection_id}", response_model=InspectionResponse)
async def get_inspection(inspection_id: uuid.UUID, _: User = Depends(get_current_user), service: InspectionService = Depends(get_inspection_service)):
    return await service.get(inspection_id)


@router.patch("/inspections/{inspection_id}/status", response_model=InspectionResponse)
async def update_inspection_status(inspection_id: uuid.UUID, data: InspectionStatusUpdate, current_user: User = Depends(inspector_only), service: InspectionService = Depends(get_inspection_service)):
    return await service.update_status(inspection_id, data, current_user)


@router.post("/inspections/{inspection_id}/items", status_code=status.HTTP_201_CREATED, response_model=InspectionItemResponse)
async def add_inspection_item(inspection_id: uuid.UUID, data: InspectionItemCreate, current_user: User = Depends(inspector_only), service: InspectionService = Depends(get_inspection_service)):
    return await service.add_item(inspection_id, data, current_user)


@router.post("/items/{item_id}/media", status_code=status.HTTP_201_CREATED, response_model=MediaResponse)
async def add_item_media(item_id: uuid.UUID, data: MediaCreate, current_user: User = Depends(inspector_only), service: InspectionService = Depends(get_inspection_service)):
    return await service.add_media(item_id, data, current_user)
