"""Shared utilities for backend maintenance scripts."""

from __future__ import annotations

import logging
import sys
from pathlib import Path


def configure_logging() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")


def get_base_dir() -> Path:
    return Path(__file__).resolve().parents[1]


def add_repo_root_to_path(base_dir: Path | None = None) -> Path:
    resolved_base_dir = base_dir or get_base_dir()
    path_value = str(resolved_base_dir)
    if path_value not in sys.path:
        sys.path.insert(0, path_value)
    return resolved_base_dir


def _retired_sql_helper(name: str) -> None:
    raise RuntimeError(
        f"{name} is retired in firestore-only mode. "
        "Do not use SQL/Alembic maintenance helpers."
    )


def get_database_url() -> str:
    _retired_sql_helper("get_database_url")
    return ""


def create_engine_from_env():
    _retired_sql_helper("create_engine_from_env")
    return None


def build_alembic_config(_base_dir: Path):
    _retired_sql_helper("build_alembic_config")
    return None


def run_common_seeds() -> None:
    _retired_sql_helper("run_common_seeds")