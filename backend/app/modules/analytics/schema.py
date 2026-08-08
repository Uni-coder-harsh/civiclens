from app.common.schemas import BaseRequestSchema


class DashboardStats(BaseRequestSchema):
    total_assets: int
    active_inspections: int
    defect_distribution: dict[str, int]
    severity_breakdown: dict[str, int]


class DegradationTrend(BaseRequestSchema):
    asset_id: str
    average_health_score: float
    total_inspections: int
