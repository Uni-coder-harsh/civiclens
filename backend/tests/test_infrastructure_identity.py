import pytest
from fastapi import HTTPException
from app.modules.infrastructure_identity.constants import (
    VerificationStatus,
    OrganizationRole,
    SourceDeclarationType,
)
from app.modules.infrastructure_identity.schema import CoordinateLookupRequest
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
from app.modules.infrastructure_identity.service import identity_service


def test_coordinate_validation():
    # Valid coordinates
    identity_service.validate_coordinates(28.6139, 77.2090)
    identity_service.validate_coordinates(-90.0, -180.0)
    identity_service.validate_coordinates(90.0, 180.0)

    # Invalid latitude
    with pytest.raises(HTTPException) as exc_lat:
        identity_service.validate_coordinates(95.0, 77.2090)
    assert exc_lat.value.status_code == 400

    # Invalid longitude
    with pytest.raises(HTTPException) as exc_lng:
        identity_service.validate_coordinates(28.6139, -190.0)
    assert exc_lng.value.status_code == 400


def test_name_and_road_normalization():
    # Company names
    assert normalize_company_name("ABC Infrastructure Pvt Ltd") == "ABC INFRASTRUCTURE"
    assert normalize_company_name("ABC Infra Pvt. Ltd.") == "ABC INFRASTRUCTURE"
    assert normalize_company_name("Apex Road Builders Limited") == "APEX ROAD BUILDERS"

    # Road names
    assert normalize_road_name("National Highway 44") == "NH-44"
    assert normalize_road_name("N.H. 44") == "NH-44"
    assert normalize_road_name("State Highway 12") == "SH-12"

    # Authority names
    assert normalize_authority_name("National Highways Authority of India") == "NHAI"
    assert normalize_authority_name("Ministry of Road Transport") == "MoRTH"
    assert normalize_authority_name("Public Works Department") == "State PWD"


def test_distance_and_match_scoring():
    # Haversine distance
    dist = haversine_distance(28.6139, 77.2090, 28.6140, 77.2091)
    assert dist > 0.0 and dist < 50.0

    # Effective distance with GPS uncertainty
    eff = calculate_effective_distance(20.0, gps_accuracy_m=4.0)
    assert eff < 20.0  # High precision GPS reduces effective uncertainty

    eff_poor = calculate_effective_distance(20.0, gps_accuracy_m=100.0)
    assert eff_poor < eff  # Low precision GPS increases effective distance denominator

    # Perfect match score
    score_high = calculate_match_score(
        road_ref_match=True,
        name_similarity=1.0,
        distance_m=10.0,
        gps_accuracy_m=5.0,
        authority_match=True,
        type_hint_match=True,
    )
    assert score_high >= 0.85

    # Weak match score
    score_low = calculate_match_score(
        road_ref_match=False,
        name_similarity=0.2,
        distance_m=200.0,
        gps_accuracy_m=10.0,
    )
    assert score_low < 0.60


def test_procurement_query_signal_generation():
    signals = generate_procurement_query_signals(
        road_name="National Highway 44 Flyover",
        road_reference="NH-44",
        district="Bengaluru Urban",
        state="Karnataka",
        type_hint="BRIDGE",
    )
    assert "NH-44" in signals
    assert "NH-44 Bengaluru Urban" in signals
    assert len(signals) <= 5


@pytest.mark.asyncio
async def test_identity_lookup_nh44_pipeline():
    # Lookup for NH-44 coordinate
    req = CoordinateLookupRequest(
        latitude=28.6139,
        longitude=77.2090,
        accuracy_m=5.0,
        type_hint="BRIDGE",
        sync_government_search=True,
    )

    res = await identity_service.lookup_identity(req)

    assert res.lookup_id is not None
    assert res.location.latitude == 28.6139
    assert res.verification_status in [VerificationStatus.VERIFIED, VerificationStatus.PROBABLE]
    assert res.confidence_score > 0.60
    assert res.infrastructure is not None
    assert len(res.sources) >= 1

    # Verify provenance source details
    osm_source = next((s for s in res.sources if "OpenStreetMap" in s.provider), None)
    assert osm_source is not None
