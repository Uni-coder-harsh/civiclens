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
    # Use raw SQL with IF NOT EXISTS so this is idempotent even if re-run
    op.execute("""
        CREATE TABLE IF NOT EXISTS civic_reports (
            id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            client_id       VARCHAR(255) NOT NULL,
            user_id         VARCHAR(255) NOT NULL,
            is_guest        BOOLEAN NOT NULL DEFAULT FALSE,
            category        VARCHAR(100) NOT NULL,
            severity        VARCHAR(50)  NOT NULL,
            description     TEXT,
            latitude        FLOAT NOT NULL,
            longitude       FLOAT NOT NULL,
            altitude_m      FLOAT,
            accuracy_m      FLOAT,
            bearing_deg     FLOAT,
            speed_mps       FLOAT,
            captured_at     TIMESTAMPTZ,
            image_url       VARCHAR(2048),
            thumbnail_url   VARCHAR(2048),
            quality_gate    VARCHAR(50)  NOT NULL DEFAULT 'ok',
            status          VARCHAR(50)  NOT NULL DEFAULT 'submitted',
            contractor_id   VARCHAR(255),
            infrastructure_id VARCHAR(255),
            sensor_data     JSONB,
            ai_confidence   FLOAT,
            ai_label        VARCHAR(255),
            civic_score_delta INTEGER NOT NULL DEFAULT 10,
            created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            created_by      UUID,
            updated_by      UUID,
            deleted_at      TIMESTAMPTZ,
            is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
            version         INTEGER NOT NULL DEFAULT 1
        );
    """)

    op.execute("""
        CREATE INDEX IF NOT EXISTS ix_civic_reports_client_id ON civic_reports (client_id);
    """)
    op.execute("""
        CREATE INDEX IF NOT EXISTS ix_civic_reports_user_id ON civic_reports (user_id);
    """)
    op.execute("""
        CREATE INDEX IF NOT EXISTS ix_civic_reports_status ON civic_reports (status);
    """)


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS civic_reports CASCADE;")
