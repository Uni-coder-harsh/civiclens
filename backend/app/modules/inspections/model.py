import uuid
from datetime import datetime
from geoalchemy2 import Geometry
from sqlalchemy import BigInteger, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.common.models import Base


class Inspection(Base):
    __tablename__ = "inspections"

    asset_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("infrastructure_assets.id", ondelete="CASCADE"), nullable=False)
    inspector_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    scheduled_at: Mapped[datetime] = mapped_column(nullable=False)
    started_at: Mapped[datetime | None] = mapped_column(nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(nullable=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False)
    summary_report_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)

    items: Mapped[list["InspectionItem"]] = relationship("InspectionItem", back_populates="inspection", cascade="all, delete-orphan")


class InspectionItem(Base):
    __tablename__ = "inspection_items"

    inspection_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("inspections.id", ondelete="CASCADE"), nullable=False)
    location_geometry: Mapped[object] = mapped_column(Geometry("Point", srid=4326), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    detected_severity: Mapped[str] = mapped_column(String(50), nullable=False)
    assigned_severity: Mapped[str | None] = mapped_column(String(50), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    inspection: Mapped[Inspection] = relationship("Inspection", back_populates="items")
    media: Mapped[list["InspectionMedia"]] = relationship("InspectionMedia", back_populates="inspection_item", cascade="all, delete-orphan")


class InspectionMedia(Base):
    __tablename__ = "inspection_media"

    inspection_item_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("inspection_items.id", ondelete="CASCADE"), nullable=False)
    media_type: Mapped[str] = mapped_column(String(20), nullable=False)
    file_url: Mapped[str] = mapped_column(String(1024), nullable=False)
    file_size_bytes: Mapped[int] = mapped_column(BigInteger, nullable=False)
    mime_type: Mapped[str] = mapped_column(String(100), nullable=False)

    inspection_item: Mapped[InspectionItem] = relationship("InspectionItem", back_populates="media")
