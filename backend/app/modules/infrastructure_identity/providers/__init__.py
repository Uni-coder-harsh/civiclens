import logging
from typing import List, Dict, Any, Optional

from app.modules.infrastructure_identity.providers.base import GovernmentInfrastructureProvider
from app.modules.infrastructure_identity.providers.osm_provider import OpenStreetMapProvider
from app.modules.infrastructure_identity.providers.data_gov_provider import DataGovInProvider
from app.modules.infrastructure_identity.providers.morth_provider import MoRTHProvider
from app.modules.infrastructure_identity.providers.nhai_provider import NHAIProvider
from app.modules.infrastructure_identity.providers.pmgsy_provider import PMGSYProvider
from app.modules.infrastructure_identity.providers.pwd_provider import StatePWDProvider
from app.modules.infrastructure_identity.providers.eproc_provider import EProcurementProvider

logger = logging.getLogger(__name__)


class ProviderRegistry:
    """
    Registry of all verified Government & Geospatial Infrastructure Providers.
    Coordinates authority routing, non-crashing fallback chains, and staged execution.
    """

    def __init__(self):
        self.osm_provider = OpenStreetMapProvider()
        self.data_gov_provider = DataGovInProvider()
        self.morth_provider = MoRTHProvider()
        self.nhai_provider = NHAIProvider()
        self.pmgsy_provider = PMGSYProvider()
        self.pwd_provider = StatePWDProvider()
        self.eproc_provider = EProcurementProvider()

        self.all_providers: List[GovernmentInfrastructureProvider] = [
            self.osm_provider,
            self.data_gov_provider,
            self.morth_provider,
            self.nhai_provider,
            self.pmgsy_provider,
            self.pwd_provider,
            self.eproc_provider,
        ]

    async def reverse_geocode(self, lat: float, lng: float) -> Optional[Dict[str, Any]]:
        """
        Executes reverse geocoding with fallback options.
        """
        if self.osm_provider.enabled:
            geo_res = await self.osm_provider.reverse_geocode(lat, lng)
            if geo_res:
                return geo_res
        return None

    async def discover_infrastructure_candidates(
        self, lat: float, lng: float, radius_m: float = 100.0, type_hint: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Retrieves nearby infrastructure candidates from geospatial sources (OSM, Overpass).
        """
        candidates = []
        try:
            candidates = await self.osm_provider.search_infrastructure(lat, lng, radius_m, type_hint)
        except Exception as e:
            logger.warning(f"[ProviderRegistry] OSM infrastructure search failed gracefully: {e}")

        return candidates

    async def discover_projects_and_tenders(
        self,
        road_reference: Optional[str],
        road_name: Optional[str],
        district: Optional[str],
        state: Optional[str],
        type_hint: Optional[str],
        queries: List[str],
    ) -> List[Dict[str, Any]]:
        """
        Executes targeted authority routing across government providers.
        """
        discovered = []

        # Authority Routing:
        # If National Highway -> Prioritize NHAI & MoRTH
        # If Rural -> Prioritize PMGSY
        # If State Highway -> Prioritize State PWD
        road_ref_upper = (road_reference or "").upper()

        targeted_providers: List[GovernmentInfrastructureProvider] = []
        if road_ref_upper.startswith("NH-"):
            targeted_providers = [self.nhai_provider, self.morth_provider, self.data_gov_provider, self.eproc_provider]
        elif road_ref_upper.startswith("SH-") or road_ref_upper.startswith("MDR-"):
            targeted_providers = [self.pwd_provider, self.data_gov_provider, self.eproc_provider]
        elif type_hint in ["BRIDGE", "FLYOVER"]:
            targeted_providers = [self.nhai_provider, self.pwd_provider, self.eproc_provider, self.data_gov_provider]
        else:
            targeted_providers = [self.data_gov_provider, self.eproc_provider, self.pmgsy_provider, self.pwd_provider]

        # 1. Query Projects
        for provider in targeted_providers:
            try:
                if provider.supports_project_search:
                    projs = await provider.search_projects(road_reference or road_name, district, state)
                    discovered.extend(projs)
            except Exception as e:
                logger.warning(f"[ProviderRegistry] Provider {provider.name} project search note: {e}")

        # 2. Query Tenders / eProcurement
        for query_signal in queries:
            try:
                tenders = await self.eproc_provider.search_tenders(query_signal, district, state)
                discovered.extend(tenders)
            except Exception as e:
                logger.warning(f"[ProviderRegistry] eProcurement tender search note for query '{query_signal}': {e}")

        return discovered


registry = ProviderRegistry()
