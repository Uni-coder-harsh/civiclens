"""add civic_reports table

Revision ID: a2f3b4c5d6e7
Revises: 1c9b82ee35bf
Create Date: 2026-08-11
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = 'a2f3b4c5d6e7'
down_revision: Union[str, None] = '1c9b82ee35bf'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'civic_reports',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column('client_id', sa.String(255), nullable=False),
        sa.Column('user_id', sa.String(255), nullable=False),
        sa.Column('is_guest', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('category', sa.String(100), nullable=False),
        sa.Column('severity', sa.String(50), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('latitude', sa.Float(), nullable=False),
        sa.Column('longitude', sa.Float(), nullable=False),
        sa.Column('altitude_m', sa.Float(), nullable=True),
        sa.Column('accuracy_m', sa.Float(), nullable=True),
        sa.Column('bearing_deg', sa.Float(), nullable=True),
        sa.Column('speed_mps', sa.Float(), nullable=True),
        sa.Column('captured_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('image_url', sa.String(2048), nullable=True),
        sa.Column('thumbnail_url', sa.String(2048), nullable=True),
        sa.Column('quality_gate', sa.String(50), nullable=False, server_default='ok'),
        sa.Column('status', sa.String(50), nullable=False, server_default='submitted'),
        sa.Column('contractor_id', sa.String(255), nullable=True),
        sa.Column('infrastructure_id', sa.String(255), nullable=True),
        sa.Column('sensor_data', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column('ai_confidence', sa.Float(), nullable=True),
        sa.Column('ai_label', sa.String(255), nullable=True),
        sa.Column('civic_score_delta', sa.Integer(), nullable=False, server_default='10'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('created_by', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('updated_by', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('version', sa.Integer(), nullable=False, server_default='1'),
        if_not_exists=True,
    )


def downgrade() -> None:
    op.drop_table('civic_reports')
