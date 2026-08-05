from fastapi import APIRouter, Depends
from app.modules.analytics.dependencies import get_analytics_service
from app.modules.analytics.schema import DashboardStats, DegradationTrend
from app.modules.analytics.service import AnalyticsService
from app.modules.auth.dependencies import get_current_user
from app.modules.auth.model import User


router = APIRouter(prefix="/analytics", tags=["Analytics"])


@router.get("/dashboard", response_model=DashboardStats)
async def dashboard(_: User = Depends(get_current_user), service: AnalyticsService = Depends(get_analytics_service)):
    return await service.dashboard()


@router.get("/degradation-trends", response_model=list[DegradationTrend])
async def degradation_trends(_: User = Depends(get_current_user), service: AnalyticsService = Depends(get_analytics_service)):
    return await service.degradation_trends()
