"""Backfill existing PostgreSQL activities to Firestore.

Reads all non-deleted activities from Postgres and upserts them into the
Firestore ``activities`` collection using the same payload structure that
ActivityService uses during dual-write.

Usage (PowerShell):
  $env:DATABASE_URL = "postgresql+psycopg2://..."
  $env:FIRESTORE_PROJECT_ID = "sao-prod-488416"
  python backend/scripts/backfill_activities_to_firestore.py

Optional flags:
  --project-id TMQ      Filter by project (default: all projects)
  --dry-run             Print what would be written without writing
  --batch-size 100      Firestore batch write size (max 500)
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
from pathlib import Path

import sqlalchemy as sa
from google.cloud import firestore
from sqlalchemy.orm import Session, sessionmaker

# Allow imports from backend root
_BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(_BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(_BACKEND_DIR))

from _script_utils import configure_logging, get_database_url  # noqa: E402


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Backfill activities to Firestore")
    parser.add_argument("--project-id", default="", help="Filter by project ID (empty = all)")
    parser.add_argument("--dry-run", action="store_true", help="Print without writing to Firestore")
    parser.add_argument("--batch-size", type=int, default=100, help="Firestore batch size (max 500)")
    parser.add_argument("--include-deleted", action="store_true", help="Also backfill soft-deleted records")
    return parser.parse_args()


def _get_firestore_client() -> firestore.Client:
    project_id = os.getenv("FIRESTORE_PROJECT_ID", "").strip()
    database = os.getenv("FIRESTORE_DATABASE", "(default)").strip() or "(default)"
    if not project_id:
        raise RuntimeError("FIRESTORE_PROJECT_ID is required")
    return firestore.Client(project=project_id, database=database)


def _build_payload(row: dict) -> dict:
    """Build Firestore document payload from a raw activity row."""
    def _str_or_none(val: object) -> str | None:
        return str(val) if val is not None else None

    return {
        "uuid": str(row["uuid"]),
        "server_id": row["id"],
        "project_id": row["project_id"],
        "front_id": _str_or_none(row.get("front_id")),
        "pk_start": row.get("pk_start"),
        "pk_end": row.get("pk_end"),
        "execution_state": row.get("execution_state"),
        "assigned_to_user_id": _str_or_none(row.get("assigned_to_user_id")),
        "created_by_user_id": str(row["created_by_user_id"]),
        "catalog_version_id": _str_or_none(row.get("catalog_version_id")),
        "activity_type_code": row.get("activity_type_code"),
        "latitude": row.get("latitude"),
        "longitude": row.get("longitude"),
        "title": row.get("title"),
        "description": row.get("description"),
        "gps_mismatch": bool(row.get("gps_mismatch", False)),
        "catalog_changed": bool(row.get("catalog_changed", False)),
        "created_at": row.get("created_at"),
        "updated_at": row.get("updated_at"),
        "deleted_at": row.get("deleted_at"),
        "sync_version": int(row.get("sync_version") or 0),
    }


def _load_activities(db: Session, project_id: str, include_deleted: bool) -> list[dict]:
    inspector = sa.inspect(db.bind)
    available = {col["name"] for col in inspector.get_columns("activities")}

    cols = [
        "id", "uuid", "project_id", "front_id", "pk_start", "pk_end",
        "execution_state", "assigned_to_user_id", "created_by_user_id",
        "catalog_version_id", "activity_type_code", "latitude", "longitude",
        "title", "description", "gps_mismatch", "catalog_changed",
        "created_at", "updated_at", "deleted_at", "sync_version",
    ]
    selected = [c for c in cols if c in available]

    conditions = []
    params: dict = {}
    if project_id:
        conditions.append("project_id = :project_id")
        params["project_id"] = project_id
    if not include_deleted:
        conditions.append("deleted_at IS NULL")

    where = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    sql = sa.text(f"SELECT {', '.join(selected)} FROM activities {where} ORDER BY updated_at ASC")
    rows = db.execute(sql, params).mappings().all()
    return [dict(r) for r in rows]


def _write_batch(
    client: firestore.Client,
    payloads: list[dict],
    dry_run: bool,
) -> int:
    if dry_run:
        for p in payloads:
            logging.info("[dry-run] would write activity uuid=%s", p["uuid"])
        return len(payloads)

    batch = client.batch()
    for p in payloads:
        ref = client.collection("activities").document(p["uuid"])
        batch.set(ref, p, merge=True)
    batch.commit()
    return len(payloads)


def main() -> int:
    configure_logging()
    args = _parse_args()

    engine = sa.create_engine(get_database_url(), pool_pre_ping=True, future=True)
    SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False, class_=Session)

    with SessionLocal() as db:
        rows = _load_activities(db, args.project_id, args.include_deleted)

    total_pg = len(rows)
    logging.info("Found %d activities in PostgreSQL (project_id=%r)", total_pg, args.project_id or "ALL")

    if total_pg == 0:
        logging.info("Nothing to backfill.")
        return 0

    if args.dry_run:
        logging.info("Dry-run mode — no writes will be made.")

    client: firestore.Client | None = None
    if not args.dry_run:
        client = _get_firestore_client()

    written = 0
    batch_size = max(1, min(args.batch_size, 500))

    for start in range(0, total_pg, batch_size):
        chunk = rows[start : start + batch_size]
        payloads = [_build_payload(r) for r in chunk]
        count = _write_batch(client, payloads, args.dry_run)  # type: ignore[arg-type]
        written += count
        logging.info("Progress: %d/%d", written, total_pg)

    logging.info(
        "Backfill complete: %d/%d activities written to Firestore%s.",
        written,
        total_pg,
        " (dry-run)" if args.dry_run else "",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
