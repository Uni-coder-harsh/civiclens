import uuid
from decimal import Decimal
from app.core.exceptions import ResourceNotFoundException
from app.modules.passport.model import AssetDegradationHistory, InfrastructurePassport
from app.modules.passport.repository import DegradationHistoryRepository, PassportRepository


class PassportService:
    def __init__(self, passport_repo: PassportRepository, history_repo: DegradationHistoryRepository):
        self.passport_repo = passport_repo
        self.history_repo = history_repo

    async def get_or_create_for_asset(self, asset_id: uuid.UUID) -> InfrastructurePassport:
        passport = await self.passport_repo.get_by_asset(asset_id)
        if passport:
            return passport
        passport = InfrastructurePassport(
            asset_id=asset_id,
            passport_number=f"CL-{str(asset_id)[:8].upper()}",
            structural_health_index=Decimal("100.00"),
            degradation_rate=Decimal("0.00"),
        )
        await self.passport_repo.create(passport)
        history = AssetDegradationHistory(
            passport_id=passport.id,
            health_index=passport.structural_health_index,
            change_reason="Passport initialized",
        )
        await self.history_repo.create(history)
        return passport

    async def get_history(self, passport_id: uuid.UUID) -> list[AssetDegradationHistory]:
        passport = await self.passport_repo.get_by_id(passport_id)
        if not passport:
            raise ResourceNotFoundException(message="Passport not found.")
        return await self.history_repo.list_by_passport(passport_id)
