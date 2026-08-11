import re
import logging
from typing import Dict, Any, List, Optional
from app.modules.infrastructure_identity.constants import SourceDeclarationType, VerificationStatus, OrganizationRole
from app.modules.infrastructure_identity.providers.base import GovernmentInfrastructureProvider

logger = logging.getLogger(__name__)


class CampusInfrastructureProvider(GovernmentInfrastructureProvider):
    """
    Specialized Provider for Educational Institutions, University Campuses, and Private Enclaves.
    When a defect report originates inside a University / College Campus where government municipal tender data
    is unavailable, this provider routes authority, contract, and passport governance directly to the
    Campus Estate & Infrastructure Management Administration.
    """

    def __init__(self):
        super().__init__(
            name="University Campus & Institutional Estate Register",
            declaration_type=SourceDeclarationType.GIS_SERVICE,
            enabled=True,
            supports_infrastructure_search=True,
            supports_project_search=True,
        )

    def is_campus_location(
        self, address: str, display_name: Optional[str] = None, tags: Optional[Dict[str, Any]] = None
    ) -> bool:
        """
        Determines if the report location falls within a University or College Campus footprint.
        """
        combined = f"{address or ''} {display_name or ''}".lower()

        keywords = [
            "university", "college", "campus", "iit ", "nit ", "bits ",
            "institute of technology", "academy", "polytechnic", "school campus"
        ]

        if any(kw in combined for kw in keywords):
            return True

        if tags:
            amenity = str(tags.get("amenity", "")).lower()
            landuse = str(tags.get("landuse", "")).lower()
            building = str(tags.get("building", "")).lower()
            if amenity in ["university", "college", "school"] or landuse == "education" or building == "university":
                return True

        return False

    def extract_campus_name(self, address: str, display_name: Optional[str] = None) -> str:
        text = display_name or address or ""
        parts = [p.strip() for p in text.split(",")]
        for p in parts:
            p_lower = p.lower()
            if any(k in p_lower for k in ["university", "college", "campus", "iit", "nit", "institute"]):
                return p
        return "University Campus"

    async def search_projects(
        self, road_reference: Optional[str], district: Optional[str], state: Optional[str]
    ) -> List[Dict[str, Any]]:
        # Called when campus detection is triggered in ProviderRegistry
        campus_name = road_reference or "University Campus"
        return [{
            "project_id": f"CAMPUS-INFRA-{(campus_name[:6]).upper()}",
            "project_name": f"{campus_name} Internal Roads & Facilities Maintenance Package",
            "authority": f"{campus_name} Administration (Estate & Maintenance Dept)",
            "location": f"{district or 'Campus Grounds'}, {state or 'India'}",
            "source": "University Campus & Institutional Estate Register",
            "source_record_id": f"CAMPUS-ESTATE-{(campus_name[:6]).upper()}",
            "contractor_name": f"{campus_name} Facilities & Capital Works Division",
            "contractor_role": "CURRENT_MAINTAINER",
            "maintainer_name": f"{campus_name} Infrastructure Management Committee",
            "maintainer_role": "OWNER",
        }]
