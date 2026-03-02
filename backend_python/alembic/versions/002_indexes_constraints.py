"""Add catalog indexes

Revision ID: 002_indexes_constraints
Revises: 001_create_catalog_schema
Create Date: 2026-02-18
"""

from alembic import op


# revision identifiers, used by Alembic.
revision = "002_indexes_constraints"
down_revision = "001_create_catalog_schema"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index(
        "ix_cat_subcategories_activity_id",
        "cat_subcategories",
        ["activity_id"],
        unique=False,
    )
    op.create_index(
        "ix_cat_purposes_activity_subcategory",
        "cat_purposes",
        ["activity_id", "subcategory_id"],
        unique=False,
    )
    op.create_index(
        "ix_rel_activity_topics_activity_id",
        "rel_activity_topics",
        ["activity_id"],
        unique=False,
    )
    op.create_index(
        "ix_proj_catalog_override_project_entity",
        "proj_catalog_override",
        ["project_id", "entity_type"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_proj_catalog_override_project_entity", table_name="proj_catalog_override")
    op.drop_index("ix_rel_activity_topics_activity_id", table_name="rel_activity_topics")
    op.drop_index("ix_cat_purposes_activity_subcategory", table_name="cat_purposes")
    op.drop_index("ix_cat_subcategories_activity_id", table_name="cat_subcategories")
