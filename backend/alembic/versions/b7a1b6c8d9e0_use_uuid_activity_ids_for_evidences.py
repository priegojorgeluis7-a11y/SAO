"""Use UUID activity IDs for evidences.

Revision ID: b7a1b6c8d9e0
Revises: c4e9d2a1b7f0
Create Date: 2026-02-24

Note: PostgreSQL converts uuid/activity_id columns to UUID type.
SQLite stores everything as TEXT so uuid columns are already compatible —
no ALTER needed, this migration is a no-op on SQLite.

Fix (2026-02-26): Changed from op.drop_constraint + op.alter_column to raw
SQL with dynamic FK discovery.  The original code relied on the auto-generated
constraint name being exactly "evidences_activity_id_fkey"; if the name
differed (or the migration was re-run after a partial failure) the DROP
silently failed and the subsequent ALTER TABLE … TYPE UUID raised:

    DatatypeMismatch: foreign key constraint "evidences_activity_id_fkey"
    cannot be implemented

The new approach:
  1. Discovers and drops ALL FK constraints on evidences.activity_id via
     information_schema — name-independent.
  2. Uses raw ALTER TABLE … USING uuid::uuid so the USING clause is always
     sent explicitly (avoids Alembic version quirks with postgresql_using).
  3. Guards every DROP with IF EXISTS for idempotency on re-runs.
"""

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = "b7a1b6c8d9e0"
down_revision = "c4e9d2a1b7f0"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "sqlite":
        # SQLite stores UUIDs as TEXT natively; no type change needed.
        return

    # ------------------------------------------------------------------
    # Step 1: Drop ALL FK constraints on evidences.activity_id.
    # We use information_schema so we are not tied to a specific auto-
    # generated constraint name.
    # ------------------------------------------------------------------
    op.execute(sa.text("""
        DO $body$
        DECLARE
            r record;
        BEGIN
            FOR r IN
                SELECT tc.constraint_name
                FROM information_schema.table_constraints AS tc
                JOIN information_schema.key_column_usage   AS kcu
                    ON  tc.constraint_name = kcu.constraint_name
                    AND tc.table_schema    = kcu.table_schema
                WHERE tc.constraint_type = 'FOREIGN KEY'
                  AND tc.table_name      = 'evidences'
                  AND kcu.column_name    = 'activity_id'
                  AND tc.table_schema    = current_schema()
            LOOP
                EXECUTE format(
                    'ALTER TABLE evidences DROP CONSTRAINT IF EXISTS %I',
                    r.constraint_name
                );
            END LOOP;
        END $body$;
    """))

    # ------------------------------------------------------------------
    # Step 2: Convert activities.uuid  VARCHAR(36) → UUID
    # USING is mandatory: PostgreSQL has no implicit varchar→uuid cast.
    # ------------------------------------------------------------------
    op.execute(sa.text(
        "ALTER TABLE activities ALTER COLUMN uuid TYPE UUID USING uuid::uuid"
    ))

    # ------------------------------------------------------------------
    # Step 3: Convert evidences.activity_id  VARCHAR(36) → UUID
    # ------------------------------------------------------------------
    op.execute(sa.text(
        "ALTER TABLE evidences ALTER COLUMN activity_id TYPE UUID USING activity_id::uuid"
    ))

    # ------------------------------------------------------------------
    # Step 4: Re-create FK — both columns are now UUID, types match.
    # ------------------------------------------------------------------
    op.create_foreign_key(
        "evidences_activity_id_fkey",
        "evidences",
        "activities",
        ["activity_id"],
        ["uuid"],
        ondelete="CASCADE",
    )


def downgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "sqlite":
        return

    # Drop FK (IF EXISTS guards against partially-applied state).
    op.execute(sa.text(
        "ALTER TABLE evidences "
        "DROP CONSTRAINT IF EXISTS evidences_activity_id_fkey"
    ))

    # Revert evidences.activity_id  UUID → VARCHAR(36)
    op.execute(sa.text(
        "ALTER TABLE evidences "
        "ALTER COLUMN activity_id TYPE VARCHAR(36) USING activity_id::text"
    ))

    # Revert activities.uuid  UUID → VARCHAR(36)
    op.execute(sa.text(
        "ALTER TABLE activities "
        "ALTER COLUMN uuid TYPE VARCHAR(36) USING uuid::text"
    ))

    # Recreate FK (now VARCHAR ↔ VARCHAR — types match again).
    op.create_foreign_key(
        "evidences_activity_id_fkey",
        "evidences",
        "activities",
        ["activity_id"],
        ["uuid"],
        ondelete="CASCADE",
    )
