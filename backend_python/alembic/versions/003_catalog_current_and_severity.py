"""Add catalog current flag and result severity

Revision ID: 003_catalog_current_and_severity
Revises: 002_indexes_constraints
Create Date: 2026-02-18
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "003_catalog_current_and_severity"
down_revision = "002_indexes_constraints"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "catalog_version",
        sa.Column("is_current", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )

    op.execute("UPDATE catalog_version SET is_current = false")

    op.execute(
        "CREATE UNIQUE INDEX ux_catalog_version_current ON catalog_version (is_current) WHERE is_current"
    )

    op.add_column(
        "cat_results",
        sa.Column("severity_default", sa.Text(), nullable=True),
    )

    op.create_check_constraint(
        "chk_cat_results_severity_default",
        "cat_results",
        "severity_default IS NULL OR severity_default IN ('green','yellow','red','blue')",
    )


def downgrade() -> None:
    op.drop_constraint("chk_cat_results_severity_default", "cat_results", type_="check")
    op.drop_column("cat_results", "severity_default")
    op.execute("DROP INDEX ux_catalog_version_current")
    op.drop_column("catalog_version", "is_current")
