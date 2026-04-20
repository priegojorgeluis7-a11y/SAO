"""Role permission settings persisted in Firestore with safe defaults."""

from __future__ import annotations

import logging
from functools import lru_cache

from google.cloud import firestore

from app.core.firestore import get_firestore_client
from app.core.permission_catalog import (
    CANONICAL_PERMISSION_CODES,
    DEFAULT_ROLE_PERMISSION_CODES,
)

logger = logging.getLogger(__name__)

_SETTINGS_COLLECTION = "system_settings"
_ROLE_PERMISSIONS_DOC = "role_permissions"
_ROLE_PERMISSIONS_FIELD = "role_permissions"


def _default_role_permission_map() -> dict[str, list[str]]:
    return {
        role: list(permission_codes)
        for role, permission_codes in DEFAULT_ROLE_PERMISSION_CODES.items()
    }


def _normalize_role_permissions(raw: object) -> dict[str, list[str]]:
    defaults = _default_role_permission_map()
    if not isinstance(raw, dict):
        return defaults

    allowed_permissions = set(CANONICAL_PERMISSION_CODES)
    normalized: dict[str, list[str]] = {}

    for role, default_codes in defaults.items():
        raw_codes = raw.get(role)
        if not isinstance(raw_codes, list):
            normalized[role] = list(default_codes)
            continue

        sanitized_codes: list[str] = []
        for item in raw_codes:
            code = str(item).strip()
            if code and code in allowed_permissions and code not in sanitized_codes:
                sanitized_codes.append(code)
        normalized[role] = sanitized_codes

    # Keep ADMIN as full access to avoid locking the platform out of recovery.
    normalized["ADMIN"] = list(CANONICAL_PERMISSION_CODES)
    return normalized


def _unique_keep_order(values: list[str]) -> list[str]:
    return list(dict.fromkeys([value for value in values if value]))


def merge_role_permission_codes(
    roles: list[str] | None,
    permission_scopes: list[dict[str, str | None]] | None,
    role_permissions_map: dict[str, list[str]] | None = None,
) -> list[str]:
    resolved_role_permissions = role_permissions_map or get_role_permission_map()
    role_permission_codes: list[str] = []
    for role_name in roles or []:
        role_permission_codes.extend(
            resolved_role_permissions.get(str(role_name).strip().upper(), [])
        )

    direct_scopes = permission_scopes or []
    allow_codes = {
        str(item.get("permission_code") or "").strip()
        for item in direct_scopes
        if str(item.get("effect") or "allow").strip().lower() == "allow"
        and item.get("project_id") is None
    }
    deny_codes = {
        str(item.get("permission_code") or "").strip()
        for item in direct_scopes
        if str(item.get("effect") or "allow").strip().lower() == "deny"
        and item.get("project_id") is None
    }
    merged = _unique_keep_order(role_permission_codes + list(allow_codes))
    return [code for code in merged if code and code not in deny_codes]


@lru_cache(maxsize=1)
def _cached_role_permission_pairs() -> tuple[tuple[str, tuple[str, ...]], ...]:
    defaults = _default_role_permission_map()
    try:
        snapshot = (
            get_firestore_client()
            .collection(_SETTINGS_COLLECTION)
            .document(_ROLE_PERMISSIONS_DOC)
            .get()
        )
        if not snapshot.exists:
            return tuple((role, tuple(codes)) for role, codes in defaults.items())

        payload = snapshot.to_dict() or {}
        raw_permissions = payload.get(_ROLE_PERMISSIONS_FIELD, payload)
        normalized = _normalize_role_permissions(raw_permissions)
        return tuple(
            (role, tuple(normalized.get(role, defaults[role])))
            for role in defaults.keys()
        )
    except Exception:
        logger.warning(
            "ROLE_PERMISSION_SETTINGS_FALLBACK_TO_DEFAULTS",
            exc_info=True,
        )
        return tuple((role, tuple(codes)) for role, codes in defaults.items())


def get_role_permission_map() -> dict[str, list[str]]:
    return {
        role: list(permission_codes)
        for role, permission_codes in _cached_role_permission_pairs()
    }


def save_role_permission_map(role_permissions: dict[str, list[str]]) -> dict[str, list[str]]:
    normalized = _normalize_role_permissions(role_permissions)
    get_firestore_client().collection(_SETTINGS_COLLECTION).document(
        _ROLE_PERMISSIONS_DOC,
    ).set(
        {
            _ROLE_PERMISSIONS_FIELD: normalized,
            "updated_at": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )
    _cached_role_permission_pairs.cache_clear()
    return normalized
