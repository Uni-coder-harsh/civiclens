import asyncio
import uuid
from sqlalchemy import select
from app.infrastructure.database import async_session_maker
from app.core.security import hash_password
from app.modules.auth.model import Role, Permission, User
from app.modules.auth.constants import RoleEnum
from app.modules.organizations.model import Organization, OrganizationMembership
from app.modules.organizations.constants import BillingPlan, OrganizationRole
from app.modules.severity.model import SeverityRule
from app.core.logging import logger

async def seed_database():
    logger.info("Starting database seeding...")
    async with async_session_maker() as session:
        try:
            # 1. Seed Permissions
            logger.info("Seeding permissions...")
            perms_data = [
                ("assets:read", "Read access to infrastructure assets"),
                ("assets:write", "Write access to create/update assets"),
                ("assets:delete", "Delete access to remove assets"),
                ("inspections:read", "Read access to inspections"),
                ("inspections:write", "Write access to schedule/perform inspections"),
                ("ai:inference", "Trigger AI inference on inspection media"),
                ("rules:manage", "Manage automated severity assessment rules"),
                ("system:settings", "Modify global system settings"),
            ]
            
            db_permissions = {}
            for name, desc in perms_data:
                stmt = select(Permission).where(Permission.name == name)
                res = await session.execute(stmt)
                perm = res.scalar_one_or_none()
                if not perm:
                    perm = Permission(name=name, description=desc)
                    session.add(perm)
                    await session.flush()
                db_permissions[name] = perm

            # 2. Seed Roles
            logger.info("Seeding roles...")
            roles_data = [
                (RoleEnum.SUPER_ADMIN.value, "Global platform administrator", list(db_permissions.values())),
                (RoleEnum.ORG_ADMIN.value, "Administrator of an organization registry", [
                    db_permissions["assets:read"], db_permissions["assets:write"], db_permissions["assets:delete"],
                    db_permissions["inspections:read"], db_permissions["inspections:write"],
                    db_permissions["ai:inference"], db_permissions["rules:manage"]
                ]),
                (RoleEnum.INSPECTOR.value, "Field inspection operator", [
                    db_permissions["assets:read"], db_permissions["inspections:read"],
                    db_permissions["inspections:write"], db_permissions["ai:inference"]
                ]),
            ]
            
            db_roles = {}
            for name, desc, perms in roles_data:
                stmt = select(Role).where(Role.name == name)
                res = await session.execute(stmt)
                role = res.scalar_one_or_none()
                if not role:
                    role = Role(name=name, description=desc)
                    session.add(role)
                    await session.flush()
                
                # Assign permissions to role
                role.permissions = perms
                db_roles[name] = role

            # 3. Seed Default Organization
            logger.info("Seeding default organization...")
            stmt = select(Organization).where(Organization.name == "CivicLens Global")
            res = await session.execute(stmt)
            default_org = res.scalar_one_or_none()
            if not default_org:
                default_org = Organization(
                    name="CivicLens Global",
                    description="Default platform administrator organization",
                    billing_plan=BillingPlan.FREE.value,
                )
                session.add(default_org)
                await session.flush()

            # 4. Seed Default Administrator User
            logger.info("Seeding default system administrator...")
            admin_email = "admin@civiclens.com"
            stmt = select(User).where(User.email == admin_email)
            res = await session.execute(stmt)
            admin_user = res.scalar_one_or_none()
            if not admin_user:
                admin_user = User(
                    role_id=db_roles[RoleEnum.SUPER_ADMIN.value].id,
                    email=admin_email,
                    hashed_password=hash_password("AdminSecureP@ss123"),
                    full_name="System Administrator",
                    is_active=True,
                    is_verified=True,
                )
                session.add(admin_user)
                await session.flush()

                # Link Admin to default organization
                membership = OrganizationMembership(
                    organization_id=default_org.id,
                    user_id=admin_user.id,
                    role_in_org=OrganizationRole.ADMIN.value,
                )
                session.add(membership)

            # 5. Seed Severity Rules
            logger.info("Seeding severity rules...")
            rules_data = [
                ("pothole", "confidence", ">=", 0.85, "SEVERE"),
                ("pothole", "confidence", "BETWEEN", 0.50, "MODERATE"), # For between we store boundary in threshold
                ("crack", "confidence", ">=", 0.75, "SEVERE"),
                ("crack", "confidence", "BETWEEN", 0.40, "MODERATE"),
                ("spalling", "confidence", ">=", 0.80, "SEVERE"),
                ("rutting", "confidence", ">=", 0.70, "SEVERE"),
            ]
            
            for class_name, param, op, threshold, severity in rules_data:
                stmt = select(SeverityRule).where(
                    SeverityRule.class_name == class_name,
                    SeverityRule.parameter_name == param,
                    SeverityRule.operator == op,
                    SeverityRule.threshold_value == threshold
                )
                res = await session.execute(stmt)
                rule = res.scalar_one_or_none()
                if not rule:
                    rule = SeverityRule(
                        class_name=class_name,
                        parameter_name=param,
                        operator=op,
                        threshold_value=threshold,
                        assigned_severity=severity,
                    )
                    session.add(rule)

            await session.commit()
            logger.info("Database seeding completed successfully!")
        except Exception as e:
            await session.rollback()
            logger.error(f"Seeding failed: {e}")
            raise

if __name__ == "__main__":
    asyncio.run(seed_database())
