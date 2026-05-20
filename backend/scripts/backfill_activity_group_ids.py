"""
Backfill activity_group_id for legacy multi-responsible activities.

Activities created before activity_group_id was introduced have no group link.
This script identifies groups of activities that share the same:
  - project_id
  - activity_type_code
  - assignment_start_at
  - assignment_end_at
  - created_by_user_id
  - front_id
  - pk_start

If 2+ activities share all those fields (and lack activity_group_id), they are
assumed to be a legacy multi-responsible group and get the same new UUID.

Usage:
    cd backend/
    python scripts/backfill_activity_group_ids.py [--dry-run]

Set FIRESTORE_PROJECT_ID (and optionally GOOGLE_APPLICATION_CREDENTIALS) before running.
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
from collections import defaultdict
from pathlib import Path
from uuid import uuid4

# ── path setup ──────────────────────────────────────────────────────────────
_BASE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(_BASE))

from scripts._script_utils import configure_logging  # noqa: E402

configure_logging()
logger = logging.getLogger(__name__)


def _composite_key(doc: dict) -> str:
    """Return a deterministic composite key for a legacy multi-responsible group."""
    return "|".join([
        str(doc.get("project_id") or "").strip().upper(),
        str(doc.get("activity_type_code") or "").strip(),
        str(doc.get("assignment_start_at") or "").strip(),
        str(doc.get("assignment_end_at") or "").strip(),
        str(doc.get("created_by_user_id") or "").strip(),
        str(doc.get("front_id") or "").strip(),
        str(doc.get("pk_start") or "").strip(),
    ])


def run(dry_run: bool = False) -> None:
    project_id = os.environ.get("FIRESTORE_PROJECT_ID")
    if not project_id:
        raise SystemExit("FIRESTORE_PROJECT_ID env var is required.")

    from google.cloud import firestore  # type: ignore

    client = firestore.Client(project=project_id)

    logger.info("Fetching all activities from Firestore project=%s …", project_id)
    all_docs = list(client.collection("activities").stream())
    logger.info("Total activity documents fetched: %d", len(all_docs))

    # Separate legacy (no activity_group_id) from already-tagged.
    legacy: list[tuple[str, dict]] = []
    already_tagged = 0

    for snap in all_docs:
        data = snap.to_dict() or {}
        if data.get("deleted_at") is not None:
            continue
        gid = str(data.get("activity_group_id") or "").strip()
        if gid:
            already_tagged += 1
        else:
            legacy.append((snap.id, data))

    logger.info("Already tagged with activity_group_id: %d", already_tagged)
    logger.info("Legacy activities without activity_group_id: %d", len(legacy))

    # Group legacy activities by composite key.
    groups: dict[str, list[str]] = defaultdict(list)  # key -> [doc_id, ...]
    key_empty_count = 0

    for doc_id, data in legacy:
        key = _composite_key(data)
        if key.replace("|", "").strip():
            groups[key].append(doc_id)
        else:
            key_empty_count += 1

    # Only groups with >1 member need a new activity_group_id.
    multi_groups = {k: ids for k, ids in groups.items() if len(ids) > 1}

    logger.info("Composite key groups with >1 activity (legacy duplicates): %d", len(multi_groups))
    logger.info("Activities with empty composite key (skipped): %d", key_empty_count)

    if not multi_groups:
        logger.info("Nothing to backfill. All legacy activities appear to be single-responsible.")
        return

    total_docs_to_update = sum(len(ids) for ids in multi_groups.values())
    logger.info("Total documents to tag: %d  (dry_run=%s)", total_docs_to_update, dry_run)

    # Batch write
    updated = 0
    for key, doc_ids in multi_groups.items():
        new_gid = str(uuid4())
        logger.info(
            "Group key=%.80s … → activity_group_id=%s (%d docs)",
            key, new_gid, len(doc_ids),
        )
        for doc_id in doc_ids:
            if not dry_run:
                client.collection("activities").document(doc_id).update(
                    {"activity_group_id": new_gid}
                )
            updated += 1

    logger.info(
        "Done. %d documents %s.",
        updated,
        "would be updated (dry run)" if dry_run else "updated",
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be changed without writing to Firestore.",
    )
    args = parser.parse_args()
    run(dry_run=args.dry_run)
