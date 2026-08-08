import uuid
from fastapi import APIRouter, Depends, status
from app.modules.auth.constants import RoleEnum
from app.modules.auth.dependencies import RoleChecker, get_current_user
from app.modules.auth.model import User
from app.modules.severity.dependencies import get_severity_service
from app.modules.severity.schema import AssessmentResponse, SeverityAssessmentRequest, SeverityOverride, SeverityRuleCreate, SeverityRuleResponse
from app.modules.severity.service import SeverityService


router = APIRouter(prefix="/severity", tags=["Severity Engine"])
admin_only = RoleChecker([RoleEnum.ORG_ADMIN.value, RoleEnum.SUPER_ADMIN.value])
inspector_only = RoleChecker([RoleEnum.INSPECTOR.value, RoleEnum.ORG_ADMIN.value, RoleEnum.SUPER_ADMIN.value])


@router.get("/rules", response_model=list[SeverityRuleResponse])
async def list_rules(_: User = Depends(get_current_user), service: SeverityService = Depends(get_severity_service)):
    return await service.list_rules()


@router.post("/rules", status_code=status.HTTP_201_CREATED, response_model=SeverityRuleResponse)
async def create_rule(data: SeverityRuleCreate, _: User = Depends(admin_only), service: SeverityService = Depends(get_severity_service)):
    return await service.create_rule(data)


@router.post("/assess/{item_id}", response_model=AssessmentResponse)
async def assess_item(item_id: uuid.UUID, data: SeverityAssessmentRequest, _: User = Depends(inspector_only), service: SeverityService = Depends(get_severity_service)):
    return await service.assess(item_id, data)


@router.patch("/override/{item_id}", response_model=AssessmentResponse)
async def override_item(item_id: uuid.UUID, data: SeverityOverride, _: User = Depends(admin_only), service: SeverityService = Depends(get_severity_service)):
    return await service.override(item_id, data)
