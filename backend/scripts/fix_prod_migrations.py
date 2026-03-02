"""Fix production database migration state.

Modes
-----
--mode upgrade   (default)
    Runs `alembic upgrade head`.  Safe when the DB has tables (even partial).
    All pending migrations are idempotent.  Use this in the common case where
    b7a1b6c8d9e0 failed previously and e1f2a3b4c5d6 was never applied.

--mode reset
    Drops the entire public schema and rebuilds from scratch (alembic upgrade
    head + seeds).  Use ONLY when the DB is confirmed empty (no real data).
    Prompts for confirmation unless --force is passed.

Usage (from backend/ directory):
    DATABASE_URL="postgresql://..." python scripts/fix_prod_migrations.py
    DATABASE_URL="postgresql://..." python scripts/fix_prod_migrations.py --mode reset --force

Cloud Run one-off job (upgrade mode):
    gcloud run jobs create sao-fix-migrations \\
        --image gcr.io/PROJECT/sao-api \\
        --command python \\
        --args "scripts/fix_prod_migrations.py,--mode,upgrade" \\
        --set-secrets DATABASE_URL=DATABASE_URL:latest \\
        --add-cloudsql-instances PROJECT:REGION:INSTANCE \\
        --execute-now
"""

import argparse
import logging
from pathlib import Path

import sqlalchemy as sa
from alembic import command

from _script_utils import (
    add_repo_root_to_path,
    build_alembic_config,
    configure_logging,
    create_engine_from_env,
    run_common_seeds,
)

EXPECTED_HEAD = "e1f2a3b4c5d6"


def _configure_logging() -> None:
    configure_logging()


def _get_engine() -> sa.Engine:
    return create_engine_from_env()


def _get_current_version(engine: sa.Engine) -> str | None:
    """Return current alembic version, or None if table absent/empty."""
    try:
        with engine.connect() as conn:
            rows = conn.execute(
                sa.text("SELECT version_num FROM alembic_version")
            ).fetchall()
            return rows[0][0] if rows else None
    except Exception:
        return None


def _count_users(engine: sa.Engine) -> int:
    try:
        with engine.connect() as conn:
            return conn.execute(sa.text("SELECT count(*) FROM users")).scalar() or 0
    except Exception:
        return 0


def _run_upgrade(base_dir: Path) -> None:
    logging.info("Running: alembic upgrade head")
    cfg = build_alembic_config(base_dir)
    command.upgrade(cfg, "head")
    logging.info("alembic upgrade head — complete")


def _run_seeds() -> None:
    run_common_seeds()
    logging.info("Seeds complete")


def _reset_schema(engine: sa.Engine) -> None:
    logging.info("Dropping public schema and recreating (CASCADE)")
    with engine.connect() as conn:
        conn.execute(sa.text("DROP SCHEMA public CASCADE"))
        conn.execute(sa.text("CREATE SCHEMA public"))
        conn.execute(sa.text("GRANT ALL ON SCHEMA public TO PUBLIC"))
        conn.commit()
    logging.info("Schema reset complete")


def do_upgrade(base_dir: Path, engine: sa.Engine) -> int:
    current = _get_current_version(engine)
    logging.info("Current alembic_version: %s", current or "(none)")

    if current == EXPECTED_HEAD:
        logging.info("DB is already at head (%s). Nothing to do.", EXPECTED_HEAD)
        return 0

    if current is None:
        user_count = _count_users(engine)
        if user_count > 0:
            logging.error(
                "alembic_version is missing but users table has %d rows. "
                "This is an ambiguous state. Run diagnose_prod_db.py first, "
                "then choose --mode reset (if data is expendable) or "
                "manually stamp with: alembic stamp <revision>",
                user_count,
            )
            return 1
        logging.warning(
            "No alembic_version found and users table is empty. "
            "Proceeding with upgrade from scratch."
        )

    _run_upgrade(base_dir)

    # Verify
    new_version = _get_current_version(engine)
    if new_version != EXPECTED_HEAD:
        logging.error(
            "After upgrade, version is %s but expected %s. "
            "Some migrations may have failed — check output above.",
            new_version,
            EXPECTED_HEAD,
        )
        return 1

    logging.info("✅  DB is now at head: %s", new_version)
    return 0


def do_reset(base_dir: Path, engine: sa.Engine, force: bool) -> int:
    user_count = _count_users(engine)
    if user_count > 0 and not force:
        print(
            f"\n⚠️  WARNING: users table has {user_count} row(s).\n"
            "  --mode reset will DROP ALL DATA.\n"
            "  Re-run with --force to confirm, or use --mode upgrade instead.\n"
        )
        return 1

    if user_count > 0:
        logging.warning("--force specified: dropping DB with %d existing user(s)", user_count)

    _reset_schema(engine)
    engine.dispose()
    _run_upgrade(base_dir)
    _run_seeds()

    new_version = _get_current_version(engine)
    logging.info("✅  DB reset complete. Version: %s", new_version)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Fix SAO production DB migrations")
    parser.add_argument(
        "--mode",
        choices=["upgrade", "reset"],
        default="upgrade",
        help="upgrade: run alembic upgrade head (default). reset: wipe and rebuild.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Skip confirmation prompt for --mode reset when data exists.",
    )
    args = parser.parse_args()

    _configure_logging()

    base_dir = add_repo_root_to_path()

    engine = _get_engine()

    logging.info("Mode: %s | Head target: %s", args.mode, EXPECTED_HEAD)

    try:
        if args.mode == "reset":
            return do_reset(base_dir, engine, args.force)
        else:
            return do_upgrade(base_dir, engine)
    except Exception as exc:
        logging.exception("fix_prod_migrations failed: %s", exc)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
