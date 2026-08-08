from typing import Any, Generic, Sequence, Type, TypeVar
import uuid
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.common.models import Base

ModelType = TypeVar("ModelType", bound=Base)

class BaseRepository(Generic[ModelType]):
    """
    Generic Base Repository providing standardized database CRUD patterns.
    Enforces soft-delete filtering by default for all standard lookups.
    """
    def __init__(self, model: Type[ModelType], db_session: AsyncSession):
        self.model = model
        self.session = db_session

    async def get_by_id(self, record_id: uuid.UUID, include_deleted: bool = False) -> ModelType | None:
        """Retrieves a single record by its UUID identifier."""
        query = select(self.model).where(self.model.id == record_id)
        if not include_deleted:
            query = query.where(self.model.is_deleted == False)
        result = await self.session.execute(query)
        return result.scalar_one_or_none()

    async def list(
        self,
        skip: int = 0,
        limit: int = 100,
        include_deleted: bool = False,
        **filters: Any
    ) -> Sequence[ModelType]:
        """Lists records with pagination and dynamic keyword filters."""
        query = select(self.model)
        if not include_deleted:
            query = query.where(self.model.is_deleted == False)
            
        # Apply exact match filters dynamically
        for key, value in filters.items():
            if hasattr(self.model, key):
                query = query.where(getattr(self.model, key) == value)
                
        query = query.offset(skip).limit(limit)
        result = await self.session.execute(query)
        return result.scalars().all()

    async def create(self, entity: ModelType) -> ModelType:
        """Persists a new entity to the database."""
        self.session.add(entity)
        await self.session.flush() # Flushes to get ID/generated values
        return entity

    async def update(self, entity: ModelType) -> ModelType:
        """Updates an existing entity and increments its version."""
        self.session.add(entity)
        await self.session.flush()
        return entity

    async def soft_delete(self, record_id: uuid.UUID, deleted_by: uuid.UUID | None = None) -> ModelType | None:
        """Performs a logical soft delete by setting is_deleted=True."""
        entity = await self.get_by_id(record_id)
        if entity:
            import datetime
            entity.is_deleted = True
            entity.deleted_at = datetime.datetime.now(datetime.timezone.utc)
            if deleted_by:
                entity.updated_by = deleted_by
            await self.update(entity)
        return entity

    async def hard_delete(self, record_id: uuid.UUID) -> bool:
        """Permanently deletes a record from the database (Physical Delete)."""
        entity = await self.get_by_id(record_id, include_deleted=True)
        if entity:
            await self.session.delete(entity)
            await self.session.flush()
            return True
        return False
