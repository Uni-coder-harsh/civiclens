import pytest
import uuid
import datetime
from unittest.mock import AsyncMock, MagicMock, patch
from app.modules.auth.service import AuthService
from app.modules.auth.schema import UserRegister, UserLogin
from app.modules.auth.model import User, Role, UserSession
from app.modules.auth.constants import RoleEnum
from app.modules.auth.exceptions import EmailAlreadyExistsException, InvalidCredentialsException

@pytest.mark.asyncio
async def test_register_admin_user_success():
    # Arrange
    mock_db = MagicMock()
    mock_db.add = MagicMock()
    mock_db.flush = AsyncMock()
    
    mock_user_repo = MagicMock()
    mock_user_repo.get_by_email = AsyncMock(return_value=None)
    mock_user_repo.get_role_by_name = AsyncMock(return_value=Role(id=uuid.uuid4(), name=RoleEnum.ORG_ADMIN.value))
    mock_user_repo.create = AsyncMock()
    
    service = AuthService(mock_db)
    service.user_repo = mock_user_repo
    
    reg_data = UserRegister(
        email="test@example.com",
        password="securePassword123",
        full_name="John Doe",
        phone_number="+1234567890",
        organization_name="My Company"
    )
    
    # Act
    user = await service.register_admin_user(reg_data)
    
    # Assert
    assert user.email == "test@example.com"
    assert user.full_name == "John Doe"
    mock_user_repo.get_by_email.assert_called_once_with("test@example.com")
    mock_user_repo.get_role_by_name.assert_called_once_with(RoleEnum.ORG_ADMIN.value)
    mock_user_repo.create.assert_called_once()
    assert mock_db.flush.call_count == 1  # only for organization

@pytest.mark.asyncio
async def test_register_admin_user_already_exists():
    # Arrange
    mock_db = MagicMock()
    mock_user_repo = MagicMock()
    mock_user_repo.get_by_email = AsyncMock(return_value=User(id=uuid.uuid4(), email="test@example.com"))
    
    service = AuthService(mock_db)
    service.user_repo = mock_user_repo
    
    reg_data = UserRegister(
        email="test@example.com",
        password="password",
        full_name="John Doe",
        phone_number="+1234567890",
        organization_name="My Company"
    )
    
    # Act & Assert
    with pytest.raises(EmailAlreadyExistsException):
        await service.register_admin_user(reg_data)

@pytest.mark.asyncio
async def test_login_user_success():
    # Arrange
    mock_db = MagicMock()
    mock_db.add = MagicMock()
    
    user_id = uuid.uuid4()
    mock_role = Role(name=RoleEnum.ORG_ADMIN.value)
    
    mock_user = User(
        id=user_id,
        email="test@example.com",
        hashed_password="hashed_pwd",
        is_active=True,
        role=mock_role
    )
    
    mock_user_repo = MagicMock()
    mock_user_repo.get_by_email = AsyncMock(return_value=mock_user)
    
    mock_session_repo = MagicMock()
    mock_session_repo.create = AsyncMock()
    mock_session_repo.enforce_max_sessions = AsyncMock()
    
    service = AuthService(mock_db)
    service.user_repo = mock_user_repo
    service.session_repo = mock_session_repo
    
    # Mocking external helper dependency functions
    with patch("app.modules.auth.service.verify_password", return_value=True), \
         patch("app.modules.auth.service.AuthService._get_user_org_id", new_callable=AsyncMock) as mock_get_org:
        
        mock_get_org.return_value = "some-org-id"
        login_data = UserLogin(email="test@example.com", password="password")
        
        # Act
        tokens = await service.login_user(login_data, ip="127.0.0.1", ua="pytest", device_id="device1")
        
        # Assert
        assert "access_token" in tokens
        assert "refresh_token" in tokens
        mock_session_repo.create.assert_called_once()
        mock_db.add.assert_called_once() # LoginHistory logged
