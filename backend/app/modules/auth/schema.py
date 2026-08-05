import uuid
from datetime import datetime
from pydantic import EmailStr, Field
from app.common.schemas import BaseRequestSchema
from app.modules.auth.constants import OTPPurposeEnum, RoleEnum

class UserRegister(BaseRequestSchema):
    email: EmailStr
    password: str = Field(..., min_length=8, description="Strong password, min 8 chars.")
    full_name: str = Field(..., min_length=1, max_length=255)
    phone_number: str | None = Field(default=None, max_length=50)
    organization_name: str = Field(..., min_length=2, max_length=255, description="Initial organization registration.")

class UserLogin(BaseRequestSchema):
    email: EmailStr
    password: str

class TokenResponse(BaseRequestSchema):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int = 3600

class OTPRequest(BaseRequestSchema):
    email: EmailStr
    purpose: OTPPurposeEnum

class OTPVerify(BaseRequestSchema):
    email: EmailStr
    otp_code: str = Field(..., min_length=6, max_length=6)
    purpose: OTPPurposeEnum

class PasswordReset(BaseRequestSchema):
    reset_token: str
    new_password: str = Field(..., min_length=8)

class PermissionResponse(BaseRequestSchema):
    id: uuid.UUID
    name: str
    description: str | None

class RoleResponse(BaseRequestSchema):
    id: uuid.UUID
    name: str
    description: str | None
    permissions: list[PermissionResponse]

class UserResponse(BaseRequestSchema):
    id: uuid.UUID
    email: EmailStr
    full_name: str
    phone_number: str | None = None
    is_active: bool
    is_verified: bool
    avatar_url: str | None = None
    role: RoleResponse
    created_at: datetime
    updated_at: datetime
    version: int
