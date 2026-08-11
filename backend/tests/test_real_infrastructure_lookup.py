import pytest
import logging
from app.modules.infrastructure_identity.schema import CoordinateLookupRequest
from app.modules.infrastructure_identity.service import identity_service
from app.modules.infrastructure_identity.constants import VerificationStatus

logger = logging.getLogger(__name__)


@pytest.mark.asyncio
async def test_real_end_to_end_infrastructure_lookup():
    """
    Step 46 Real Integration Test:
    Executes live coordinate lookup against real OpenStreetMap / Nominatim & Government Discovery Pipeline.
    Coordinates: 12.9716, 77.5946 (MG Road / NH Corridor, Bengaluru, Karnataka, India)
    """
    req = CoordinateLookupRequest(
        latitude=12.9716,
        longitude=77.5946,
        accuracy_m=6.5,
        type_hint="ROAD",
        sync_government_search=True,
    )

    response = await identity_service.lookup_identity(req)

    print("\n" + "=" * 80)
    print("      CIVICLENS REAL INFRASTRUCTURE IDENTITY DISCOVERY REPORT")
    print("=" * 80)
    print(f"Lookup ID          : {response.lookup_id}")
    print(f"Coordinates        : {response.location.latitude}, {response.location.longitude} (Accuracy: {response.location.accuracy_m}m)")
    print(f"Address            : {response.location.address}")
    print(f"City / District    : {response.location.city} / {response.location.district}")
    print(f"State / Country    : {response.location.state}, {response.location.country}")
    print(f"Verification Status: {response.verification_status.value}")
    print(f"Confidence Score   : {response.confidence_score * 100:.1f}%")
    print("-" * 80)

    if response.infrastructure:
        print("INFRASTRUCTURE MATCH:")
        print(f"  Name           : {response.infrastructure.name}")
        print(f"  Type           : {response.infrastructure.type}")
        print(f"  Road Reference : {response.infrastructure.road_reference or 'N/A'}")
        print(f"  Source         : {response.infrastructure.source} (Record ID: {response.infrastructure.source_record_id})")
        print(f"  Match Score    : {response.infrastructure.match_score * 100:.1f}%")
        print(f"  Raw Distance   : {response.infrastructure.distance_m}m (Effective: {response.infrastructure.effective_distance_m}m)")

    if response.government_identity:
        print("-" * 80)
        print("GOVERNMENT AUTHORITY & PROJECT IDENTIFICATION:")
        print(f"  Authority      : {response.government_identity.authority}")
        print(f"  Project ID     : {response.government_identity.project_id or 'Pending Registration'}")
        print(f"  Project Name   : {response.government_identity.project_name or 'N/A'}")

    if response.organizations:
        print("-" * 80)
        print(f"ORGANIZATIONS & CONTRACTORS ({len(response.organizations)} DISCOVERED):")
        for idx, org in enumerate(response.organizations, 1):
            print(f"  [{idx}] {org.name}")
            print(f"      Normalized : {org.normalized_name}")
            print(f"      Role       : {org.role.value}")
            print(f"      Status     : {org.status.value} (Confidence: {org.confidence * 100:.1f}%)")
            print(f"      Source     : {org.source} (CIN/GSTIN: {org.cin_gstin or 'Unchecked'})")
            print(f"      Validity   : {org.valid_from} to {org.valid_to or 'Present'}")

    print("-" * 80)
    print("PROVENANCE & DATA SOURCES:")
    for src in response.sources:
        print(f"  - [{src.provider_type.value}] {src.provider} | Status: {src.verification_status.value} | URL: {src.url or 'N/A'}")
    print("=" * 80 + "\n")

    # Assertions
    assert response.lookup_id is not None
    assert response.location.latitude == 12.9716
    assert response.location.longitude == 77.5946
    assert response.verification_status in [
        VerificationStatus.VERIFIED,
        VerificationStatus.PROBABLE,
        VerificationStatus.UNVERIFIED,
    ]
    assert len(response.sources) >= 1
