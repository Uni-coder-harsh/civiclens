import uuid
from datetime import datetime
from decimal import Decimal
from sqlalchemy import ForeignKey, Numeric, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.common.models import Base


class InfrastructurePassport(Base):
    __tablename__ = "infrastructure_passports"

    asset_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("infrastructure_assets.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    passport_number: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    structural_health_index: Mapped[Decimal] = mapped_column(Numeric(5, 2), default=Decimal("100.00"), nullable=False)
    last_inspected_at: Mapped[datetime | None] = mapped_column(nullable=True)
    next_inspection_due: Mapped[datetime | None] = mapped_column(nullable=True)
    degradation_rate: Mapped[Decimal] = mapped_column(Numeric(5, 2), default=Decimal("0.00"), nullable=False)

    history: Mapped[list["AssetDegradationHistory"]] = relationship(
        "AssetDegradationHistory",
        back_populates="passport",
        cascade="all, delete-orphan",
    )


class AssetDegradationHistory(Base):
    __tablename__ = "asset_degradation_history"

    passport_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("infrastructure_passports.id", ondelete="CASCADE"),
        nullable=False,
    )
    health_index: Mapped[Decimal] = mapped_column(Numeric(5, 2), nullable=False)
    change_reason: Mapped[str] = mapped_column(String(255), nullable=False)

    passport: Mapped[InfrastructurePassport] = relationship("InfrastructurePassport", back_populates="history")
