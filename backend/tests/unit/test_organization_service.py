import pytest
import uuid
from unittest.mock import AsyncMock, MagicMock
from app.modules.organizations.service import OrganizationService
from app.modules.organizations.schema import OrganizationCreate, BillingPlan, OrganizationRole
from app.modules.auth.model import User, Role
from app.modules.organizations.model import Organization, OrganizationMembership

@pytest.mark.asyncio
async def test_create_organization():
    # Arrange
    org_repo = MagicMock()
    org_repo.create = AsyncMock()
    
    membership_repo = MagicMock()
    membership_repo.create = AsyncMock()
    
    user_repo = MagicMock()
    
    service = OrganizationService(org_repo, membership_repo, user_repo)
    
    current_user = User(
        id=uuid.uuid4(),
        email="admin@example.com",
        full_name="Admin User",
        is_active=True
    )
    
    data = OrganizationCreate(
        name="Test Org",
        description="A test organization",
        logo_url="http://example.com/logo.png",
        billing_plan=BillingPlan.FREE
    )
    
    # Act
    org = await service.create(data, current_user)
    
    # Assert
    assert org.name == "Test Org"
    assert org.description == "A test organization"
    assert org.created_by == current_user.id
    org_repo.create.assert_called_once()
    membership_repo.create.assert_called_once()
