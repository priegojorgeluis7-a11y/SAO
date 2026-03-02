"""add_index_project_sync_version

Revision ID: 6afdfb767b40
Revises: 5fd505b2d50b
Create Date: 2026-02-19 11:18:10.623827

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '6afdfb767b40'
down_revision = '5fd505b2d50b'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add composite index on (project_id, sync_version) for efficient sync queries
    op.create_index('idx_activity_project_sync', 'activities', ['project_id', 'sync_version'], unique=False)


def downgrade() -> None:
    # Drop the composite index
    op.drop_index('idx_activity_project_sync', table_name='activities')
