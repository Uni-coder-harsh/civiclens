import uuid
from geoalchemy2.elements import WKTElement
from app.modules.auth.model import User
from app.modules.infrastructure.exceptions import AssetNotFoundException
from app.modules.infrastructure.model import InfrastructureAsset
from app.modules.infrastructure.repository import InfrastructureAssetRepository
from app.modules.infrastructure.schema import AssetCreate, AssetUpdate
from app.modules.organizations.repository import MembershipRepository
from app.modules.organizations.exceptions import MembershipNotFoundException


def point_wkt(lat: float, lon: float) -> WKTElement:
    return WKTElement(f"POINT({lon} {lat})", srid=4326)


class InfrastructureService:
    def __init__(self, asset_repo: InfrastructureAssetRepository, membership_repo: MembershipRepository):
        self.asset_repo = asset_repo
        self.membership_repo = membership_repo

    async def current_org_id(self, user: User) -> uuid.UUID:
        membership = await self.membership_repo.get_by_user(user.id)
        if not membership:
            raise MembershipNotFoundException()
        return membership.organization_id

    async def create_asset(self, data: AssetCreate, user: User) -> InfrastructureAsset:
        org_id = await self.current_org_id(user)
        asset = InfrastructureAsset(
            organization_id=org_id,
            name=data.name,
            type=data.type.value,
            geometry=point_wkt(data.location.lat, data.location.lon),
            classification=data.classification,
            construction_year=data.construction_year,
            status=data.status.value,
            address=data.address,
            created_by=user.id,
        )
        return await self.asset_repo.create(asset)

    async def list_assets(
        self,
        user: User,
        skip: int = 0,
        limit: int = 100,
        asset_type: str | None = None,
        status: str | None = None,
    ) -> list[InfrastructureAsset]:
        org_id = await self.current_org_id(user)
        return await self.asset_repo.search(org_id, skip, limit, asset_type, status)

    async def get_asset(self, asset_id: uuid.UUID, user: User) -> InfrastructureAsset:
        org_id = await self.current_org_id(user)
        asset = await self.asset_repo.get_by_id(asset_id)
        if not asset or asset.organization_id != org_id:
            raise AssetNotFoundException()
        return asset

    async def update_asset(self, asset_id: uuid.UUID, data: AssetUpdate, user: User) -> InfrastructureAsset:
        asset = await self.get_asset(asset_id, user)
        values = data.model_dump(exclude_unset=True)
        location = values.pop("location", None)
        if location:
            asset.geometry = point_wkt(location["lat"], location["lon"])
        for field, value in values.items():
            setattr(asset, field, value.value if hasattr(value, "value") else value)
        asset.updated_by = user.id
        return await self.asset_repo.update(asset)

    async def delete_asset(self, asset_id: uuid.UUID, user: User) -> None:
        asset = await self.get_asset(asset_id, user)
        await self.asset_repo.soft_delete(asset.id, deleted_by=user.id)

    async def nearby(self, user: User, lat: float, lon: float, radius: float) -> dict:
        org_id = await self.current_org_id(user)
        assets = await self.asset_repo.nearby(org_id, lat, lon, radius)
        return self.to_feature_collection(assets)

    @staticmethod
    def to_feature_collection(assets: list[InfrastructureAsset]) -> dict:
        features = []
        for asset in assets:
            features.append(
                {
                    "type": "Feature",
                    "geometry": {"type": "Point", "coordinates": []},
                    "properties": {
                        "id": str(asset.id),
                        "name": asset.name,
                        "type": asset.type,
                        "status": asset.status,
                    },
                }
            )
        return {"type": "FeatureCollection", "features": features}
