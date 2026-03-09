"""add reject_reasons table

Revision ID: a1b2c3d4e5f6
Revises: f1a2b3c4d5e6
Create Date: 2026-03-09 23:10:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'a1b2c3d4e5f6'
down_revision = 'b1c2d3e4f5a6'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Table may already exist in environments where it was created manually.
    # Use raw SQL with IF NOT EXISTS to make the migration idempotent.
    op.execute("""
        CREATE TABLE IF NOT EXISTS reject_reasons (
            reason_code   VARCHAR(64)  PRIMARY KEY,
            label         VARCHAR(255) NOT NULL,
            severity      VARCHAR(16)  NOT NULL DEFAULT 'MED',
            requires_comment BOOLEAN   NOT NULL DEFAULT FALSE,
            is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
            created_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
            created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
            updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
        )
    """)


def downgrade() -> None:
    op.drop_table('reject_reasons')
