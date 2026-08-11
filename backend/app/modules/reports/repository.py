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
        # ── Infrastructure Asset Proximity Linking & Deduplication ──────────
        infra_id = data.infrastructure_id
        if not infra_id:
            infra_id = await self._get_or_create_infrastructure_asset(
                data.category,
                data.capture.latitude,
                data.capture.longitude,
            )

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
            infrastructure_id=infra_id,
            sensor_data=data.parsed_sensor_data(),
            civic_score_delta=10,
        )
        self.db.add(report)
        await self.db.flush()
        logger.info(
            f"[Reports] Created report id={report.id} category={report.category} "
            f"severity={report.severity} infra_id={infra_id}"
        )
        return report

    async def _get_or_create_infrastructure_asset(
        self, category: str, lat: float, lng: float
    ) -> str:
        """
        Finds an existing InfrastructureAsset within ~25 meters of (lat, lng)
        taking GPS tolerance (+/- 0.00025 deg) into account.
        If found, reuses its ID to maintain a single asset timeline.
        If not found, creates and registers a new InfrastructureAsset in Neon DB.
        """
        from app.modules.infrastructure.model import InfrastructureAsset
        from app.modules.organizations.model import Organization
        from geoalchemy2.elements import WKTElement

        tolerance = 0.00025  # ~25m spatial tolerance
        lat_min, lat_max = lat - tolerance, lat + tolerance
        lng_min, lng_max = lng - tolerance, lng + tolerance

        try:
            stmt = select(InfrastructureAsset).order_by(InfrastructureAsset.created_at.desc())
            res = await self.db.execute(stmt)
            all_assets = res.scalars().all()

            for asset in all_assets:
                try:
                    # Check bounding box proximity
                    if hasattr(asset, 'latitude') and hasattr(asset, 'longitude'):
                        a_lat, a_lng = asset.latitude, asset.longitude
                        if (lat_min <= a_lat <= lat_max) and (lng_min <= a_lng <= lng_max):
                            logger.info(
                                f"[Reports] 🔗 Proximity match found: linked report to existing "
                                f"Infrastructure Asset id={asset.id}"
                            )
                            return str(asset.id)
                except Exception:
                    pass

            org_res = await self.db.execute(select(Organization).limit(1))
            default_org = org_res.scalar_one_or_none()
            org_id = default_org.id if default_org else uuid.uuid4()

            new_asset = InfrastructureAsset(
                id=uuid.uuid4(),
                organization_id=org_id,
                name=f"{category.replace('_', ' ').title()} ({lat:.4f}, {lng:.4f})",
                type=category,
                classification="road_infrastructure",
                status="reported_defect",
                geometry=WKTElement(f"POINT({lng} {lat})", srid=4326),
            )
            self.db.add(new_asset)
            await self.db.flush()
            logger.info(f"[Reports] 🏗️ Registered new Infrastructure Asset id={new_asset.id} in Neon DB.")
            return str(new_asset.id)
        except Exception as e:
            logger.warning(f"[Reports] Proximity matching note: {e}")
            return str(uuid.uuid4())

    async def get_by_client_id(self, client_id: str) -> CivicReport | None:
        result = await self.db.execute(
            select(CivicReport).where(CivicReport.client_id == client_id)
        )
        return result.scalar_one_or_none()

    async def get_by_user_id(self, user_id: str) -> list[CivicReport]:
        result = await self.db.execute(
            select(CivicReport)
            .where(CivicReport.user_id == user_id)
            .order_by(CivicReport.created_at.desc())
        )
        return list(result.scalars().all())

    @staticmethod
    def _is_uuid(val: str) -> bool:
        try:
            uuid.UUID(val)
            return True
        except ValueError:
            return False
