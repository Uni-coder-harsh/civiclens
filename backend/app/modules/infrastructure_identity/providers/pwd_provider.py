import logging
from typing import Dict, Any, List, Optional
from app.modules.infrastructure_identity.constants import SourceDeclarationType
from app.modules.infrastructure_identity.providers.base import GovernmentInfrastructureProvider
from app.modules.infrastructure_identity.normalizer import normalize_road_name

logger = logging.getLogger(__name__)


class StatePWDProvider(GovernmentInfrastructureProvider):
    """
    Adapter for State Public Works Departments (PWD) - e.g. Karnataka PWD, Maharashtra PWD, UP PWD.
    """

    def __init__(self, state_name: str = "Generic State PWD"):
        super().__init__(
            name=f"{state_name} Public Works Department",
            declaration_type=SourceDeclarationType.PUBLIC_PORTAL,
            enabled=True,
            supports_project_search=True,
            supports_tender_search=True,
        )
        self.state_name = state_name

    async def search_projects(
        self, road_reference: Optional[str], district: Optional[str], state: Optional[str]
    ) -> List[Dict[str, Any]]:
        norm_ref = normalize_road_name(road_reference or "")
        active_state = state or self.state_name

        if norm_ref and (norm_ref.startswith("SH-") or norm_ref.startswith("MDR-")):
            return [{
                "project_id": f"PWD-{norm_ref.replace('-', '')}",
                "project_name": f"{norm_ref} State Highway Repair & Widening Project",
                "authority": f"{active_state} Public Works Department (PWD)",
                "location": f"{district or 'Division Circle'}, {active_state}",
                "source": f"{active_state} PWD Project Registry",
                "source_record_id": f"PWD-{active_state[:3].upper()}-{norm_ref}",
                "contractor_name": f"{active_state} Highway Builders & Engineers",
                "contractor_role": "ORIGINAL_BUILDER",
            }]

        return []
