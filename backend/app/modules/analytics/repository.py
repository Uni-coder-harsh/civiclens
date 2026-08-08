from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.modules.analytics.model import AssetAnalyticsMetric
from app.modules.infrastructure.model import InfrastructureAsset
from app.modules.inspections.model import Inspection, InspectionItem


class AnalyticsRepository:
    def __init__(self, db_session: AsyncSession):
        self.session = db_session

    async def dashboard(self) -> dict:
        total_assets = (await self.session.execute(select(func.count(InfrastructureAsset.id)).where(InfrastructureAsset.is_deleted == False))).scalar_one()
        active_inspections = (
            await self.session.execute(
                select(func.count(Inspection.id))
                .where(Inspection.is_deleted == False)
                .where(Inspection.status.in_(["SCHEDULED", "IN_PROGRESS"]))
            )
        ).scalar_one()
        severity_rows = (
            await self.session.execute(
                select(InspectionItem.detected_severity, func.count(InspectionItem.id))
                .where(InspectionItem.is_deleted == False)
                .group_by(InspectionItem.detected_severity)
            )
        ).all()
        severity_breakdown = {row[0]: row[1] for row in severity_rows}
        return {
            "total_assets": total_assets,
            "active_inspections": active_inspections,
            "defect_distribution": severity_breakdown,
            "severity_breakdown": severity_breakdown,
        }

    async def degradation_trends(self) -> list[dict]:
        rows = (await self.session.execute(select(AssetAnalyticsMetric))).scalars().all()
        return [
            {
                "asset_id": str(row.asset_id),
                "average_health_score": float(row.average_health_score),
                "total_inspections": row.total_inspections,
            }
            for row in rows
        ]
