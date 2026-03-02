"""Drop all tables, run Alembic migrations from scratch, and seed data.

Use only when setting up a fresh production database where tables exist
from a legacy create_all() but alembic_version is not populated.
"""

import logging
from pathlib import Path

import sqlalchemy as sa
from alembic import command
from alembic.config import Config

from _script_utils import (
    add_repo_root_to_path,
    build_alembic_config,
    configure_logging,
    create_engine_from_env,
    run_common_seeds,
)


def _configure_logging() -> None:
    configure_logging()


def _get_engine() -> sa.Engine:
    return create_engine_from_env()


def _drop_all(engine: sa.Engine) -> None:
    logging.info("Dropping all tables and custom types via CASCADE")
    with engine.connect() as conn:
        conn.execute(sa.text("DROP SCHEMA public CASCADE"))
        conn.execute(sa.text("CREATE SCHEMA public"))
        conn.execute(sa.text("GRANT ALL ON SCHEMA public TO PUBLIC"))
        conn.commit()
    logging.info("Schema reset complete")


def _run_migrations(base_dir: Path) -> None:
    logging.info("Running Alembic migrations")
    cfg = build_alembic_config(base_dir)
    command.upgrade(cfg, "head")


def _run_seeds() -> None:
    run_common_seeds()


def main() -> int:
    _configure_logging()
    try:
        base_dir = add_repo_root_to_path()
        engine = _get_engine()
        _drop_all(engine)
        engine.dispose()
        _run_migrations(base_dir)
        _run_seeds()
    except Exception as exc:
        logging.exception("Reset/migrate failed: %s", exc)
        return 1

    logging.info("Database initialized successfully")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
