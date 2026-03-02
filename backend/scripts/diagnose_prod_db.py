"""Diagnose production database state.

Checks:
  - alembic_version table and current revision
  - PostgreSQL enum labels (are they uppercase or lowercase?)
  - Column types for activities.uuid and evidences.activity_id
  - Row counts for key tables
  - Prints a recommended action based on findings

Usage (from backend/ directory):
    DATABASE_URL="postgresql://..." python scripts/diagnose_prod_db.py

Cloud Run one-off job:
    gcloud run jobs create sao-diagnose \\
        --image gcr.io/PROJECT/sao-api \\
        --command python --args scripts/diagnose_prod_db.py \\
        --set-secrets DATABASE_URL=DATABASE_URL:latest \\
        --add-cloudsql-instances PROJECT:REGION:INSTANCE \\
        --execute-now
"""

import logging
import os
import sys
from pathlib import Path

import sqlalchemy as sa

# ── expected migration chain (newest last) ─────────────────────────────────
EXPECTED_HEAD = "e1f2a3b4c5d6"
MIGRATION_CHAIN = [
    "2943c465af13",
    "894874841371",
    "5fd505b2d50b",
    "6afdfb767b40",
    "c4e9d2a1b7f0",
    "b7a1b6c8d9e0",
    "d3e4f5a6b7c8",
    "e1f2a3b4c5d6",
]


def _row(label: str, value: object) -> None:
    print(f"  {label:<40} {value}")


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s  %(message)s")

    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        logging.error("DATABASE_URL environment variable is not set")
        return 1

    engine = sa.create_engine(db_url)
    issues: list[str] = []
    applied_version: str | None = None

    print("\n" + "=" * 60)
    print("SAO — Production DB Diagnostic")
    print("=" * 60)

    with engine.connect() as conn:

        # ── 1. alembic_version ────────────────────────────────────────
        print("\n[1] Alembic version")
        try:
            rows = conn.execute(sa.text("SELECT version_num FROM alembic_version")).fetchall()
            if rows:
                applied_version = rows[0][0]
                _row("version_num:", applied_version)
                if applied_version == EXPECTED_HEAD:
                    _row("Status:", "✅  UP TO DATE")
                elif applied_version in MIGRATION_CHAIN:
                    idx = MIGRATION_CHAIN.index(applied_version)
                    pending = MIGRATION_CHAIN[idx + 1:]
                    _row("Status:", f"⚠️  BEHIND HEAD — {len(pending)} migration(s) pending")
                    _row("Pending:", " → ".join(pending))
                    issues.append("MIGRATIONS_PENDING")
                else:
                    _row("Status:", "❓  Unknown revision — manual inspection needed")
                    issues.append("UNKNOWN_REVISION")
            else:
                _row("version_num:", "(table exists but empty)")
                issues.append("ALEMBIC_VERSION_EMPTY")
        except Exception as exc:
            _row("alembic_version table:", f"NOT FOUND ({exc})")
            issues.append("NO_ALEMBIC_VERSION_TABLE")

        # ── 2. Enum labels ────────────────────────────────────────────
        print("\n[2] PostgreSQL enum labels")
        for type_name in ("userstatus", "projectstatus", "catalogstatus", "entitytype", "widgettype"):
            try:
                result = conn.execute(sa.text("""
                    SELECT e.enumlabel
                    FROM   pg_enum  e
                    JOIN   pg_type  t ON e.enumtypid = t.oid
                    WHERE  t.typname = :tname
                    ORDER  BY e.enumsortorder
                """), {"tname": type_name})
                labels = [r[0] for r in result]
                has_upper = any(v != v.lower() for v in labels)
                flag = "❌  UPPERCASE — FIX NEEDED" if has_upper else "✅  lowercase"
                _row(f"  {type_name}:", f"{labels}  {flag}")
                if has_upper:
                    issues.append(f"ENUM_UPPERCASE:{type_name}")
            except Exception as exc:
                _row(f"  {type_name}:", f"type not found ({exc})")

        # ── 3. Column types ───────────────────────────────────────────
        print("\n[3] Column types (UUID migration check)")
        for table, col in [("activities", "uuid"), ("evidences", "activity_id")]:
            try:
                result = conn.execute(sa.text("""
                    SELECT data_type
                    FROM   information_schema.columns
                    WHERE  table_name  = :t
                      AND  column_name = :c
                """), {"t": table, "c": col})
                row = result.fetchone()
                if row:
                    dtype = row[0]
                    ok = dtype.lower() in ("uuid",)
                    flag = "✅" if ok else f"❌  expected uuid, got {dtype} — b7a1b6c8d9e0 not applied"
                    _row(f"  {table}.{col}:", f"{dtype}  {flag}")
                    if not ok:
                        issues.append(f"UUID_NOT_MIGRATED:{table}.{col}")
                else:
                    _row(f"  {table}.{col}:", "column not found (table may not exist)")
            except Exception as exc:
                _row(f"  {table}.{col}:", f"error: {exc}")

        # ── 4. Row counts ─────────────────────────────────────────────
        print("\n[4] Row counts")
        for table in ("users", "roles", "projects", "activities", "evidences",
                      "catalog_version", "cat_activities"):
            try:
                count = conn.execute(sa.text(f"SELECT count(*) FROM {table}")).scalar()
                _row(f"  {table}:", count)
            except Exception:
                _row(f"  {table}:", "table does not exist")

    # ── Summary & recommendation ──────────────────────────────────────────
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)

    if not issues:
        print("\n✅  No issues detected. DB schema is healthy.\n")
        return 0

    print(f"\n⚠️  Issues detected: {issues}\n")

    if "NO_ALEMBIC_VERSION_TABLE" in issues or "ALEMBIC_VERSION_EMPTY" in issues:
        print("RECOMMENDED ACTION — Case A (empty / untracked DB):")
        print("  python scripts/fix_prod_migrations.py --mode reset")
        print("  This drops all tables and rebuilds from scratch (safe only if DB has no real data).")

    elif "MIGRATIONS_PENDING" in issues or any("UUID_NOT_MIGRATED" in i for i in issues) or any("ENUM_UPPERCASE" in i for i in issues):
        print("RECOMMENDED ACTION — Case B (partial migrations):")
        print("  python scripts/fix_prod_migrations.py --mode upgrade")
        print("  OR: redeploy the Cloud Run image — it runs 'alembic upgrade head' automatically.")
        print(f"\n  Current version: {applied_version}")
        print(f"  Target  version: {EXPECTED_HEAD}")
        print(f"\n  NOTE: all pending migrations are idempotent and safe to re-run.")

    print()
    return 1


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    raise SystemExit(main())
