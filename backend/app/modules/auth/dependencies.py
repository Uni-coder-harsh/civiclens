import uuid
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.core.exceptions import UnauthorizedException
from app.core.logging import logger
from app.core.security import decode_access_token
from app.infrastructure.database import get_db_session
from app.modules.auth.model import User
from app.modules.auth.repository import UserRepository

# HTTPBearer extractor to parse Authorization header
security_bearer = HTTPBearer(auto_error=False)

async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security_bearer),
    db: AsyncSession = Depends(get_db_session)
) -> User:
    """
    FastAPI Dependency to retrieve the currently authenticated user.
    Parses, validates, and decodes the JWT access token.
    """
    if not credentials or credentials.scheme.lower() != "bearer":
        raise UnauthorizedException(message="Authentication credentials missing or invalid.")

    token = credentials.credentials
    payload = decode_access_token(token)

    # Validate claim fields
    user_id_str = payload.get("sub")
    if not user_id_str:
        raise UnauthorizedException(message="Invalid token claims structure.")

    try:
        user_uuid = uuid.UUID(user_id_str)
    except ValueError:
        raise UnauthorizedException(message="Invalid user identifier structure.")

    user_repo = UserRepository(db)
    user = await user_repo.get_by_id(user_uuid)
    
    if not user:
        raise UnauthorizedException(message="User associated with this token not found.")
        
    if not user.is_active:
        raise UnauthorizedException(message="User account has been deactivated.")

    return user

class RoleChecker:
    """Dependency that checks if the authenticated user has one of the allowed roles."""
    def __init__(self, allowed_roles: list[str]):
        self.allowed_roles = allowed_roles

    def __call__(self, current_user: User = Depends(get_current_user)) -> User:
        if current_user.role.name not in self.allowed_roles:
            logger.warning(
                f"Unauthorized access attempt by user {current_user.email} "
                f"with role {current_user.role.name}. Allowed: {self.allowed_roles}"
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to access this resource."
            )
        return current_user
