"""Add events table for field incident reporting.

Revision ID: f1a2b3c4d5e6
Revises: e1f2a3b4c5d6
Create Date: 2026-03-02

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = 'f1a2b3c4d5e6'
down_revision = 'e1f2a3b4c5d6'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'events',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('uuid', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('sync_version', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('deleted_at', sa.DateTime(), nullable=True),
        sa.Column('project_id', sa.String(length=10), nullable=False),
        sa.Column('event_type_code', sa.String(length=50), nullable=False),
        sa.Column('title', sa.String(length=200), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('severity', sa.String(length=10), nullable=False, server_default='MEDIUM'),
        sa.Column('location_pk_meters', sa.Integer(), nullable=True),
        sa.Column('latitude', sa.String(length=20), nullable=True),
        sa.Column('longitude', sa.String(length=20), nullable=True),
        sa.Column('occurred_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('resolved_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('reported_by_user_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('assigned_to_user_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('form_fields_json', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')",
            name='check_event_severity',
        ),
        sa.ForeignKeyConstraint(['assigned_to_user_id'], ['users.id']),
        sa.ForeignKeyConstraint(['project_id'], ['projects.id']),
        sa.ForeignKeyConstraint(['reported_by_user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
    )

    # Unique and search indexes
    op.create_index(op.f('ix_events_uuid'), 'events', ['uuid'], unique=True)
    op.create_index(op.f('ix_events_sync_version'), 'events', ['sync_version'], unique=False)
    op.create_index(op.f('ix_events_project_id'), 'events', ['project_id'], unique=False)
    op.create_index(op.f('ix_events_deleted_at'), 'events', ['deleted_at'], unique=False)
    op.create_index(op.f('ix_events_severity'), 'events', ['severity'], unique=False)
    op.create_index(op.f('ix_events_location_pk_meters'), 'events', ['location_pk_meters'], unique=False)
    op.create_index(op.f('ix_events_reported_by_user_id'), 'events', ['reported_by_user_id'], unique=False)
    op.create_index('idx_event_sync', 'events', ['sync_version', 'updated_at'], unique=False)
    op.create_index('idx_event_project_severity', 'events', ['project_id', 'severity'], unique=False)


def downgrade() -> None:
    op.drop_index('idx_event_project_severity', table_name='events')
    op.drop_index('idx_event_sync', table_name='events')
    op.drop_index(op.f('ix_events_reported_by_user_id'), table_name='events')
    op.drop_index(op.f('ix_events_location_pk_meters'), table_name='events')
    op.drop_index(op.f('ix_events_severity'), table_name='events')
    op.drop_index(op.f('ix_events_deleted_at'), table_name='events')
    op.drop_index(op.f('ix_events_project_id'), table_name='events')
    op.drop_index(op.f('ix_events_sync_version'), table_name='events')
    op.drop_index(op.f('ix_events_uuid'), table_name='events')
    op.drop_table('events')
