from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from app.core.config import settings
from app.core.logging import logger

# Initialize async SQLAlchemy engine with connection pool parameters
# pool_pre_ping enables connection health checking on checkout
async_engine = create_async_engine(
    settings.database_url,
    echo=False,  # Set to True for query logs in debugging
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True,
    future=True
)

# Async session factory
async_session_maker = async_sessionmaker(
    bind=async_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False
)

async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    """
    FastAPI Dependency yielding an asynchronous database session.
    Automatically handles session closing, commits, and rollbacks on exception.
    """
    async with async_session_maker() as session:
        try:
            yield session
            await session.commit()
        except Exception as e:
            await session.rollback()
            logger.error(f"Transaction rolled back due to error: {e}")
            raise
        finally:
            await session.close()
