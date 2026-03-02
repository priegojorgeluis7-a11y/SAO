"""Create catalog schema

Revision ID: 001_create_catalog_schema
Revises: 
Create Date: 2026-02-18
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "001_create_catalog_schema"
down_revision = None
branch_labels = None
depends_on = None


ENTITY_TYPES = (
    "activity",
    "subcategory",
    "purpose",
    "topic",
    "result",
    "attendee",
    "rel_activity_topic",
)

SEVERITY_VALUES = ("green", "yellow", "red", "blue")


def upgrade() -> None:
    op.execute(
        "CREATE TYPE entity_type_enum AS ENUM "
        + "(" + ", ".join([f"'{t}'" for t in ENTITY_TYPES]) + ")"
    )

    op.create_table(
        "catalog_version",
        sa.Column("version_id", sa.Text(), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.Column("changelog", sa.Text()),
    )

    op.create_table(
        "cat_projects",
        sa.Column("project_id", sa.Text(), primary_key=True),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("version_id", sa.Text(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["version_id"], ["catalog_version.version_id"]),
    )

    op.create_table(
        "cat_activities",
        sa.Column("activity_id", sa.Text(), primary_key=True),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("version_id", sa.Text(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["version_id"], ["catalog_version.version_id"]),
    )

    op.create_table(
        "cat_subcategories",
        sa.Column("subcategory_id", sa.Text(), primary_key=True),
        sa.Column("activity_id", sa.Text(), nullable=False),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("version_id", sa.Text(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["activity_id"], ["cat_activities.activity_id"]),
        sa.ForeignKeyConstraint(["version_id"], ["catalog_version.version_id"]),
    )

    op.create_table(
        "cat_purposes",
        sa.Column("purpose_id", sa.Text(), primary_key=True),
        sa.Column("activity_id", sa.Text(), nullable=False),
        sa.Column("subcategory_id", sa.Text(), nullable=True),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("version_id", sa.Text(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["activity_id"], ["cat_activities.activity_id"]),
        sa.ForeignKeyConstraint(["subcategory_id"], ["cat_subcategories.subcategory_id"]),
        sa.ForeignKeyConstraint(["version_id"], ["catalog_version.version_id"]),
    )

    op.create_table(
        "cat_topics",
        sa.Column("topic_id", sa.Text(), primary_key=True),
        sa.Column("type", sa.Text(), nullable=True),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("version_id", sa.Text(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["version_id"], ["catalog_version.version_id"]),
    )

    op.create_table(
        "rel_activity_topics",
        sa.Column("activity_id", sa.Text(), primary_key=True),
        sa.Column("topic_id", sa.Text(), primary_key=True),
        sa.Column("version_id", sa.Text(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["activity_id"], ["cat_activities.activity_id"]),
        sa.ForeignKeyConstraint(["topic_id"], ["cat_topics.topic_id"]),
        sa.ForeignKeyConstraint(["version_id"], ["catalog_version.version_id"]),
    )

    op.create_table(
        "cat_results",
        sa.Column("result_id", sa.Text(), primary_key=True),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("category", sa.Text(), nullable=False),
        sa.Column("version_id", sa.Text(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["version_id"], ["catalog_version.version_id"]),
    )

    op.create_table(
        "cat_attendees",
        sa.Column("attendee_id", sa.Text(), primary_key=True),
        sa.Column("type", sa.Text(), nullable=False),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("version_id", sa.Text(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["version_id"], ["catalog_version.version_id"]),
    )

    op.create_table(
        "proj_catalog_override",
        sa.Column("project_id", sa.Text(), nullable=False),
        sa.Column("entity_type", sa.Enum(*ENTITY_TYPES, name="entity_type_enum"), nullable=False),
        sa.Column("entity_id", sa.Text(), nullable=False),
        sa.Column("is_enabled", sa.Boolean(), nullable=True),
        sa.Column("display_name_override", sa.Text(), nullable=True),
        sa.Column("sort_order_override", sa.Integer(), nullable=True),
        sa.Column("color_override", sa.Text(), nullable=True),
        sa.Column("severity_override", sa.Text(), nullable=True),
        sa.Column("rules_json", sa.dialects.postgresql.JSONB(), nullable=True),
        sa.Column("version_id", sa.Text(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["project_id"], ["cat_projects.project_id"]),
        sa.ForeignKeyConstraint(["version_id"], ["catalog_version.version_id"]),
        sa.PrimaryKeyConstraint("project_id", "entity_type", "entity_id"),
        sa.CheckConstraint(
            "severity_override IS NULL OR severity_override IN ('green','yellow','red','blue')",
            name="chk_proj_catalog_override_severity",
        ),
    )


def downgrade() -> None:
    op.drop_table("proj_catalog_override")
    op.drop_table("cat_attendees")
    op.drop_table("cat_results")
    op.drop_table("rel_activity_topics")
    op.drop_table("cat_topics")
    op.drop_table("cat_purposes")
    op.drop_table("cat_subcategories")
    op.drop_table("cat_activities")
    op.drop_table("cat_projects")
    op.drop_table("catalog_version")
    op.execute("DROP TYPE entity_type_enum")
