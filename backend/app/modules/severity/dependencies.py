from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.infrastructure.database import get_db_session
from app.modules.inspections.repository import InspectionItemRepository
from app.modules.severity.repository import AssessmentRepository, SeverityRuleRepository
from app.modules.severity.service import SeverityService


def get_severity_service(db: AsyncSession = Depends(get_db_session)) -> SeverityService:
    return SeverityService(SeverityRuleRepository(db), AssessmentRepository(db), InspectionItemRepository(db))
