from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field
from app.modules.infrastructure_identity.constants import (
    VerificationStatus,
    OrganizationRole,
    SourceDeclarationType,
    InfrastructureTypeHint,
)


class CoordinateLookupRequest(BaseModel):
    latitude: float = Field(..., description="Latitude in range [-90, 90]")
    longitude: float = Field(..., description="Longitude in range [-180, 180]")
    accuracy_m: Optional[float] = Field(default=None, description="GPS accuracy in meters")
    altitude_m: Optional[float] = Field(default=None, description="Altitude in meters")
    timestamp: Optional[str] = Field(default=None, description="ISO timestamp of capture")
    type_hint: Optional[str] = Field(default="OTHER", description="User infrastructure hint: ROAD, BRIDGE, etc.")
    sync_government_search: bool = Field(default=True, description="Whether to execute staged government search synchronously")


class LocationMeta(BaseModel):
    latitude: float
    longitude: float
    accuracy_m: Optional[float] = None
    address: Optional[str] = None
    city: Optional[str] = None
    district: Optional[str] = None
    state: Optional[str] = None
    country: Optional[str] = "India"
    postcode: Optional[str] = None


class InfrastructureIdentityCandidateSchema(BaseModel):
    candidate_id: str
    name: str
    type: str
    road_reference: Optional[str] = None
    highway_classification: Optional[str] = None
    latitude: float
    longitude: float
    distance_m: float
    effective_distance_m: float
    source: str
    source_record_id: Optional[str] = None
    match_score: float
    authority_hint: Optional[str] = None


class GovernmentIdentitySchema(BaseModel):
    authority: Optional[str] = None
    project_id: Optional[str] = None
    project_name: Optional[str] = None
    sanction_details: Optional[str] = None
    confidence: float = 0.0
    status: VerificationStatus = VerificationStatus.NOT_FOUND


class OrganizationRelationshipSchema(BaseModel):
    name: str
    normalized_name: str
    role: OrganizationRole
    status: VerificationStatus
    confidence: float
    source: str
    source_url: Optional[str] = None
    source_record_id: Optional[str] = None
    cin_gstin: Optional[str] = None
    valid_from: Optional[str] = None
    valid_to: Optional[str] = None


class SourceProvenanceSchema(BaseModel):
    provider: str
    provider_type: SourceDeclarationType
    record_id: Optional[str] = None
    url: Optional[str] = None
    retrieved_at: str
    verification_status: VerificationStatus


class InfrastructureIdentityResponse(BaseModel):
    lookup_id: str
    location: LocationMeta
    verification_status: VerificationStatus
    confidence_score: float
    infrastructure: Optional[InfrastructureIdentityCandidateSchema] = None
    government_identity: Optional[GovernmentIdentitySchema] = None
    organizations: List[OrganizationRelationshipSchema] = Field(default_factory=list)
    sources: List[SourceProvenanceSchema] = Field(default_factory=list)
    candidates: List[InfrastructureIdentityCandidateSchema] = Field(default_factory=list)
    conflict_note: Optional[str] = None
