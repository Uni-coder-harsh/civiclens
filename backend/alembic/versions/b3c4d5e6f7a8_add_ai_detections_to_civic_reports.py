"""Add ai_detections, ai_severity, ai_inference_log_id to civic_reports

Revision ID: b3c4d5e6f7a8
Revises: a2f3b4c5d6e7
Create Date: 2026-08-12 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

revision = "b3c4d5e6f7a8"
down_revision = "a2f3b4c5d6e7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "civic_reports",
        sa.Column("ai_severity", sa.String(50), nullable=True,
                  comment="ONNX-derived severity: low/medium/high/critical"),
    )
    op.add_column(
        "civic_reports",
        sa.Column("ai_detections", JSONB, nullable=True,
                  comment="Full ONNX DetectionResult JSON blob"),
    )
    op.add_column(
        "civic_reports",
        sa.Column("ai_inference_log_id", sa.String(255), nullable=True,
                  comment="FK reference to ai_inference_logs.id"),
    )


def downgrade() -> None:
    op.drop_column("civic_reports", "ai_inference_log_id")
    op.drop_column("civic_reports", "ai_detections")
    op.drop_column("civic_reports", "ai_severity")
