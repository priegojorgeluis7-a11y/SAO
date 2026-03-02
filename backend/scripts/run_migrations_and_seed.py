"""Run database migrations and seed data in a single step."""

import logging
from pathlib import Path

from alembic import command

from _script_utils import (
    add_repo_root_to_path,
    build_alembic_config,
    configure_logging,
    get_database_url,
    run_common_seeds,
)


def _configure_logging() -> None:
    configure_logging()


def _ensure_database_url() -> str:
    return get_database_url()


def _run_migrations(base_dir: Path) -> None:
    logging.info("Running Alembic migrations")
    alembic_cfg = build_alembic_config(base_dir)
    command.upgrade(alembic_cfg, "head")


def _run_seeds() -> None:
    logging.info("Running seed routines")
    run_common_seeds()


def main() -> int:
    _configure_logging()
    try:
        _ensure_database_url()
        base_dir = add_repo_root_to_path()
        _run_migrations(base_dir)
        _run_seeds()
    except Exception as exc:
        logging.exception("Migration/seed failed: %s", exc)
        return 1

    logging.info("Migrations and seeds completed successfully")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
