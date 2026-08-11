import uuid
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.common.repositories import BaseRepository
from app.modules.auth.model import OTPVerification, Role, User, UserSession

class UserRepository(BaseRepository[User]):
    """Data repository interface for operations on User records."""
    def __init__(self, db_session: AsyncSession):
        super().__init__(User, db_session)

    async def get_by_email(self, email: str, include_deleted: bool = False) -> User | None:
        """Retrieves a user profile by their email address."""
        query = select(User).where(User.email == email)
        if not include_deleted:
            query = query.where(User.is_deleted == False)
        result = await self.session.execute(query)
        return result.scalar_one_or_none()

    async def get_role_by_name(self, role_name: str) -> Role | None:
        """Retrieves a system security role by its exact name."""
        query = select(Role).where(Role.name == role_name)
        result = await self.session.execute(query)
        return result.scalar_one_or_none()

class SessionRepository(BaseRepository[UserSession]):
    """Data repository interface for managing device login tokens."""
    def __init__(self, db_session: AsyncSession):
        super().__init__(UserSession, db_session)

    async def get_by_token(self, token: str) -> UserSession | None:
        """Retrieves a session record matching a given refresh token."""
        query = select(UserSession).where(UserSession.refresh_token == token)
        result = await self.session.execute(query)
        return result.scalar_one_or_none()

    async def get_active_sessions_by_user(self, user_id: uuid.UUID) -> list[UserSession]:
        """Lists active device sessions registered to a user."""
        query = select(UserSession).where(UserSession.user_id == user_id)
        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def revoke_all_sessions(self, user_id: uuid.UUID) -> None:
        """Revokes all active login sessions associated with a user."""
        query = select(UserSession).where(UserSession.user_id == user_id)
        result = await self.session.execute(query)
        for session in result.scalars().all():
            await self.session.delete(session)

    async def enforce_max_sessions(self, user_id: uuid.UUID, max_allowed: int = 3) -> None:
        """
        Enforces maximum concurrent active sessions per user (default 3).
        If active sessions exceed or equal max_allowed, deletes the oldest sessions so that
        the user never accumulates unbounded login sessions across device reinstalls.
        """
        query = (
            select(UserSession)
            .where(UserSession.user_id == user_id)
            .order_by(UserSession.created_at.asc())
        )
        result = await self.session.execute(query)
        active_sessions = list(result.scalars().all())

        if len(active_sessions) >= max_allowed:
            to_delete_count = len(active_sessions) - max_allowed + 1
            for old_session in active_sessions[:to_delete_count]:
                await self.session.delete(old_session)
            await self.session.flush()

class OTPRepository(BaseRepository[OTPVerification]):
    """Data repository interface managing OTP security tokens."""
    def __init__(self, db_session: AsyncSession):
        super().__init__(OTPVerification, db_session)

    async def get_active_otp(self, user_id: uuid.UUID, purpose: str) -> OTPVerification | None:
        """Retrieves the latest unused, non-expired OTP record for a user."""
        query = (
            select(OTPVerification)
            .where(OTPVerification.user_id == user_id)
            .where(OTPVerification.purpose == purpose)
            .where(OTPVerification.is_used == False)
            .order_by(OTPVerification.created_at.desc())
            .limit(1)
        )
        result = await self.session.execute(query)
        return result.scalar_one_or_none()

    async def invalidate_otps(self, user_id: uuid.UUID, purpose: str) -> None:
        """Invalidates all outstanding OTP tokens for a user by marking them used."""
        import datetime
        now = datetime.datetime.now(datetime.timezone.utc)
        stmt = (
            update(OTPVerification)
            .where(OTPVerification.user_id == user_id)
            .where(OTPVerification.purpose == purpose)
            .where(OTPVerification.is_used == False)
            .values(is_used=True, updated_at=now)
        )
        await self.session.execute(stmt)
