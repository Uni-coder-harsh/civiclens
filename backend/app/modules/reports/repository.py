import uuid
import logging
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.modules.reports.model import CivicReport
from app.modules.reports.schema import ReportCreate

logger = logging.getLogger(__name__)


class ReportsRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create(self, data: ReportCreate, image_url: str | None) -> CivicReport:
        report = CivicReport(
            id=uuid.UUID(data.id) if self._is_uuid(data.id) else uuid.uuid4(),
            client_id=data.id,
            user_id=data.user_id,
            is_guest=data.is_guest,
            category=data.category,
            severity=data.severity,
            description=data.description,
            latitude=data.capture.latitude,
            longitude=data.capture.longitude,
            altitude_m=data.capture.altitude_m,
            accuracy_m=data.capture.accuracy_m,
            bearing_deg=data.capture.bearing_deg,
            speed_mps=data.capture.speed_mps,
            captured_at=data.capture.captured_at,
            image_url=image_url,
            quality_gate=data.quality_gate,
            status="submitted",
            contractor_id=data.contractor_id,
            infrastructure_id=data.infrastructure_id,
            sensor_data=data.parsed_sensor_data(),
            civic_score_delta=10,
        )
        self.db.add(report)
        await self.db.flush()
        logger.info(f"[Reports] Created report id={report.id} category={report.category} severity={report.severity}")
        return report

    async def get_by_client_id(self, client_id: str) -> CivicReport | None:
        result = await self.db.execute(
            select(CivicReport).where(CivicReport.client_id == client_id)
        )
        return result.scalar_one_or_none()

    @staticmethod
    def _is_uuid(val: str) -> bool:
        try:
            uuid.UUID(val)
            return True
        except ValueError:
            return False
