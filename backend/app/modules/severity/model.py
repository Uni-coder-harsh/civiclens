import uuid
from decimal import Decimal
from sqlalchemy import ForeignKey, Numeric, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.common.models import Base


class SeverityRule(Base):
    __tablename__ = "severity_rules"

    class_name: Mapped[str] = mapped_column(String(100), nullable=False)
    parameter_name: Mapped[str] = mapped_column(String(100), nullable=False)
    operator: Mapped[str] = mapped_column(String(10), nullable=False)
    threshold_value: Mapped[Decimal] = mapped_column(Numeric(10, 4), nullable=False)
    assigned_severity: Mapped[str] = mapped_column(String(50), nullable=False)


class AutomatedAssessment(Base):
    __tablename__ = "automated_assessments"

    inspection_item_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("inspection_items.id", ondelete="CASCADE"), unique=True, nullable=False)
    calculated_severity: Mapped[str] = mapped_column(String(50), nullable=False)
    priority_score: Mapped[Decimal] = mapped_column(Numeric(5, 2), nullable=False)
    reasoning_details: Mapped[str | None] = mapped_column(Text, nullable=True)
