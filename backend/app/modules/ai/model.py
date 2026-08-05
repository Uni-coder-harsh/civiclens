import uuid
from decimal import Decimal
from sqlalchemy import Boolean, ForeignKey, Integer, Numeric, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.common.models import Base


class AIModel(Base):
    __tablename__ = "ai_models"

    name: Mapped[str] = mapped_column(String(100), nullable=False)
    version: Mapped[str] = mapped_column(String(50), nullable=False)
    file_path: Mapped[str] = mapped_column(String(1024), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    accuracy_metrics: Mapped[dict | None] = mapped_column(JSONB, nullable=True)


class AIInferenceLog(Base):
    __tablename__ = "ai_inference_logs"

    model_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("ai_models.id", ondelete="CASCADE"), nullable=False)
    media_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("inspection_media.id", ondelete="CASCADE"), nullable=False)
    inference_duration_ms: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)

    predictions: Mapped[list["AIPrediction"]] = relationship("AIPrediction", back_populates="inference_log", cascade="all, delete-orphan")


class AIPrediction(Base):
    __tablename__ = "ai_predictions"

    inference_log_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("ai_inference_logs.id", ondelete="CASCADE"), nullable=False)
    class_name: Mapped[str] = mapped_column(String(100), nullable=False)
    confidence: Mapped[Decimal] = mapped_column(Numeric(4, 3), nullable=False)
    bbox_x_center: Mapped[Decimal] = mapped_column(Numeric(6, 5), nullable=False)
    bbox_y_center: Mapped[Decimal] = mapped_column(Numeric(6, 5), nullable=False)
    bbox_width: Mapped[Decimal] = mapped_column(Numeric(6, 5), nullable=False)
    bbox_height: Mapped[Decimal] = mapped_column(Numeric(6, 5), nullable=False)

    inference_log: Mapped[AIInferenceLog] = relationship("AIInferenceLog", back_populates="predictions")
