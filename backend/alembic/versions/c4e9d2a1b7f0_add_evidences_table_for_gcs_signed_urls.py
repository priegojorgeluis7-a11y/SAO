"""add evidences table for gcs signed urls

Revision ID: c4e9d2a1b7f0
Revises: 6afdfb767b40
Create Date: 2026-02-24 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision = 'c4e9d2a1b7f0'
down_revision = '6afdfb767b40'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'evidences',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('activity_id', sa.String(length=36), nullable=False),
        sa.Column('object_path', sa.Text(), nullable=True),
        sa.Column('pending_object_path', sa.Text(), nullable=True),
        sa.Column('mime_type', sa.String(length=255), nullable=False),
        sa.Column('size_bytes', sa.Integer(), nullable=False),
        sa.Column('original_file_name', sa.String(length=255), nullable=True),
        sa.Column('caption', sa.Text(), nullable=True),
        sa.Column('created_by', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('uploaded_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['activity_id'], ['activities.uuid'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['created_by'], ['users.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
    )

    op.create_index('ix_evidences_activity_id', 'evidences', ['activity_id'], unique=False)
    op.create_index('ix_evidences_created_by', 'evidences', ['created_by'], unique=False)
    op.create_index('idx_evidences_activity_created', 'evidences', ['activity_id', 'created_at'], unique=False)


def downgrade() -> None:
    op.drop_index('idx_evidences_activity_created', table_name='evidences')
    op.drop_index('ix_evidences_created_by', table_name='evidences')
    op.drop_index('ix_evidences_activity_id', table_name='evidences')
    op.drop_table('evidences')
