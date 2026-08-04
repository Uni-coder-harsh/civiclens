from typing import Any, Generic, Sequence, TypeVar
import uuid
from app.common.models import Base
from app.common.repositories import BaseRepository
from app.core.exceptions import ResourceNotFoundException

ModelType = TypeVar("ModelType", bound=Base)
RepoType = TypeVar("RepoType", bound=BaseRepository)

class BaseService(Generic[ModelType, RepoType]):
    """
    Generic Base Service layer orchestrating domain logic.
    Exposes default passthroughs to underlying repositories.
    """
    def __init__(self, repository: RepoType):
        self.repository = repository

    async def get_by_id(self, record_id: uuid.UUID) -> ModelType:
        """Retrieves a single record; raises ResourceNotFoundException if missing."""
        entity = await self.repository.get_by_id(record_id)
        if not entity:
            raise ResourceNotFoundException(
                message=f"Record with ID '{record_id}' not found."
            )
        return entity

    async def list(self, skip: int = 0, limit: int = 100, **filters: Any) -> Sequence[ModelType]:
        """Lists records with default pagination filters."""
        return await self.repository.list(skip=skip, limit=limit, **filters)

    async def soft_delete(self, record_id: uuid.UUID, deleted_by: uuid.UUID | None = None) -> None:
        """Logically soft-deletes a record; throws Exception if not found."""
        # Ensure entity exists first
        await self.get_by_id(record_id)
        await self.repository.soft_delete(record_id, deleted_by=deleted_by)
