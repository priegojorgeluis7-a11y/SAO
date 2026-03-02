"""add_effective_catalog_tables

Sistema de catálogo efectivo usado por la app móvil (sync/diff).
Es un sistema SEPARADO de catalog_versions (admin).

- catalog_version  : versión activa marcada con is_current=true
- cat_projects     : proyectos con versión asignada
- cat_activities   : actividades de campo
- cat_subcategories: subcategorías por actividad
- cat_purposes     : propósitos/objetivos por actividad+subcategoría
- cat_topics       : temas (capacitación, seguridad, etc.)
- rel_activity_topics: relación N:N actividad ↔ tema
- cat_results      : resultados de inspección
- cat_attendees    : roles de asistentes
- proj_catalog_override: overrides por proyecto

Revision ID: d3e4f5a6b7c8
Revises: 6afdfb767b40
Create Date: 2026-02-26 00:00:00.000000
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = 'd3e4f5a6b7c8'
down_revision = 'b7a1b6c8d9e0'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── catalog_version ──────────────────────────────────────────────────────
    op.create_table(
        'catalog_version',
        sa.Column('version_id', sa.Text(), primary_key=True, nullable=False),
        sa.Column('is_current', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('changelog', sa.Text(), nullable=True),
    )
    op.create_index('ix_catalog_version_is_current', 'catalog_version', ['is_current'])

    # ── cat_projects ─────────────────────────────────────────────────────────
    op.create_table(
        'cat_projects',
        sa.Column('project_id', sa.Text(), primary_key=True, nullable=False),
        sa.Column('name', sa.Text(), nullable=False),
        sa.Column('version_id', sa.Text(),
                  sa.ForeignKey('catalog_version.version_id'), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )

    # ── cat_activities ────────────────────────────────────────────────────────
    op.create_table(
        'cat_activities',
        sa.Column('activity_id', sa.Text(), primary_key=True, nullable=False),
        sa.Column('name', sa.Text(), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('version_id', sa.Text(),
                  sa.ForeignKey('catalog_version.version_id'), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_cat_activities_version', 'cat_activities', ['version_id'])

    # ── cat_subcategories ─────────────────────────────────────────────────────
    op.create_table(
        'cat_subcategories',
        sa.Column('subcategory_id', sa.Text(), primary_key=True, nullable=False),
        sa.Column('activity_id', sa.Text(),
                  sa.ForeignKey('cat_activities.activity_id'), nullable=False),
        sa.Column('name', sa.Text(), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('version_id', sa.Text(),
                  sa.ForeignKey('catalog_version.version_id'), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_cat_subcategories_activity', 'cat_subcategories', ['activity_id'])

    # ── cat_purposes ──────────────────────────────────────────────────────────
    op.create_table(
        'cat_purposes',
        sa.Column('purpose_id', sa.Text(), primary_key=True, nullable=False),
        sa.Column('activity_id', sa.Text(),
                  sa.ForeignKey('cat_activities.activity_id'), nullable=False),
        sa.Column('subcategory_id', sa.Text(),
                  sa.ForeignKey('cat_subcategories.subcategory_id'), nullable=True),
        sa.Column('name', sa.Text(), nullable=False),
        sa.Column('version_id', sa.Text(),
                  sa.ForeignKey('catalog_version.version_id'), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_cat_purposes_activity', 'cat_purposes', ['activity_id'])

    # ── cat_topics ────────────────────────────────────────────────────────────
    op.create_table(
        'cat_topics',
        sa.Column('topic_id', sa.Text(), primary_key=True, nullable=False),
        sa.Column('type', sa.Text(), nullable=True),
        sa.Column('name', sa.Text(), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('version_id', sa.Text(),
                  sa.ForeignKey('catalog_version.version_id'), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_cat_topics_version', 'cat_topics', ['version_id'])

    # ── rel_activity_topics ───────────────────────────────────────────────────
    op.create_table(
        'rel_activity_topics',
        sa.Column('activity_id', sa.Text(),
                  sa.ForeignKey('cat_activities.activity_id'), primary_key=True, nullable=False),
        sa.Column('topic_id', sa.Text(),
                  sa.ForeignKey('cat_topics.topic_id'), primary_key=True, nullable=False),
        sa.Column('version_id', sa.Text(),
                  sa.ForeignKey('catalog_version.version_id'), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )

    # ── cat_results ───────────────────────────────────────────────────────────
    op.create_table(
        'cat_results',
        sa.Column('result_id', sa.Text(), primary_key=True, nullable=False),
        sa.Column('name', sa.Text(), nullable=False),
        sa.Column('category', sa.Text(), nullable=False),
        sa.Column('severity_default', sa.Text(), nullable=True),
        sa.Column('version_id', sa.Text(),
                  sa.ForeignKey('catalog_version.version_id'), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )

    # ── cat_attendees ─────────────────────────────────────────────────────────
    op.create_table(
        'cat_attendees',
        sa.Column('attendee_id', sa.Text(), primary_key=True, nullable=False),
        sa.Column('type', sa.Text(), nullable=False),
        sa.Column('name', sa.Text(), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('version_id', sa.Text(),
                  sa.ForeignKey('catalog_version.version_id'), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )

    # ── proj_catalog_override ─────────────────────────────────────────────────
    op.create_table(
        'proj_catalog_override',
        sa.Column('project_id', sa.Text(),
                  sa.ForeignKey('cat_projects.project_id'), primary_key=True, nullable=False),
        sa.Column('entity_type', sa.Text(), primary_key=True, nullable=False),
        sa.Column('entity_id', sa.Text(), primary_key=True, nullable=False),
        sa.Column('is_enabled', sa.Boolean(), nullable=True),
        sa.Column('display_name_override', sa.Text(), nullable=True),
        sa.Column('sort_order_override', sa.Integer(), nullable=True),
        sa.Column('color_override', sa.Text(), nullable=True),
        sa.Column('severity_override', sa.Text(), nullable=True),
        sa.Column('rules_json', sa.JSON(), nullable=True),
        sa.Column('version_id', sa.Text(),
                  sa.ForeignKey('catalog_version.version_id'), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )


def downgrade() -> None:
    op.drop_table('proj_catalog_override')
    op.drop_table('cat_attendees')
    op.drop_table('cat_results')
    op.drop_table('rel_activity_topics')
    op.drop_table('cat_topics')
    op.drop_table('cat_purposes')
    op.drop_index('ix_cat_subcategories_activity', table_name='cat_subcategories')
    op.drop_table('cat_subcategories')
    op.drop_index('ix_cat_activities_version', table_name='cat_activities')
    op.drop_table('cat_activities')
    op.drop_table('cat_projects')
    op.drop_index('ix_catalog_version_is_current', table_name='catalog_version')
    op.drop_table('catalog_version')
