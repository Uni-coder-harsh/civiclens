import uuid
import logging
from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.modules.reports.model import CivicReport
from app.modules.reports.schema import ReportCreate

logger = logging.getLogger(__name__)


class ReportsRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create(
        self,
        data: ReportCreate,
        image_url: str | None,
        ai_result: dict | None = None,
    ) -> CivicReport:
        # ── Infrastructure Asset Proximity Linking & Deduplication ──────────
        infra_id = data.infrastructure_id
        if not infra_id:
            infra_id = await self._get_or_create_infrastructure_asset(
                data.category,
                data.capture.latitude,
                data.capture.longitude,
            )

        # ── Infrastructure Passport & Identity Discovery Pipeline ──────────
        try:
            await self._update_or_create_infrastructure_passport(infra_id, data.category, data.severity)

            from app.modules.infrastructure_identity.service import identity_service
            from app.modules.infrastructure_identity.schema import CoordinateLookupRequest

            lookup_req = CoordinateLookupRequest(
                latitude=data.capture.latitude,
                longitude=data.capture.longitude,
                accuracy_m=data.capture.accuracy_m,
                altitude_m=data.capture.altitude_m,
                type_hint=data.category.upper(),
                sync_government_search=True,
            )
            id_response = await identity_service.lookup_identity(lookup_req)
            await identity_service.persist_identity_and_update_passport(
                self.db, id_response, asset_id_str=infra_id, report_id=str(data.id)
            )
        except Exception as p_err:
            logger.warning(f"[Reports] Passport and identity update note: {p_err}")

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
            ai_confidence=(ai_result or {}).get("ai_confidence"),
            ai_label=(ai_result or {}).get("ai_label"),
            ai_severity=(ai_result or {}).get("ai_severity"),
            ai_detections=(ai_result or {}).get("ai_detections"),
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

    async def _update_or_create_infrastructure_passport(
        self, infra_id_str: str, category: str, severity: str
    ) -> None:
        """
        Retrieves or creates the InfrastructurePassport for infra_id_str in Neon DB.
        Deducts health points according to defect severity and appends an AssetDegradationHistory entry.
        """
        from app.modules.passport.model import InfrastructurePassport, AssetDegradationHistory
        try:
            infra_uuid = uuid.UUID(infra_id_str)
        except Exception:
            return

        now_naive = datetime.now(timezone.utc).replace(tzinfo=None)

        try:
            stmt = select(InfrastructurePassport).where(InfrastructurePassport.asset_id == infra_uuid)
            res = await self.db.execute(stmt)
            passport = res.scalar_one_or_none()

            # Severity penalties
            penalties = {"critical": 15.0, "high": 10.0, "medium": 5.0, "low": 2.0}
            penalty = Decimal(str(penalties.get(severity.lower(), 5.0)))

            if not passport:
                new_health = Decimal("100.00") - penalty
                passport = InfrastructurePassport(
                    id=uuid.uuid4(),
                    asset_id=infra_uuid,
                    passport_number=f"CL-{str(infra_uuid)[:8].upper()}",
                    structural_health_index=max(Decimal("0.00"), new_health),
                    degradation_rate=Decimal("2.50"),
                    last_inspected_at=now_naive,
                )
                self.db.add(passport)
                await self.db.flush()
                logger.info(f"[Passport] 📜 Initialized new Infrastructure Passport id={passport.id} num={passport.passport_number}")
            else:
                passport.structural_health_index = max(Decimal("0.00"), passport.structural_health_index - penalty)
                passport.last_inspected_at = now_naive
                passport.degradation_rate += Decimal("0.50")
                logger.info(f"[Passport] 📜 Updated Passport id={passport.id} health={passport.structural_health_index}")

            history_entry = AssetDegradationHistory(
                id=uuid.uuid4(),
                passport_id=passport.id,
                health_index=passport.structural_health_index,
                change_reason=f"Reported defect: {category} ({severity} severity)",
            )
            self.db.add(history_entry)
            await self.db.flush()
        except Exception as e:
            logger.warning(f"[Passport] Failed to sync infrastructure passport: {e}")

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
