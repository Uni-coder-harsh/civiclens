import uuid
from decimal import Decimal
from geoalchemy2 import Geometry
from sqlalchemy import ForeignKey, Integer, Numeric
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.common.models import Base


class AnalyticsWeatherCache(Base):
    __tablename__ = "analytics_weather_cache"

    location_geometry: Mapped[object] = mapped_column(Geometry("Point", srid=4326), nullable=False)
    weather_data: Mapped[dict] = mapped_column(JSONB, nullable=False)


class AssetAnalyticsMetric(Base):
    __tablename__ = "asset_analytics_metrics"

    asset_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("infrastructure_assets.id", ondelete="CASCADE"), unique=True, nullable=False)
    total_inspections: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    critical_defects_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    average_health_score: Mapped[Decimal] = mapped_column(Numeric(5, 2), default=Decimal("100.00"), nullable=False)
