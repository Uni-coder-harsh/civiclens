import uuid
from fastapi import APIRouter, Depends, status
from app.modules.auth.constants import RoleEnum
from app.modules.auth.dependencies import RoleChecker, get_current_user
from app.modules.auth.model import User
from app.modules.organizations.dependencies import get_organization_service
from app.modules.organizations.schema import (
    MemberInvite,
    MemberRoleUpdate,
    MembershipResponse,
    OrganizationCreate,
    OrganizationResponse,
    OrganizationUpdate,
)
from app.modules.organizations.service import OrganizationService


router = APIRouter(prefix="/organizations", tags=["Organizations"])
admin_only = RoleChecker([RoleEnum.ORG_ADMIN.value, RoleEnum.SUPER_ADMIN.value])


@router.post("", status_code=status.HTTP_201_CREATED, response_model=OrganizationResponse)
async def create_organization(
    data: OrganizationCreate,
    current_user: User = Depends(admin_only),
    service: OrganizationService = Depends(get_organization_service),
):
    return await service.create(data, current_user)


@router.get("/my-org", response_model=OrganizationResponse)
async def get_my_organization(
    current_user: User = Depends(get_current_user),
    service: OrganizationService = Depends(get_organization_service),
):
    return await service.get_current_organization(current_user)


@router.patch("/my-org", response_model=OrganizationResponse)
async def update_my_organization(
    data: OrganizationUpdate,
    current_user: User = Depends(admin_only),
    service: OrganizationService = Depends(get_organization_service),
):
    return await service.update_current_organization(data, current_user)


@router.get("/members", response_model=list[MembershipResponse])
async def list_members(
    current_user: User = Depends(get_current_user),
    service: OrganizationService = Depends(get_organization_service),
):
    return await service.list_members(current_user)


@router.post("/members/invite", status_code=status.HTTP_201_CREATED, response_model=MembershipResponse)
async def invite_member(
    data: MemberInvite,
    current_user: User = Depends(admin_only),
    service: OrganizationService = Depends(get_organization_service),
):
    return await service.invite_member(data, current_user)


@router.patch("/members/{user_id}", response_model=MembershipResponse)
async def update_member_role(
    user_id: uuid.UUID,
    data: MemberRoleUpdate,
    current_user: User = Depends(admin_only),
    service: OrganizationService = Depends(get_organization_service),
):
    return await service.update_member_role(user_id, data, current_user)


@router.delete("/members/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_member(
    user_id: uuid.UUID,
    current_user: User = Depends(admin_only),
    service: OrganizationService = Depends(get_organization_service),
):
    await service.remove_member(user_id, current_user)
