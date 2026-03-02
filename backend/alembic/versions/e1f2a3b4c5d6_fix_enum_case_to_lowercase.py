"""Fix enum value case: uppercase → lowercase.

Revision ID: e1f2a3b4c5d6
Revises: d3e4f5a6b7c8
Create Date: 2026-02-26

Root cause of HTTP 500 on login
--------------------------------
All PostgreSQL native enum types were created by migration 2943c465af13 /
894874841371 with UPPERCASE labels (e.g. 'ACTIVE', 'DRAFT', 'ACTIVITY').

The corresponding Python enum classes define lowercase values:
    class UserStatus(str, enum.Enum): ACTIVE = "active"

When SQLAlchemy reads a row and attempts:
    UserStatus('ACTIVE')   →  ValueError: 'ACTIVE' is not a valid UserStatus

FastAPI converts the unhandled ValueError to HTTP 500.

This migration renames every PostgreSQL enum label to its lowercase form so
that the DB values match the Python enum values.

PostgreSQL stores enum values by internal OID, so renaming a label
automatically "updates" all existing rows—no backfill UPDATE is required.

ALTER TYPE … RENAME VALUE is supported from PostgreSQL 10 (prod is PG 16).

Idempotency
-----------
Each rename is wrapped in a DO $$ block that checks pg_enum before acting,
so re-running the migration (e.g. after a partial failure) is safe.
"""

from alembic import op
import sqlalchemy as sa

revision = "e1f2a3b4c5d6"
down_revision = "d3e4f5a6b7c8"
branch_labels = None
depends_on = None


def _rename_if_exists(type_name: str, old_val: str, new_val: str) -> str:
    """Return a DO block that renames an enum label only if it currently exists."""
    return f"""
        DO $$ BEGIN
            IF EXISTS (
                SELECT 1
                FROM   pg_enum  e
                JOIN   pg_type  t ON e.enumtypid = t.oid
                WHERE  t.typname    = '{type_name}'
                  AND  e.enumlabel  = '{old_val}'
                  AND  t.typnamespace = (
                           SELECT oid FROM pg_namespace
                           WHERE  nspname = current_schema()
                       )
            ) THEN
                ALTER TYPE {type_name} RENAME VALUE '{old_val}' TO '{new_val}';
            END IF;
        END $$;
    """


def upgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "sqlite":
        # SQLite has no native enum types; no-op.
        return

    # ── userstatus ───────────────────────────────────────────────────────
    for old, new in [("ACTIVE", "active"), ("INACTIVE", "inactive"), ("LOCKED", "locked")]:
        op.execute(sa.text(_rename_if_exists("userstatus", old, new)))

    # ── projectstatus ────────────────────────────────────────────────────
    for old, new in [("ACTIVE", "active"), ("ARCHIVED", "archived")]:
        op.execute(sa.text(_rename_if_exists("projectstatus", old, new)))

    # ── catalogstatus ────────────────────────────────────────────────────
    for old, new in [
        ("DRAFT", "draft"),
        ("PUBLISHED", "published"),
        ("DEPRECATED", "deprecated"),
    ]:
        op.execute(sa.text(_rename_if_exists("catalogstatus", old, new)))

    # ── entitytype ───────────────────────────────────────────────────────
    for old, new in [("ACTIVITY", "activity"), ("EVENT", "event")]:
        op.execute(sa.text(_rename_if_exists("entitytype", old, new)))

    # ── widgettype ───────────────────────────────────────────────────────
    for w in [
        "TEXT", "NUMBER", "DATE", "TIME", "DATETIME", "TEXTAREA",
        "SELECT", "MULTISELECT", "RADIO", "CHECKBOX",
        "GPS", "SIGNATURE", "FILE", "PHOTO",
    ]:
        op.execute(sa.text(_rename_if_exists("widgettype", w, w.lower())))


def downgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "sqlite":
        return

    # Reverse: lowercase → uppercase

    # ── userstatus ───────────────────────────────────────────────────────
    for old, new in [("active", "ACTIVE"), ("inactive", "INACTIVE"), ("locked", "LOCKED")]:
        op.execute(sa.text(_rename_if_exists("userstatus", old, new)))

    # ── projectstatus ────────────────────────────────────────────────────
    for old, new in [("active", "ACTIVE"), ("archived", "ARCHIVED")]:
        op.execute(sa.text(_rename_if_exists("projectstatus", old, new)))

    # ── catalogstatus ────────────────────────────────────────────────────
    for old, new in [
        ("draft", "DRAFT"),
        ("published", "PUBLISHED"),
        ("deprecated", "DEPRECATED"),
    ]:
        op.execute(sa.text(_rename_if_exists("catalogstatus", old, new)))

    # ── entitytype ───────────────────────────────────────────────────────
    for old, new in [("activity", "ACTIVITY"), ("event", "EVENT")]:
        op.execute(sa.text(_rename_if_exists("entitytype", old, new)))

    # ── widgettype ───────────────────────────────────────────────────────
    for w in [
        "text", "number", "date", "time", "datetime", "textarea",
        "select", "multiselect", "radio", "checkbox",
        "gps", "signature", "file", "photo",
    ]:
        op.execute(sa.text(_rename_if_exists("widgettype", w, w.upper())))
