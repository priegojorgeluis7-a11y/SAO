"""Helpers to minimize sensitive data exposure in audit responses."""

from __future__ import annotations

import json
from typing import Any

_REDACTED_VALUE = "[REDACTED]"
_SENSITIVE_KEYS = {
    "access_token",
    "comment",
    "current_password",
    "description",
    "details",
    "extracted_fields",
    "invite_code",
    "invite_id",
    "message",
    "new_password",
    "password",
    "password_hash",
    "pin",
    "pin_hash",
    "preview",
    "reason",
    "refresh_token",
    "review_comment",
    "reviewed_text",
    "text",
    "token",
}


def _sanitize_value(value: Any, *, key: str | None = None) -> Any:
    normalized_key = str(key or "").strip().lower()
    if normalized_key in _SENSITIVE_KEYS:
        return _REDACTED_VALUE

    if isinstance(value, dict):
        return {
            str(child_key): _sanitize_value(child_value, key=str(child_key))
            for child_key, child_value in value.items()
        }
    if isinstance(value, list):
        return [_sanitize_value(item) for item in value]
    return value


def sanitize_audit_details(raw_details: Any) -> dict[str, Any] | None:
    if raw_details in (None, ""):
        return None

    parsed = raw_details
    if isinstance(raw_details, str):
        try:
            parsed = json.loads(raw_details)
        except ValueError:
            return {"value": _REDACTED_VALUE}

    sanitized = _sanitize_value(parsed)
    if isinstance(sanitized, dict):
        return sanitized
    return {"value": sanitized}


def sanitize_audit_details_json(raw_details: Any) -> str | None:
    sanitized = sanitize_audit_details(raw_details)
    if sanitized is None:
        return None
    return json.dumps(sanitized, ensure_ascii=True)