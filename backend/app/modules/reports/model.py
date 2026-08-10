import uuid
from datetime import datetime
from sqlalchemy import Float, String, Text, Boolean, DateTime
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column
from app.common.models import Base


class CivicReport(Base):
    """
    Stores citizen-submitted infrastructure defect reports received from the Flutter app.
    Each report carries GPS capture metadata, image URL (Supabase S3), severity, and category.
    """
    __tablename__ = "civic_reports"

    # Reporter identity
    client_id: Mapped[str] = mapped_column(String(255), nullable=False, index=True, comment="UUID from the Flutter app")
    user_id: Mapped[str] = mapped_column(String(255), nullable=False, index=True, comment="User ID from auth session")
    is_guest: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # Defect classification
    category: Mapped[str] = mapped_column(String(100), nullable=False, comment="e.g. pothole, roadCrack")
    severity: Mapped[str] = mapped_column(String(50), nullable=False, comment="low, medium, high, critical")
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    # GPS capture
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    altitude_m: Mapped[float] = mapped_column(Float, nullable=True)
    accuracy_m: Mapped[float] = mapped_column(Float, nullable=True)
    bearing_deg: Mapped[float] = mapped_column(Float, nullable=True)
    speed_mps: Mapped[float] = mapped_column(Float, nullable=True)
    captured_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Media
    image_url: Mapped[str | None] = mapped_column(String(2048), nullable=True, comment="Supabase S3 public URL")
    thumbnail_url: Mapped[str | None] = mapped_column(String(2048), nullable=True)
    quality_gate: Mapped[str] = mapped_column(String(50), nullable=False, default="ok")

    # Status lifecycle
    status: Mapped[str] = mapped_column(String(50), nullable=False, default="submitted")

    # Optional associations
    contractor_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    infrastructure_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Sensor telemetry (JSON blob from sweep mode)
    sensor_data: Mapped[dict | None] = mapped_column(JSONB, nullable=True)

    # AI scoring (filled in async after submission)
    ai_confidence: Mapped[float | None] = mapped_column(Float, nullable=True)
    ai_label: Mapped[str | None] = mapped_column(String(255), nullable=True)
    civic_score_delta: Mapped[int] = mapped_column(nullable=False, default=10)
