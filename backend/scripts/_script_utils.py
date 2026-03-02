"""Shared utilities for backend maintenance scripts."""

from __future__ import annotations

import logging
import os
import sys
from pathlib import Path

import sqlalchemy as sa
from alembic.config import Config


def configure_logging() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")


def get_database_url() -> str:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL environment variable is not set")
    return database_url


def get_base_dir() -> Path:
    return Path(__file__).resolve().parents[1]


def add_repo_root_to_path(base_dir: Path | None = None) -> Path:
    resolved_base_dir = base_dir or get_base_dir()
    path_value = str(resolved_base_dir)
    if path_value not in sys.path:
        sys.path.insert(0, path_value)
    return resolved_base_dir


def create_engine_from_env() -> sa.Engine:
    return sa.create_engine(get_database_url())


def build_alembic_config(base_dir: Path) -> Config:
    alembic_config = Config(str(base_dir / "alembic.ini"))
    alembic_config.set_main_option("script_location", str(base_dir / "alembic"))
    return alembic_config


def run_common_seeds() -> None:
    from app.core.database import SessionLocal
    from app.seeds.catalog_tmq_v1 import seed_catalog_tmq_v1
    from app.seeds.initial_data import run_all_seeds

    logging.info("Running seeds")
    db = SessionLocal()
    try:
        run_all_seeds(db)
        seed_catalog_tmq_v1(db)
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()