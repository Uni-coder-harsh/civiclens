import datetime
import hashlib
import random
import uuid
import jwt
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.core.exceptions import UnauthorizedException
from app.core.logging import logger
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.modules.auth.constants import RoleEnum
from app.modules.auth.exceptions import (
    EmailAlreadyExistsException,
    InvalidCredentialsException,
    InvalidOTPException,
    OTPExpiredException,
    SessionExpiredException,
)
from app.modules.auth.model import LoginHistory, OTPVerification, Role, User, UserSession
from app.modules.auth.repository import OTPRepository, SessionRepository, UserRepository
from app.modules.auth.schema import OTPRequest, OTPVerify, PasswordReset, UserLogin, UserRegister
from app.modules.organizations.constants import BillingPlan, OrganizationRole
from app.modules.organizations.model import Organization, OrganizationMembership


class AuthService:
    """Orchestrates authentication, session rotations, and verification workflows."""

    def __init__(self, db_session: AsyncSession):
        self.session = db_session
        self.user_repo = UserRepository(db_session)
        self.session_repo = SessionRepository(db_session)
        self.otp_repo = OTPRepository(db_session)

    async def register_admin_user(self, reg_data: UserRegister) -> User:
        existing = await self.user_repo.get_by_email(reg_data.email)
        if existing:
            raise EmailAlreadyExistsException()

        role = await self.user_repo.get_role_by_name(RoleEnum.ORG_ADMIN.value)
        if not role:
            role = Role(
                name=RoleEnum.ORG_ADMIN.value,
                description="Administrator of an organization asset registry",
            )
            self.session.add(role)
            await self.session.flush()

        new_user = User(
            role_id=role.id,
            email=reg_data.email,
            hashed_password=hash_password(reg_data.password),
            full_name=reg_data.full_name,
            phone_number=reg_data.phone_number,
            is_active=True,
            is_verified=True,
        )
        await self.user_repo.create(new_user)

        organization = Organization(
            name=reg_data.organization_name,
            description=f"Organization registry for {reg_data.organization_name}",
            billing_plan=BillingPlan.FREE.value,
            created_by=new_user.id,
        )
        self.session.add(organization)
        await self.session.flush()

        membership = OrganizationMembership(
            organization_id=organization.id,
            user_id=new_user.id,
            role_in_org=OrganizationRole.ADMIN.value,
            created_by=new_user.id,
        )
        self.session.add(membership)

        logger.info(f"Registered user {reg_data.email} and created organization {reg_data.organization_name}")
        return new_user

    async def login_user(self, login_data: UserLogin, ip: str, ua: str, device_id: str | None) -> dict:
        user = await self.user_repo.get_by_email(login_data.email)

        if not user or not verify_password(user.hashed_password, login_data.password):
            self.session.add(
                LoginHistory(
                    user_id=user.id if user else None,
                    ip_address=ip,
                    user_agent=ua,
                    status="FAILED",
                    failure_reason="Invalid credentials",
                )
            )
            raise InvalidCredentialsException()

        if not user.is_active:
            raise InvalidCredentialsException(message="This account is deactivated.")

        org_id = await self._get_user_org_id(user.id)
        access_token, refresh_token = self._issue_tokens(user, org_id)

        # Enforce maximum 3 active sessions per user; prune oldest sessions automatically
        await self.session_repo.enforce_max_sessions(user.id, max_allowed=3)

        expiry = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
        await self.session_repo.create(
            UserSession(
                user_id=user.id,
                refresh_token=refresh_token,
                ip_address=ip,
                user_agent=ua,
                device_id=device_id,
                expires_at=expiry,
            )
        )
        self.session.add(LoginHistory(user_id=user.id, ip_address=ip, user_agent=ua, status="SUCCESS"))
        logger.info(f"User {user.email} successfully authenticated from {ip}.")
        return self._token_response(access_token, refresh_token)

    async def rotate_refresh_session(self, old_refresh_token: str, ip: str, ua: str) -> dict:
        try:
            payload = decode_refresh_token(old_refresh_token)
            user_id = uuid.UUID(payload["sub"])
        except Exception:
            raise SessionExpiredException(message="Invalid refresh token signature.")

        session_record = await self.session_repo.get_by_token(old_refresh_token)
        if not session_record:
            logger.warning(f"Potential Refresh Token Reuse Hijack detected for user {user_id}. Purging sessions.")
            await self.session_repo.revoke_all_sessions(user_id)
            raise SessionExpiredException(message="Token reuse detected. All sessions revoked for safety.")

        now = datetime.datetime.now(datetime.timezone.utc)
        if session_record.expires_at.replace(tzinfo=datetime.timezone.utc) < now:
            await self.session_repo.hard_delete(session_record.id)
            raise SessionExpiredException(message="Refresh token session has expired.")

        user = await self.user_repo.get_by_id(user_id)
        if not user or not user.is_active:
            raise SessionExpiredException(message="User is disabled or not found.")

        org_id = await self._get_user_org_id(user.id)
        new_access_token, new_refresh_token = self._issue_tokens(user, org_id)

        await self.session_repo.hard_delete(session_record.id)
        await self.session_repo.create(
            UserSession(
                user_id=user.id,
                refresh_token=new_refresh_token,
                ip_address=ip,
                user_agent=ua,
                device_id=session_record.device_id,
                expires_at=now + datetime.timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
            )
        )
        return self._token_response(new_access_token, new_refresh_token)

    async def logout_session(self, refresh_token: str) -> None:
        session_record = await self.session_repo.get_by_token(refresh_token)
        if session_record:
            await self.session_repo.hard_delete(session_record.id)

    async def send_otp_token(self, otp_req: OTPRequest) -> None:
        user = await self.user_repo.get_by_email(otp_req.email)
        if not user:
            logger.warning(f"OTP requested for non-existent email: {otp_req.email}")
            return

        await self.otp_repo.invalidate_otps(user.id, otp_req.purpose.value)
        otp_code = f"{random.randint(100000, 999999)}"
        otp_record = OTPVerification(
            user_id=user.id,
            otp_code_hash=hashlib.sha256(otp_code.encode()).hexdigest(),
            purpose=otp_req.purpose.value,
            expires_at=datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(minutes=5),
            is_used=False,
        )
        await self.otp_repo.create(otp_record)
        
        # Send dynamic OTP email using Resend
        if settings.RESEND_API_KEY:
            import httpx
            try:
                headers = {
                    "Authorization": f"Bearer {settings.RESEND_API_KEY}",
                    "Content-Type": "application/json"
                }
                payload = {
                    "from": settings.RESEND_FROM_EMAIL,
                    "to": [user.email],
                    "subject": f"CivicLens Verification Code: {otp_code}",
                    "html": f"""
                    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #ddd; border-radius: 5px;">
                        <h2 style="color: #333;">CivicLens Identity Verification</h2>
                        <p>Hello {user.full_name},</p>
                        <p>We received a request to verify your account identity. Your 6-digit verification code is:</p>
                        <div style="font-size: 24px; font-weight: bold; background-color: #f5f5f5; padding: 15px; border-radius: 4px; text-align: center; letter-spacing: 5px; margin: 20px 0;">
                            {otp_code}
                        </div>
                        <p style="color: #666; font-size: 12px;">This code is valid for 5 minutes. If you did not make this request, you can safely ignore this email.</p>
                        <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
                        <p style="color: #999; font-size: 11px; text-align: center;">CivicLens Intelligence Engine</p>
                    </div>
                    """
                }
                async with httpx.AsyncClient() as client:
                    resp = await client.post("https://api.resend.com/emails", json=payload, headers=headers)
                    if resp.status_code >= 400:
                        logger.error(f"Resend dispatch failed ({resp.status_code}): {resp.text}")
                    else:
                        logger.info(f"OTP successfully dispatched to {user.email} via Resend")
            except Exception as ex:
                logger.error(f"Failed to dispatch OTP email via Resend: {ex}")
        else:
            logger.info(f"Resend not configured. Simulated OTP dispatch to {user.email}: purpose={otp_req.purpose.value}, code={otp_code}")

    async def verify_otp_token(self, verify_data: OTPVerify) -> str:
        user = await self.user_repo.get_by_email(verify_data.email)
        if not user:
            raise InvalidOTPException()

        active_otp = await self.otp_repo.get_active_otp(user.id, verify_data.purpose.value)
        if not active_otp:
            raise InvalidOTPException()

        now = datetime.datetime.now(datetime.timezone.utc)
        if active_otp.expires_at.replace(tzinfo=datetime.timezone.utc) < now:
            raise OTPExpiredException()

        input_hash = hashlib.sha256(verify_data.otp_code.encode()).hexdigest()
        if active_otp.otp_code_hash != input_hash:
            raise InvalidOTPException()

        active_otp.is_used = True
        await self.otp_repo.update(active_otp)

        reset_claims = {
            "sub": str(user.id),
            "purpose": "PASSWORD_RESET",
            "jti": str(uuid.uuid4()),
            "exp": int((now + datetime.timedelta(minutes=10)).timestamp()),
        }
        return jwt.encode(reset_claims, settings.JWT_SECRET_KEY, algorithm="HS256")

    async def reset_password(self, reset_data: PasswordReset) -> None:
        try:
            payload = decode_token(reset_data.reset_token, settings.JWT_SECRET_KEY)
            if payload.get("purpose") != "PASSWORD_RESET":
                raise UnauthorizedException(message="Invalid token purpose.")
            user_uuid = uuid.UUID(payload["sub"])
        except Exception:
            raise UnauthorizedException(message="Reset token expired or invalid.")

        user = await self.user_repo.get_by_id(user_uuid)
        if not user:
            raise UnauthorizedException(message="User not found.")

        user.hashed_password = hash_password(reset_data.new_password)
        await self.user_repo.update(user)
        await self.session_repo.revoke_all_sessions(user.id)

    async def _get_user_org_id(self, user_id: uuid.UUID) -> str | None:
        membership_res = await self.session.execute(
            text("SELECT organization_id FROM organization_memberships WHERE user_id = :u_id AND is_deleted = false LIMIT 1"),
            {"u_id": user_id},
        )
        org_id_val = membership_res.scalar()
        return str(org_id_val) if org_id_val else None

    def _issue_tokens(self, user: User, org_id: str | None) -> tuple[str, str]:
        return (
            create_access_token(subject=str(user.id), org_id=org_id, role=user.role.name, jti=str(uuid.uuid4())),
            create_refresh_token(subject=str(user.id), jti=str(uuid.uuid4())),
        )

    @staticmethod
    def _token_response(access_token: str, refresh_token: str) -> dict:
        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        }
