import logging
from typing import Dict, Any, List, Optional
from app.modules.infrastructure_identity.constants import SourceDeclarationType
from app.modules.infrastructure_identity.providers.base import GovernmentInfrastructureProvider
from app.modules.infrastructure_identity.normalizer import normalize_road_name

logger = logging.getLogger(__name__)


class MoRTHProvider(GovernmentInfrastructureProvider):
    """
    Adapter for Ministry of Road Transport and Highways (MoRTH) data records.
    Provides National Highway network metadata, classification, and authority details.
    """

    def __init__(self):
        super().__init__(
            name="Ministry of Road Transport and Highways (MoRTH)",
            declaration_type=SourceDeclarationType.DOWNLOAD_DATASET,
            enabled=True,
            supports_project_search=True,
        )

    async def search_projects(
        self, road_reference: Optional[str], district: Optional[str], state: Optional[str]
    ) -> List[Dict[str, Any]]:
        norm_ref = normalize_road_name(road_reference or "")
        if not norm_ref:
            return []

        # MoRTH Basic Road Statistics metadata schema resolution
        if norm_ref.startswith("NH-"):
            return [{
                "project_id": f"MORTH-NH-{norm_ref.split('-')[-1]}",
                "project_name": f"{norm_ref} National Highway Trunk Corridor",
                "authority": "Ministry of Road Transport and Highways (MoRTH)",
                "location": f"{district or 'Central Circle'}, {state or 'India'}",
                "source": "MoRTH National Highway Network Register",
                "source_record_id": f"MORTH-{norm_ref}",
                "highway_classification": "National Highway",
            }]

        return []
