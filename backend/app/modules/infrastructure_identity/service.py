import uuid
import logging
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.modules.infrastructure_identity.constants import (
    VerificationStatus,
    OrganizationRole,
    SourceDeclarationType,
)
from app.modules.infrastructure_identity.schema import (
    CoordinateLookupRequest,
    LocationMeta,
    InfrastructureIdentityCandidateSchema,
    GovernmentIdentitySchema,
    OrganizationRelationshipSchema,
    SourceProvenanceSchema,
    InfrastructureIdentityResponse,
)
from app.modules.infrastructure_identity.normalizer import (
    normalize_company_name,
    normalize_road_name,
    normalize_authority_name,
)
from app.modules.infrastructure_identity.matcher import (
    haversine_distance,
    calculate_effective_distance,
    calculate_match_score,
    generate_procurement_query_signals,
)
from app.modules.infrastructure_identity.cache import IdentityCache
from app.modules.infrastructure_identity.providers import registry
from app.modules.infrastructure_identity.model import (
    InfrastructureIdentityRecord,
    InfrastructureOrganizationRecord,
    SourceRecordData,
)

logger = logging.getLogger(__name__)


class InfrastructureIdentityService:
    """
    Core orchestrator for the CivicLens Infrastructure Identity + Contractor Discovery Pipeline.
    """

    def validate_coordinates(self, lat: float, lng: float) -> None:
        if not (-90.0 <= lat <= 90.0):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid latitude {lat}. Must be between -90.0 and 90.0.",
            )
        if not (-180.0 <= lng <= 180.0):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid longitude {lng}. Must be between -180.0 and 180.0.",
            )

    async def lookup_identity(self, req: CoordinateLookupRequest) -> InfrastructureIdentityResponse:
        self.validate_coordinates(req.latitude, req.longitude)
        lookup_uuid = str(uuid.uuid4())

        # ── 0. Check Cache ───────────────────────────────────────────────────
        cache_key = IdentityCache._make_geo_key(req.latitude, req.longitude)
        cached_data = await IdentityCache.get(cache_key)
        if cached_data:
            logger.info(f"[IdentityService] ⚡ Returning cached identity lookup for ({req.latitude}, {req.longitude})")
            return InfrastructureIdentityResponse(**cached_data)

        # ── 1. Reverse Geocoding ──────────────────────────────────────────────
        geo_info = await registry.reverse_geocode(req.latitude, req.longitude)
        location = LocationMeta(
            latitude=req.latitude,
            longitude=req.longitude,
            accuracy_m=req.accuracy_m,
            address=geo_info.get("address") if geo_info else "Coordinates Recorded",
            city=geo_info.get("city") if geo_info else None,
            district=geo_info.get("district") if geo_info else None,
            state=geo_info.get("state") if geo_info else None,
            country=geo_info.get("country", "India") if geo_info else "India",
            postcode=geo_info.get("postcode") if geo_info else None,
        )

        # ── 2. Geospatial Feature Candidate Search (OSM / Overpass) ─────────
        radius_m = 50.0
        if req.accuracy_m and req.accuracy_m > 30.0:
            radius_m = min(250.0, req.accuracy_m * 2.0)

        raw_candidates = await registry.discover_infrastructure_candidates(
            req.latitude, req.longitude, radius_m=radius_m, type_hint=req.type_hint
        )

        scored_candidates: List[InfrastructureIdentityCandidateSchema] = []
        road_name_hint = geo_info.get("road_name") if geo_info else "Unknown Road"
        road_ref_hint = geo_info.get("road_reference") if geo_info else None

        if not raw_candidates:
            # Fallback primary candidate built from reverse geocoding
            c_dist = 5.0
            eff_dist = calculate_effective_distance(c_dist, req.accuracy_m)
            norm_ref = normalize_road_name(road_ref_hint or road_name_hint)
            m_score = calculate_match_score(
                road_ref_match=bool(norm_ref and norm_ref.startswith("NH-")),
                name_similarity=0.7,
                distance_m=c_dist,
                gps_accuracy_m=req.accuracy_m,
                type_hint_match=True,
            )
            scored_candidates.append(
                InfrastructureIdentityCandidateSchema(
                    candidate_id="GEO-REVERSE-01",
                    name=road_name_hint,
                    type=req.type_hint.lower() if req.type_hint else "road",
                    road_reference=norm_ref,
                    highway_classification="highway" if norm_ref and norm_ref.startswith("NH-") else "local_road",
                    latitude=req.latitude,
                    longitude=req.longitude,
                    distance_m=c_dist,
                    effective_distance_m=eff_dist,
                    source="ReverseGeocode",
                    source_record_id=geo_info.get("osm_id") if geo_info else None,
                    match_score=m_score,
                    authority_hint=normalize_authority_name(norm_ref),
                )
            )
        else:
            for c in raw_candidates:
                c_dist = haversine_distance(req.latitude, req.longitude, c["latitude"], c["longitude"])
                eff_dist = calculate_effective_distance(c_dist, req.accuracy_m)
                norm_ref = normalize_road_name(c.get("road_reference") or c.get("name"))

                is_ref_match = bool(norm_ref and road_ref_hint and norm_ref.lower() == road_ref_hint.lower())
                name_sim = 0.9 if c.get("name") and road_name_hint and c["name"].lower() in road_name_hint.lower() else 0.5
                type_match = req.type_hint and c.get("type", "").lower() == req.type_hint.lower()

                m_score = calculate_match_score(
                    road_ref_match=is_ref_match,
                    name_similarity=name_sim,
                    distance_m=c_dist,
                    gps_accuracy_m=req.accuracy_m,
                    authority_match=bool(c.get("authority_hint")),
                    type_hint_match=type_match,
                )

                scored_candidates.append(
                    InfrastructureIdentityCandidateSchema(
                        candidate_id=c["candidate_id"],
                        name=c["name"],
                        type=c["type"],
                        road_reference=norm_ref,
                        highway_classification=c.get("highway_classification"),
                        latitude=c["latitude"],
                        longitude=c["longitude"],
                        distance_m=round(c_dist, 2),
                        effective_distance_m=round(eff_dist, 2),
                        source=c["source"],
                        source_record_id=c.get("source_record_id"),
                        match_score=m_score,
                        authority_hint=normalize_authority_name(c.get("authority_hint") or norm_ref),
                    )
                )

        # Sort candidates descending by match_score
        scored_candidates.sort(key=lambda x: x.match_score, reverse=True)
        top_candidate = scored_candidates[0] if scored_candidates else None

        # ── 3. Government Open Data & Procurement Discovery ─────────────────
        target_road_ref = top_candidate.road_reference if top_candidate else road_ref_hint
        target_road_name = top_candidate.name if top_candidate else road_name_hint

        query_signals = generate_procurement_query_signals(
            road_name=target_road_name,
            road_reference=target_road_ref,
            district=location.district,
            state=location.state,
            type_hint=req.type_hint,
        )

        gov_discoveries = []
        if req.sync_government_search:
            gov_discoveries = await registry.discover_projects_and_tenders(
                road_reference=target_road_ref,
                road_name=target_road_name,
                district=location.district,
                state=location.state,
                type_hint=req.type_hint,
                queries=query_signals,
            )

        # ── 4. Cross Validation, Organization Extraction & Conflict Check ──
        sources: List[SourceProvenanceSchema] = [
            SourceProvenanceSchema(
                provider="OpenStreetMap / Nominatim",
                provider_type=SourceDeclarationType.LIVE_API,
                record_id=top_candidate.source_record_id if top_candidate else None,
                url=f"https://www.openstreetmap.org/{top_candidate.source_record_id}" if top_candidate and top_candidate.source_record_id else None,
                retrieved_at=datetime.now(timezone.utc).isoformat(),
                verification_status=VerificationStatus.VERIFIED if top_candidate and top_candidate.match_score >= 0.8 else VerificationStatus.PROBABLE,
            )
        ]

        organizations: List[OrganizationRelationshipSchema] = []
        contractor_names_found = set()
        conflicting_contractors = False
        conflict_note = None

        gov_identity = GovernmentIdentitySchema(
            authority=normalize_authority_name(top_candidate.road_reference if top_candidate else "State PWD"),
            status=VerificationStatus.PROBABLE,
            confidence=0.75,
        )

        for disc in gov_discoveries:
            p_id = disc.get("project_id") or disc.get("tender_id")
            p_name = disc.get("project_name") or disc.get("tender_title")
            p_auth = disc.get("authority") or disc.get("department")

            if p_auth:
                gov_identity.authority = normalize_authority_name(p_auth)
            if p_id:
                gov_identity.project_id = p_id
            if p_name:
                gov_identity.project_name = p_name
            gov_identity.status = VerificationStatus.VERIFIED
            gov_identity.confidence = 0.92

            # Track Source Provenance
            sources.append(
                SourceProvenanceSchema(
                    provider=disc.get("source", "Government eProcurement"),
                    provider_type=SourceDeclarationType.PUBLIC_PORTAL,
                    record_id=str(p_id),
                    url=disc.get("source_url"),
                    retrieved_at=datetime.now(timezone.utc).isoformat(),
                    verification_status=VerificationStatus.VERIFIED,
                )
            )

            c_name = disc.get("contractor_name")
            if c_name:
                norm_c = normalize_company_name(c_name)
                contractor_names_found.add(norm_c)
                role_enum = OrganizationRole(disc.get("contractor_role", "ORIGINAL_BUILDER"))

                organizations.append(
                    OrganizationRelationshipSchema(
                        name=c_name,
                        normalized_name=norm_c,
                        role=role_enum,
                        status=VerificationStatus.VERIFIED if disc.get("cin_gstin") else VerificationStatus.PROBABLE,
                        confidence=0.92 if disc.get("cin_gstin") else 0.78,
                        source=disc.get("source", "eProcurement"),
                        source_url=disc.get("source_url"),
                        source_record_id=str(p_id),
                        cin_gstin=disc.get("cin_gstin"),
                        valid_from=disc.get("valid_from", "2018-01-01"),
                        valid_to=disc.get("valid_to"),
                    )
                )

            m_name = disc.get("maintainer_name")
            if m_name:
                norm_m = normalize_company_name(m_name)
                organizations.append(
                    OrganizationRelationshipSchema(
                        name=m_name,
                        normalized_name=norm_m,
                        role=OrganizationRole.CURRENT_MAINTAINER,
                        status=VerificationStatus.VERIFIED,
                        confidence=0.88,
                        source=disc.get("source", "NHAI PIU Register"),
                        source_url=disc.get("source_url"),
                        source_record_id=str(p_id),
                        valid_from="2023-04-01",
                        valid_to=None,
                    )
                )

        # Conflict Detection: If multiple contradictory contractor names are returned
        if len(contractor_names_found) > 1:
            conflicting_contractors = True
            conflict_note = f"Multiple conflicting contractor records discovered for {target_road_ref or target_road_name}: {', '.join(contractor_names_found)}. Human review recommended."

        # Overall Status Resolution
        if conflicting_contractors:
            overall_status = VerificationStatus.CONFLICTING_DATA
            overall_confidence = 0.50
        elif organizations and any(o.status == VerificationStatus.VERIFIED for o in organizations):
            overall_status = VerificationStatus.VERIFIED
            overall_confidence = 0.92
        elif top_candidate and top_candidate.match_score >= 0.60:
            overall_status = VerificationStatus.PROBABLE
            overall_confidence = top_candidate.match_score
        elif top_candidate:
            overall_status = VerificationStatus.UNVERIFIED
            overall_confidence = top_candidate.match_score
        else:
            overall_status = VerificationStatus.NOT_FOUND
            overall_confidence = 0.0

        response = InfrastructureIdentityResponse(
            lookup_id=lookup_uuid,
            location=location,
            verification_status=overall_status,
            confidence_score=overall_confidence,
            infrastructure=top_candidate,
            government_identity=gov_identity,
            organizations=organizations,
            sources=sources,
            candidates=scored_candidates,
            conflict_note=conflict_note,
        )

        # Cache response
        await IdentityCache.set(cache_key, response.model_dump(), ttl_seconds=86400)
        return response

    async def persist_identity_and_update_passport(
        self,
        db: AsyncSession,
        response: InfrastructureIdentityResponse,
        asset_id_str: Optional[str] = None,
        report_id: Optional[str] = None,
    ) -> None:
        """
        Persists identity, organization relationships, and source records to PostgreSQL/Neon DB
        and updates the corresponding InfrastructurePassport.
        """
        from app.modules.passport.model import InfrastructurePassport, AssetDegradationHistory

        try:
            asset_uuid = uuid.UUID(asset_id_str) if asset_id_str else None
        except Exception:
            asset_uuid = None

        top_infra = response.infrastructure

        # 1. Create InfrastructureIdentityRecord
        identity_rec = InfrastructureIdentityRecord(
            id=uuid.uuid4(),
            asset_id=asset_uuid,
            report_id=report_id,
            latitude=response.location.latitude,
            longitude=response.location.longitude,
            accuracy_m=response.location.accuracy_m,
            name=top_infra.name if top_infra else response.location.address or "Unknown Asset",
            type=top_infra.type if top_infra else "road",
            road_reference=top_infra.road_reference if top_infra else None,
            authority=response.government_identity.authority if response.government_identity else None,
            verification_status=response.verification_status.value,
            confidence_score=response.confidence_score,
            identity_metadata=response.model_dump(),
        )
        db.add(identity_rec)
        await db.flush()

        # 2. Auto-register Discovered Contractor Organizations in Neon DB organizations table
        from app.modules.organizations.model import Organization
        for org in response.organizations:
            try:
                org_stmt = select(Organization).where(Organization.name == org.name)
                org_res = await db.execute(org_stmt)
                existing_org = org_res.scalar_one_or_none()

                if not existing_org:
                    new_org = Organization(
                        id=uuid.uuid4(),
                        name=org.name,
                        description=f"Discovered Entity ({org.role.value}) via {org.source} for {top_infra.name if top_infra else 'Infrastructure Asset'}",
                        billing_plan="free",
                    )
                    db.add(new_org)
                    await db.flush()
                    logger.info(f"[Identity] 🏢 Auto-registered Contractor Organization '{org.name}' in Neon DB (id={new_org.id})")
            except Exception as org_err:
                logger.warning(f"[Identity] Note when auto-registering Organization '{org.name}': {org_err}")

        # 3. Add Organization Records
        for org in response.organizations:
            org_rec = InfrastructureOrganizationRecord(
                id=uuid.uuid4(),
                identity_id=identity_rec.id,
                asset_id=asset_uuid,
                name=org.name,
                normalized_name=org.normalized_name,
                role=org.role.value,
                verification_status=org.status.value,
                confidence_score=org.confidence,
                source=org.source,
                source_url=org.source_url,
                source_record_id=org.source_record_id,
                cin_gstin=org.cin_gstin,
                valid_from=org.valid_from,
                valid_to=org.valid_to,
            )
            db.add(org_rec)

        # 3. Add Source Records
        now_naive = datetime.now(timezone.utc).replace(tzinfo=None)
        for s in response.sources:
            src_rec = SourceRecordData(
                id=uuid.uuid4(),
                identity_id=identity_rec.id,
                provider_name=s.provider,
                provider_type=s.provider_type.value,
                source_url=s.url,
                record_id=s.record_id,
                retrieved_at=now_naive,
            )
            db.add(src_rec)

        await db.flush()

        # 4. Update InfrastructurePassport in Neon DB
        if asset_uuid:
            stmt = select(InfrastructurePassport).where(InfrastructurePassport.asset_id == asset_uuid)
            res = await db.execute(stmt)
            passport = res.scalar_one_or_none()
            if passport:
                builder_org = next((o for o in response.organizations if o.role == OrganizationRole.ORIGINAL_BUILDER), None)
                reason_text = f"Identity resolved ({response.verification_status.value})"
                if builder_org:
                    reason_text += f" • Contractor: {builder_org.name} ({builder_org.status.value})"

                history_entry = AssetDegradationHistory(
                    id=uuid.uuid4(),
                    passport_id=passport.id,
                    health_index=passport.structural_health_index,
                    change_reason=reason_text,
                )
                db.add(history_entry)
                await db.flush()


identity_service = InfrastructureIdentityService()
