import uuid
from datetime import datetime
from sqlalchemy import Float, ForeignKey, String, Text, DateTime
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.common.models import Base


class InfrastructureIdentityRecord(Base):
    """
    Persists resolved infrastructure identity details for a given GPS coordinate location or asset.
    """
    __tablename__ = "infrastructure_identities"

    asset_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("infrastructure_assets.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    report_id: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)

    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    accuracy_m: Mapped[float | None] = mapped_column(Float, nullable=True)

    name: Mapped[str] = mapped_column(String(255), nullable=False)
    type: Mapped[str] = mapped_column(String(100), nullable=False)
    road_reference: Mapped[str | None] = mapped_column(String(100), nullable=True)
    authority: Mapped[str | None] = mapped_column(String(255), nullable=True)

    verification_status: Mapped[str] = mapped_column(String(50), nullable=False, default="UNVERIFIED")
    confidence_score: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)

    identity_metadata: Mapped[dict | None] = mapped_column(JSONB, nullable=True)

    organizations: Mapped[list["InfrastructureOrganizationRecord"]] = relationship(
        "InfrastructureOrganizationRecord",
        back_populates="identity",
        cascade="all, delete-orphan",
    )
    sources: Mapped[list["SourceRecordData"]] = relationship(
        "SourceRecordData",
        back_populates="identity",
        cascade="all, delete-orphan",
    )


class InfrastructureOrganizationRecord(Base):
    """
    Tracks associated organizations (Contractors, EPC, Maintainers, Authorities)
    with role lifecycle windows (valid_from / valid_to), provenance, and verification level.
    """
    __tablename__ = "infrastructure_organizations"

    identity_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("infrastructure_identities.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    asset_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("infrastructure_assets.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    name: Mapped[str] = mapped_column(String(255), nullable=False)
    normalized_name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    role: Mapped[str] = mapped_column(String(50), nullable=False)  # ORIGINAL_BUILDER, CURRENT_MAINTAINER, etc.

    verification_status: Mapped[str] = mapped_column(String(50), nullable=False, default="UNVERIFIED")
    confidence_score: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)

    source: Mapped[str] = mapped_column(String(255), nullable=False)
    source_url: Mapped[str | None] = mapped_column(String(2048), nullable=True)
    source_record_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    cin_gstin: Mapped[str | None] = mapped_column(String(100), nullable=True)
    valid_from: Mapped[str | None] = mapped_column(String(50), nullable=True)
    valid_to: Mapped[str | None] = mapped_column(String(50), nullable=True)

    identity: Mapped[InfrastructureIdentityRecord] = relationship(
        "InfrastructureIdentityRecord", back_populates="organizations"
    )


class SourceRecordData(Base):
    """
    Preserves audit provenance for every retrieved government dataset / procurement payload.
    """
    __tablename__ = "source_records"

    identity_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("infrastructure_identities.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    provider_name: Mapped[str] = mapped_column(String(100), nullable=False)
    provider_type: Mapped[str] = mapped_column(String(50), nullable=False)
    source_url: Mapped[str | None] = mapped_column(String(2048), nullable=True)
    record_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    raw_payload: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    retrieved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    identity: Mapped[InfrastructureIdentityRecord] = relationship(
        "InfrastructureIdentityRecord", back_populates="sources"
    )
