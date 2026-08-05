import uuid
from fastapi import APIRouter, Depends
from app.modules.auth.dependencies import get_current_user
from app.modules.auth.model import User
from app.modules.passport.dependencies import get_passport_service
from app.modules.passport.schema import DegradationHistoryResponse, PassportResponse
from app.modules.passport.service import PassportService


router = APIRouter(prefix="/passport", tags=["Infrastructure Passport"])


@router.get("/passports/{asset_id}", response_model=PassportResponse)
async def get_passport(
    asset_id: uuid.UUID,
    _: User = Depends(get_current_user),
    service: PassportService = Depends(get_passport_service),
):
    return await service.get_or_create_for_asset(asset_id)


@router.get("/passports/{passport_id}/history", response_model=list[DegradationHistoryResponse])
async def get_passport_history(
    passport_id: uuid.UUID,
    _: User = Depends(get_current_user),
    service: PassportService = Depends(get_passport_service),
):
    return await service.get_history(passport_id)
