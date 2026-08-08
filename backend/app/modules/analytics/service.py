from app.modules.analytics.repository import AnalyticsRepository


class AnalyticsService:
    def __init__(self, analytics_repo: AnalyticsRepository):
        self.analytics_repo = analytics_repo

    async def dashboard(self) -> dict:
        return await self.analytics_repo.dashboard()

    async def degradation_trends(self) -> list[dict]:
        return await self.analytics_repo.degradation_trends()
