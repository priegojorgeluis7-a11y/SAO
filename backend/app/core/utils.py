"""Shared backend utility functions."""

from datetime import datetime, timezone


def parse_firestore_dt(value: object) -> datetime | None:
    """Convert a Firestore datetime, ISO string, or None to a tz-aware datetime.

    Consolidates `_coerce_firestore_datetime` (sync.py), `_to_dt` (assignments.py),
    and `_parse_dt` (reports.py) into a single canonical implementation.
    """
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if isinstance(value, str):
        raw = value.strip()
        if not raw:
            return None
        if raw.endswith("Z"):
            raw = raw[:-1] + "+00:00"
        try:
            parsed = datetime.fromisoformat(raw)
            return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
        except ValueError:
            return None
    return None
