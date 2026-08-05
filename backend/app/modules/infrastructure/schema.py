import uuid
from pydantic import Field
from app.common.schemas import BaseRequestSchema, BaseResponseSchema
from app.modules.infrastructure.constants import AssetStatus, AssetType


class GeoPoint(BaseRequestSchema):
    lat: float = Field(..., ge=-90, le=90)
    lon: float = Field(..., ge=-180, le=180)


class AssetCreate(BaseRequestSchema):
    name: str = Field(..., min_length=1, max_length=255)
    type: AssetType
    location: GeoPoint
    classification: str = Field(..., min_length=1, max_length=50)
    construction_year: int | None = Field(default=None, gt=1800)
    status: AssetStatus = AssetStatus.GOOD
    address: str | None = Field(default=None, max_length=512)


class AssetUpdate(BaseRequestSchema):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    type: AssetType | None = None
    location: GeoPoint | None = None
    classification: str | None = Field(default=None, min_length=1, max_length=50)
    construction_year: int | None = Field(default=None, gt=1800)
    status: AssetStatus | None = None
    address: str | None = Field(default=None, max_length=512)


class AssetResponse(BaseResponseSchema):
    organization_id: uuid.UUID
    name: str
    type: str
    classification: str
    construction_year: int | None = None
    status: str
    address: str | None = None


class GeoJSONFeature(BaseRequestSchema):
    type: str = "Feature"
    geometry: dict
    properties: dict


class GeoJSONFeatureCollection(BaseRequestSchema):
    type: str = "FeatureCollection"
    features: list[GeoJSONFeature]
