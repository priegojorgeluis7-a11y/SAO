"""Add observations table for mobile correction inbox.

Revision ID: b1c2d3e4f5a6
Revises: a9b8c7d6e5f4
Create Date: 2026-03-02

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = 'b1c2d3e4f5a6'
down_revision = 'a9b8c7d6e5f4'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'observations',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('sync_version', sa.Integer(), nullable=False),
        sa.Column('deleted_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('project_id', sa.String(length=10), nullable=False),
        sa.Column('activity_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('assignee_user_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('tags_json', sa.Text(), nullable=True),
        sa.Column('message', sa.Text(), nullable=False),
        sa.Column('severity', sa.String(length=10), nullable=False, server_default='MED'),
        sa.Column('due_date', sa.DateTime(timezone=True), nullable=True),
        sa.Column('status', sa.String(length=16), nullable=False, server_default='OPEN'),
        sa.Column('resolved_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['activity_id'], ['activities.uuid'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['assignee_user_id'], ['users.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['project_id'], ['projects.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_observations_sync_version'), 'observations', ['sync_version'], unique=False)
    op.create_index(op.f('ix_observations_deleted_at'), 'observations', ['deleted_at'], unique=False)
    op.create_index(op.f('ix_observations_project_id'), 'observations', ['project_id'], unique=False)
    op.create_index(op.f('ix_observations_activity_id'), 'observations', ['activity_id'], unique=False)
    op.create_index(op.f('ix_observations_assignee_user_id'), 'observations', ['assignee_user_id'], unique=False)
    op.create_index(op.f('ix_observations_status'), 'observations', ['status'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_observations_status'), table_name='observations')
    op.drop_index(op.f('ix_observations_assignee_user_id'), table_name='observations')
    op.drop_index(op.f('ix_observations_activity_id'), table_name='observations')
    op.drop_index(op.f('ix_observations_project_id'), table_name='observations')
    op.drop_index(op.f('ix_observations_deleted_at'), table_name='observations')
    op.drop_index(op.f('ix_observations_sync_version'), table_name='observations')
    op.drop_table('observations')
