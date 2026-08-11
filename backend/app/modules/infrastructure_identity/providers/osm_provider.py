import os
import logging
from typing import Dict, Any, List, Optional
import httpx
from app.modules.infrastructure_identity.constants import SourceDeclarationType
from app.modules.infrastructure_identity.providers.base import GovernmentInfrastructureProvider
from app.modules.infrastructure_identity.normalizer import normalize_road_name

logger = logging.getLogger(__name__)


class OpenStreetMapProvider(GovernmentInfrastructureProvider):
    """
    OpenStreetMap & Nominatim Provider for reverse geocoding and geospatial feature extraction.
    Uses legitimate public endpoints with proper User-Agent headers.
    """

    def __init__(self):
        super().__init__(
            name="OpenStreetMap",
            declaration_type=SourceDeclarationType.LIVE_API,
            enabled=True,
            supports_reverse_geocode=True,
            supports_infrastructure_search=True,
        )
        self.user_agent = os.getenv("NOMINATIM_USER_AGENT", "CivicLens-InfrastructureIdentity/1.0 (civiclens@app.gov.in)")

    async def reverse_geocode(self, lat: float, lng: float) -> Optional[Dict[str, Any]]:
        url = "https://nominatim.openstreetmap.org/reverse"
        params = {
            "lat": lat,
            "lon": lng,
            "format": "jsonv2",
            "addressdetails": 1,
            "extratags": 1,
            "namedetails": 1,
        }
        headers = {"User-Agent": self.user_agent}

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.get(url, params=params, headers=headers)
                if res.status_code == 200:
                    data = res.json()
                    addr = data.get("address", {})
                    tags = data.get("extratags", {})
                    names = data.get("namedetails", {})

                    road = addr.get("road") or addr.get("highway") or addr.get("pedestrian") or addr.get("bridge") or "Unknown Road"
                    city = addr.get("city") or addr.get("town") or addr.get("village") or addr.get("suburb") or ""
                    district = addr.get("county") or addr.get("state_district") or addr.get("city_district") or city
                    state = addr.get("state", "")
                    postcode = addr.get("postcode", "")

                    road_ref = tags.get("ref") or tags.get("route") or addr.get("ref")
                    if not road_ref:
                        road_ref = normalize_road_name(road)

                    return {
                        "osm_id": str(data.get("osm_id", "")),
                        "osm_type": data.get("osm_type", ""),
                        "display_name": data.get("display_name", ""),
                        "road_name": road,
                        "road_reference": road_ref,
                        "address": data.get("display_name", ""),
                        "city": city,
                        "district": district,
                        "state": state,
                        "country": addr.get("country", "India"),
                        "postcode": postcode,
                        "tags": tags,
                        "names": names,
                    }
        except Exception as e:
            logger.warning(f"[OSMProvider] Nominatim reverse geocode note: {e}")

        return None

    async def search_infrastructure(
        self, lat: float, lng: float, radius_m: float = 100.0, type_hint: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Queries Overpass API for nearby highway and bridge features.
        """
        overpass_url = "https://overpass-api.de/api/interpreter"
        # Overpass QL query around coordinate bounding box
        query = f"""
        [out:json][timeout:10];
        (
          way(around:{int(radius_m)},{lat},{lng})["highway"];
          way(around:{int(radius_m)},{lat},{lng})["bridge"];
          node(around:{int(radius_m)},{lat},{lng})["bridge"];
        );
        out tags center;
        """
        headers = {"User-Agent": self.user_agent}

        results = []
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.post(overpass_url, data={"data": query}, headers=headers)
                if res.status_code == 200:
                    data = res.json()
                    elements = data.get("elements", [])
                    for elem in elements:
                        tags = elem.get("tags", {})
                        center = elem.get("center", {})
                        e_lat = center.get("lat", lat)
                        e_lng = center.get("lon", lng)

                        name = tags.get("name") or tags.get("official_name") or tags.get("alt_name")
                        ref = tags.get("ref") or tags.get("route")
                        is_bridge = tags.get("bridge") in ["yes", "viaduct", "aqueduct"] or type_hint == "BRIDGE"
                        infra_type = "bridge" if is_bridge else "road"
                        infra_name = name or (f"{ref} Bridge" if is_bridge and ref else (ref or f"Unnamed {infra_type.title()}"))

                        results.append({
                            "candidate_id": f"OSM-{elem.get('id')}",
                            "name": infra_name,
                            "type": infra_type,
                            "road_reference": normalize_road_name(ref or infra_name),
                            "highway_classification": tags.get("highway", "unclassified"),
                            "latitude": e_lat,
                            "longitude": e_lng,
                            "source": "OpenStreetMap",
                            "source_record_id": str(elem.get("id")),
                            "authority_hint": tags.get("operator") or tags.get("network"),
                            "tags": tags,
                        })
        except Exception as e:
            logger.warning(f"[OSMProvider] Overpass search note: {e}")

        return results
