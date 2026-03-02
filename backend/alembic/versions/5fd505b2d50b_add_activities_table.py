"""add activities table

Revision ID: 5fd505b2d50b
Revises: 894874841371
Create Date: 2026-02-18 23:19:58.428533

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '5fd505b2d50b'
down_revision = '894874841371'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create activities table only (removed ALTER COLUMN operations for SQLite compatibility)
    op.create_table('activities',
    sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
    sa.Column('uuid', sa.String(length=36), nullable=False),
    sa.Column('sync_version', sa.Integer(), nullable=False),
    sa.Column('deleted_at', sa.DateTime(), nullable=True),
    sa.Column('project_id', sa.String(length=10), nullable=False),
    sa.Column('front_id', sa.dialects.postgresql.UUID(as_uuid=True), nullable=True),
    sa.Column('pk_start', sa.Integer(), nullable=False),
    sa.Column('pk_end', sa.Integer(), nullable=True),
    sa.Column('execution_state', sa.String(length=20), nullable=False),
    sa.Column('assigned_to_user_id', sa.dialects.postgresql.UUID(as_uuid=True), nullable=True),
    sa.Column('created_by_user_id', sa.dialects.postgresql.UUID(as_uuid=True), nullable=False),
    sa.Column('catalog_version_id', sa.dialects.postgresql.UUID(as_uuid=True), nullable=False),
    sa.Column('activity_type_code', sa.String(length=20), nullable=False),
    sa.Column('latitude', sa.String(length=20), nullable=True),
    sa.Column('longitude', sa.String(length=20), nullable=True),
    sa.Column('title', sa.String(length=200), nullable=True),
    sa.Column('description', sa.Text(), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    sa.CheckConstraint("execution_state IN ('PENDIENTE', 'EN_CURSO', 'REVISION_PENDIENTE', 'COMPLETADA')", name='check_execution_state'),
    sa.CheckConstraint('pk_end IS NULL OR pk_end >= pk_start', name='check_pk_range'),
    sa.ForeignKeyConstraint(['assigned_to_user_id'], ['users.id'], ),
    sa.ForeignKeyConstraint(['catalog_version_id'], ['catalog_versions.id'], ),
    sa.ForeignKeyConstraint(['created_by_user_id'], ['users.id'], ),
    sa.ForeignKeyConstraint(['front_id'], ['fronts.id'], ),
    sa.ForeignKeyConstraint(['project_id'], ['projects.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index('idx_activity_pk_range', 'activities', ['pk_start', 'pk_end'], unique=False)
    op.create_index('idx_activity_project_front', 'activities', ['project_id', 'front_id'], unique=False)
    op.create_index('idx_activity_sync', 'activities', ['sync_version', 'updated_at'], unique=False)
    op.create_index(op.f('ix_activities_assigned_to_user_id'), 'activities', ['assigned_to_user_id'], unique=False)
    op.create_index(op.f('ix_activities_created_by_user_id'), 'activities', ['created_by_user_id'], unique=False)
    op.create_index(op.f('ix_activities_deleted_at'), 'activities', ['deleted_at'], unique=False)
    op.create_index(op.f('ix_activities_execution_state'), 'activities', ['execution_state'], unique=False)
    op.create_index(op.f('ix_activities_front_id'), 'activities', ['front_id'], unique=False)
    op.create_index(op.f('ix_activities_pk_start'), 'activities', ['pk_start'], unique=False)
    op.create_index(op.f('ix_activities_project_id'), 'activities', ['project_id'], unique=False)
    op.create_index(op.f('ix_activities_sync_version'), 'activities', ['sync_version'], unique=False)
    op.create_index(op.f('ix_activities_uuid'), 'activities', ['uuid'], unique=True)


def downgrade() -> None:
    # Drop activities table and its indexes
    op.drop_index(op.f('ix_activities_uuid'), table_name='activities')
    op.drop_index(op.f('ix_activities_sync_version'), table_name='activities')
    op.drop_index(op.f('ix_activities_project_id'), table_name='activities')
    op.drop_index(op.f('ix_activities_pk_start'), table_name='activities')
    op.drop_index(op.f('ix_activities_front_id'), table_name='activities')
    op.drop_index(op.f('ix_activities_execution_state'), table_name='activities')
    op.drop_index(op.f('ix_activities_deleted_at'), table_name='activities')
    op.drop_index(op.f('ix_activities_created_by_user_id'), table_name='activities')
    op.drop_index(op.f('ix_activities_assigned_to_user_id'), table_name='activities')
    op.drop_index('idx_activity_sync', table_name='activities')
    op.drop_index('idx_activity_project_front', table_name='activities')
    op.drop_index('idx_activity_pk_range', table_name='activities')
    op.drop_table('activities')
