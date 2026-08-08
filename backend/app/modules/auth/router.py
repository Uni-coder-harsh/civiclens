from typing import Annotated
from fastapi import APIRouter, Cookie, Depends, Header, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.infrastructure.database import get_db_session
from app.modules.auth.dependencies import get_current_user
from app.modules.auth.model import User
from app.modules.auth.schema import (
    OTPRequest,
    OTPVerify,
    PasswordReset,
    TokenResponse,
    UserLogin,
    UserRegister,
    UserResponse,
)
from app.modules.auth.service import AuthService

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post(
    "/register",
    status_code=status.HTTP_201_CREATED,
    response_model=UserResponse,
    summary="Register a new administrator and organization"
)
async def register_admin(
    reg_data: UserRegister,
    db: AsyncSession = Depends(get_db_session)
):
    """
    Registers a new user with ORG_ADMIN role, creates a new organization,
    and sets up the administration membership links.
    """
    auth_service = AuthService(db)
    user = await auth_service.register_admin_user(reg_data)
    return user

@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Login with password credentials"
)
async def login(
    login_data: UserLogin,
    request: Request,
    response: Response,
    x_device_id: Annotated[str | None, Header(alias="X-Device-ID")] = None,
    db: AsyncSession = Depends(get_db_session)
):
    """
    Validates user credentials and initiates an active session.
    Automatically places the rotated refresh token inside an HTTPOnly secure cookie.
    """
    # Extract client metadata for auditing and session tracking
    client_ip = request.client.host if request.client else "unknown"
    user_agent = request.headers.get("User-Agent", "unknown")

    auth_service = AuthService(db)
    tokens = await auth_service.login_user(
        login_data=login_data,
        ip=client_ip,
        ua=user_agent,
        device_id=x_device_id
    )

    # Set refresh token as secure cookie
    # __Host- prefix requires HTTPS and path=/; using standard secure cookies for local development flexibility
    response.set_cookie(
        key="refresh_token",
        value=tokens["refresh_token"],
        httponly=True,
        secure=not settings.DEBUG,  # True in prod, False in local dev
        samesite="lax",
        max_age=settings.REFRESH_TOKEN_EXPIRE_DAYS * 24 * 3600
    )

    return tokens

@router.post(
    "/refresh",
    response_model=TokenResponse,
    summary="Rotate active refresh token session"
)
async def refresh_session(
    request: Request,
    response: Response,
    refresh_token: Annotated[str | None, Cookie()] = None,
    x_refresh_token: Annotated[str | None, Header(alias="X-Refresh-Token")] = None,
    db: AsyncSession = Depends(get_db_session)
):
    """
    Rotates the active session refresh token (RTR).
    Accepts token via cookie or fallback header. Returns updated credentials.
    """
    token_to_verify = refresh_token or x_refresh_token
    if not token_to_verify:
        from app.core.exceptions import UnauthorizedException
        raise UnauthorizedException(message="Refresh token missing from request.")

    client_ip = request.client.host if request.client else "unknown"
    user_agent = request.headers.get("User-Agent", "unknown")

    auth_service = AuthService(db)
    tokens = await auth_service.rotate_refresh_session(
        old_refresh_token=token_to_verify,
        ip=client_ip,
        ua=user_agent
    )

    # Update secure cookie
    response.set_cookie(
        key="refresh_token",
        value=tokens["refresh_token"],
        httponly=True,
        secure=not settings.DEBUG,
        samesite="lax",
        max_age=settings.REFRESH_TOKEN_EXPIRE_DAYS * 24 * 3600
    )

    return tokens

@router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Terminate active login session"
)
async def logout(
    response: Response,
    refresh_token: Annotated[str | None, Cookie()] = None,
    x_refresh_token: Annotated[str | None, Header(alias="X-Refresh-Token")] = None,
    db: AsyncSession = Depends(get_db_session)
):
    """
    Revokes the provided refresh token session and clears the client cookies.
    """
    token_to_revoke = refresh_token or x_refresh_token
    if token_to_revoke:
        auth_service = AuthService(db)
        await auth_service.logout_session(token_to_revoke)

    response.delete_cookie("refresh_token")
    return Response(status_code=status.HTTP_204_NO_CONTENT)

@router.post(
    "/otp/send",
    status_code=status.HTTP_200_OK,
    summary="Send a verification OTP code"
)
async def send_otp(
    otp_req: OTPRequest,
    db: AsyncSession = Depends(get_db_session)
):
    """
    Generates a secure verification code (OTP) and sends it to the user.
    Protects against email enumeration by returning a generic success status.
    """
    auth_service = AuthService(db)
    await auth_service.send_otp_token(otp_req)
    return {"message": "Verification code dispatched if account exists."}

@router.post(
    "/otp/verify",
    summary="Verify OTP code and return reset token"
)
async def verify_otp(
    verify_data: OTPVerify,
    db: AsyncSession = Depends(get_db_session)
):
    """
    Validates the provided OTP. If valid, returns a single-use Password Reset token.
    """
    auth_service = AuthService(db)
    reset_token = await auth_service.verify_otp_token(verify_data)
    return {"reset_token": reset_token}

@router.post(
    "/password/reset",
    status_code=status.HTTP_200_OK,
    summary="Reset password using verification token"
)
async def reset_password(
    reset_data: PasswordReset,
    db: AsyncSession = Depends(get_db_session)
):
    """
    Resets the user's password using the single-use reset token.
    """
    auth_service = AuthService(db)
    await auth_service.reset_password(reset_data)
    return {"message": "Password reset successfully."}
