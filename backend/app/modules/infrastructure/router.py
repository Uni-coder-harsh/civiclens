import uuid
from fastapi import APIRouter, Depends, Query, status
from app.modules.auth.constants import RoleEnum
from app.modules.auth.dependencies import RoleChecker, get_current_user
from app.modules.auth.model import User
from app.modules.infrastructure.dependencies import get_infrastructure_service
from app.modules.infrastructure.schema import AssetCreate, AssetResponse, AssetUpdate
from app.modules.infrastructure.service import InfrastructureService


router = APIRouter(prefix="/infrastructure", tags=["Infrastructure"])
admin_only = RoleChecker([RoleEnum.ORG_ADMIN.value, RoleEnum.SUPER_ADMIN.value])


@router.get("/assets/nearby")
async def nearby_assets(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    radius: float = Query(5000, gt=0),
    current_user: User = Depends(get_current_user),
    service: InfrastructureService = Depends(get_infrastructure_service),
):
    return await service.nearby(current_user, lat, lon, radius)


@router.get("/assets", response_model=list[AssetResponse])
async def list_assets(
    skip: int = 0,
    limit: int = Query(100, le=500),
    asset_type: str | None = None,
    asset_status: str | None = None,
    current_user: User = Depends(get_current_user),
    service: InfrastructureService = Depends(get_infrastructure_service),
):
    return await service.list_assets(current_user, skip, limit, asset_type, asset_status)


@router.post("/assets", status_code=status.HTTP_201_CREATED, response_model=AssetResponse)
async def create_asset(
    data: AssetCreate,
    current_user: User = Depends(admin_only),
    service: InfrastructureService = Depends(get_infrastructure_service),
):
    return await service.create_asset(data, current_user)


@router.get("/assets/{asset_id}", response_model=AssetResponse)
async def get_asset(
    asset_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    service: InfrastructureService = Depends(get_infrastructure_service),
):
    return await service.get_asset(asset_id, current_user)


@router.put("/assets/{asset_id}", response_model=AssetResponse)
async def update_asset(
    asset_id: uuid.UUID,
    data: AssetUpdate,
    current_user: User = Depends(admin_only),
    service: InfrastructureService = Depends(get_infrastructure_service),
):
    return await service.update_asset(asset_id, data, current_user)


@router.delete("/assets/{asset_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_asset(
    asset_id: uuid.UUID,
    current_user: User = Depends(admin_only),
    service: InfrastructureService = Depends(get_infrastructure_service),
):
    await service.delete_asset(asset_id, current_user)
