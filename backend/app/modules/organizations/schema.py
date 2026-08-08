import uuid
from datetime import datetime
from pydantic import EmailStr, Field
from app.common.schemas import BaseRequestSchema, BaseResponseSchema
from app.modules.organizations.constants import BillingPlan, OrganizationRole


class OrganizationCreate(BaseRequestSchema):
    name: str = Field(..., min_length=2, max_length=255)
    description: str | None = None
    logo_url: str | None = None
    billing_plan: BillingPlan = BillingPlan.FREE


class OrganizationUpdate(BaseRequestSchema):
    name: str | None = Field(default=None, min_length=2, max_length=255)
    description: str | None = None
    logo_url: str | None = None
    billing_plan: BillingPlan | None = None


class OrganizationResponse(BaseResponseSchema):
    name: str
    description: str | None = None
    logo_url: str | None = None
    billing_plan: str


class MemberInvite(BaseRequestSchema):
    email: EmailStr
    full_name: str = Field(..., min_length=1, max_length=255)
    role_in_org: OrganizationRole = OrganizationRole.MEMBER


class MemberRoleUpdate(BaseRequestSchema):
    role_in_org: OrganizationRole


class MembershipResponse(BaseResponseSchema):
    organization_id: uuid.UUID
    user_id: uuid.UUID
    department_id: uuid.UUID | None = None
    role_in_org: str
    created_at: datetime
