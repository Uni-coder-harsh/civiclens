import uuid
from app.core.security import hash_password
from app.modules.auth.constants import RoleEnum
from app.modules.auth.model import Role, User
from app.modules.auth.repository import UserRepository
from app.modules.organizations.constants import OrganizationRole
from app.modules.organizations.exceptions import MembershipNotFoundException, OrganizationNotFoundException
from app.modules.organizations.model import Organization, OrganizationMembership
from app.modules.organizations.repository import MembershipRepository, OrganizationRepository
from app.modules.organizations.schema import MemberInvite, MemberRoleUpdate, OrganizationCreate, OrganizationUpdate


class OrganizationService:
    def __init__(self, org_repo: OrganizationRepository, membership_repo: MembershipRepository, user_repo: UserRepository):
        self.org_repo = org_repo
        self.membership_repo = membership_repo
        self.user_repo = user_repo

    async def create(self, data: OrganizationCreate, current_user: User) -> Organization:
        org = Organization(
            name=data.name,
            description=data.description,
            logo_url=data.logo_url,
            billing_plan=data.billing_plan.value,
            created_by=current_user.id,
        )
        await self.org_repo.create(org)
        membership = OrganizationMembership(
            organization_id=org.id,
            user_id=current_user.id,
            role_in_org=OrganizationRole.ADMIN.value,
            created_by=current_user.id,
        )
        await self.membership_repo.create(membership)
        return org

    async def get_current_organization(self, current_user: User) -> Organization:
        membership = await self.membership_repo.get_by_user(current_user.id)
        if not membership:
            raise MembershipNotFoundException()
        org = await self.org_repo.get_by_id(membership.organization_id)
        if not org:
            raise OrganizationNotFoundException()
        return org

    async def update_current_organization(self, data: OrganizationUpdate, current_user: User) -> Organization:
        org = await self.get_current_organization(current_user)
        for field, value in data.model_dump(exclude_unset=True).items():
            setattr(org, field, value.value if hasattr(value, "value") else value)
        org.updated_by = current_user.id
        return await self.org_repo.update(org)

    async def list_members(self, current_user: User) -> list[OrganizationMembership]:
        org = await self.get_current_organization(current_user)
        return await self.membership_repo.list_members(org.id)

    async def invite_member(self, data: MemberInvite, current_user: User) -> OrganizationMembership:
        org = await self.get_current_organization(current_user)
        user = await self.user_repo.get_by_email(data.email)
        if not user:
            role = await self.user_repo.get_role_by_name(RoleEnum.INSPECTOR.value)
            if not role:
                role = Role(name=RoleEnum.INSPECTOR.value, description="Infrastructure inspection operator")
                self.user_repo.session.add(role)
                await self.user_repo.session.flush()
            user = User(
                role_id=role.id,
                email=data.email,
                full_name=data.full_name,
                hashed_password=hash_password(uuid.uuid4().hex),
                is_active=True,
                is_verified=False,
                created_by=current_user.id,
            )
            await self.user_repo.create(user)
        existing = await self.membership_repo.get_member(org.id, user.id)
        if existing:
            existing.role_in_org = data.role_in_org.value
            existing.updated_by = current_user.id
            return await self.membership_repo.update(existing)
        membership = OrganizationMembership(
            organization_id=org.id,
            user_id=user.id,
            role_in_org=data.role_in_org.value,
            created_by=current_user.id,
        )
        return await self.membership_repo.create(membership)

    async def update_member_role(self, user_id: uuid.UUID, data: MemberRoleUpdate, current_user: User) -> OrganizationMembership:
        org = await self.get_current_organization(current_user)
        membership = await self.membership_repo.get_member(org.id, user_id)
        if not membership:
            raise MembershipNotFoundException()
        membership.role_in_org = data.role_in_org.value
        membership.updated_by = current_user.id
        return await self.membership_repo.update(membership)

    async def remove_member(self, user_id: uuid.UUID, current_user: User) -> None:
        org = await self.get_current_organization(current_user)
        membership = await self.membership_repo.get_member(org.id, user_id)
        if not membership:
            raise MembershipNotFoundException()
        await self.membership_repo.soft_delete(membership.id, deleted_by=current_user.id)
