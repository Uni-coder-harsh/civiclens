from abc import ABC, abstractmethod
from typing import List, Optional, Dict, Any
from app.modules.infrastructure_identity.constants import SourceDeclarationType


class GovernmentInfrastructureProvider(ABC):
    """
    Abstract base concept for all government data providers (NHAI, MoRTH, PMGSY, State PWD, eProcurement, OGD).
    Every provider declares its source type and capabilities explicitly.
    """

    def __init__(
        self,
        name: str,
        declaration_type: SourceDeclarationType,
        enabled: bool = True,
        supports_reverse_geocode: bool = False,
        supports_infrastructure_search: bool = False,
        supports_project_search: bool = False,
        supports_tender_search: bool = False,
        supports_award_search: bool = False,
    ):
        self.name = name
        self.declaration_type = declaration_type
        self.enabled = enabled
        self.supports_reverse_geocode = supports_reverse_geocode
        self.supports_infrastructure_search = supports_infrastructure_search
        self.supports_project_search = supports_project_search
        self.supports_tender_search = supports_tender_search
        self.supports_award_search = supports_award_search

    def get_source_metadata(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "declaration_type": self.declaration_type.value,
            "enabled": self.enabled,
            "supports_reverse_geocode": self.supports_reverse_geocode,
            "supports_infrastructure_search": self.supports_infrastructure_search,
            "supports_project_search": self.supports_project_search,
            "supports_tender_search": self.supports_tender_search,
            "supports_award_search": self.supports_award_search,
        }

    async def reverse_geocode(self, lat: float, lng: float) -> Optional[Dict[str, Any]]:
        return None

    async def search_infrastructure(
        self, lat: float, lng: float, radius_m: float = 100.0, type_hint: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        return []

    async def search_projects(
        self, road_reference: Optional[str], district: Optional[str], state: Optional[str]
    ) -> List[Dict[str, Any]]:
        return []

    async def search_tenders(
        self, query: str, district: Optional[str] = None, state: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        return []

    async def get_awardee(self, tender_or_project_id: str) -> Optional[Dict[str, Any]]:
        return None
