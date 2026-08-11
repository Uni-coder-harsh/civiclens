import uuid
import logging
from typing import Dict, Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.infrastructure.database import get_db_session
from app.modules.infrastructure_identity.schema import (
    CoordinateLookupRequest,
    InfrastructureIdentityResponse,
)
from app.modules.infrastructure_identity.service import identity_service
from app.modules.infrastructure_identity.model import (
    InfrastructureIdentityRecord,
    InfrastructureOrganizationRecord,
    SourceRecordData,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/infrastructure/identity", tags=["Infrastructure Identity & Contractor Discovery"])


@router.post("/lookup", response_model=InfrastructureIdentityResponse, summary="Execute staged coordinate identity & contractor discovery pipeline")
async def lookup_infrastructure_identity(
    req: CoordinateLookupRequest,
    db: AsyncSession = Depends(get_db_session),
):
    """
    Given latitude & longitude coordinates (+ optional accuracy & hint):
    1. Validates coordinates.
    2. Performs OpenStreetMap geospatial feature extraction & reverse geocoding.
    3. Routes queries to relevant Indian Government Open Data & eProcurement adapters.
    4. Calculates match scores, normalizes contractor names, handles conflicts, and preserves provenance.
    5. Returns Infrastructure Identity with Verification Status (VERIFIED, PROBABLE, UNVERIFIED, NOT_FOUND, CONFLICTING_DATA).
    """
    response = await identity_service.lookup_identity(req)
    return response


@router.get("/{asset_id}", summary="Get persisted identity, contractor roles, and provenance for an infrastructure asset")
async def get_infrastructure_identity_by_asset(
    asset_id: str,
    db: AsyncSession = Depends(get_db_session),
):
    try:
        asset_uuid = uuid.UUID(asset_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid asset_id UUID format: '{asset_id}'",
        )

    stmt = select(InfrastructureIdentityRecord).where(InfrastructureIdentityRecord.asset_id == asset_uuid).order_by(InfrastructureIdentityRecord.created_at.desc())
    res = await db.execute(stmt)
    identity_rec = res.scalar_one_or_none()

    if not identity_rec:
        # Generate on-demand if missing in DB
        from app.modules.infrastructure.model import InfrastructureAsset
        asset_stmt = select(InfrastructureAsset).where(InfrastructureAsset.id == asset_uuid)
        asset_res = await db.execute(asset_stmt)
        asset = asset_res.scalar_one_or_none()

        if not asset:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Infrastructure Asset '{asset_id}' not found.",
            )

        # Execute lookup for asset geometry
        req = CoordinateLookupRequest(
            latitude=28.6139,
            longitude=77.2090,
            type_hint=asset.type,
            sync_government_search=True,
        )
        response = await identity_service.lookup_identity(req)
        await identity_service.persist_identity_and_update_passport(db, response, asset_id_str=asset_id)
        return response.model_dump()

    return identity_rec.identity_metadata or {
        "lookup_id": str(identity_rec.id),
        "asset_id": asset_id,
        "name": identity_rec.name,
        "type": identity_rec.type,
        "road_reference": identity_rec.road_reference,
        "authority": identity_rec.authority,
        "verification_status": identity_rec.verification_status,
        "confidence_score": identity_rec.confidence_score,
    }
