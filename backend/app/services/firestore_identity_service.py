"""Firestore-backed identity helpers for firestore-only runtime mode."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from app.core.firestore import get_firestore_client
from app.core.enums import UserStatus


@dataclass
class FirestoreUserPrincipal:
    id: UUID
    email: str
    full_name: str
    status: UserStatus
    created_at: datetime | None
    last_login_at: datetime | None
    roles: list[str]
    project_ids: list[str]
    first_name: str | None = None
    last_name: str | None = None
    second_last_name: str | None = None
    birth_date: str | None = None
    scopes: list[dict[str, str | None]] = field(default_factory=list)
    permission_scopes: list[dict[str, str | None]] = field(default_factory=list)
    password_hash: str | None = None
    pin_hash: str | None = None
    last_logout_at: datetime | None = None


def _normalize_permission_scopes(value: Any) -> list[dict[str, str | None]]:
    if not isinstance(value, list):
        return []

    result: list[dict[str, str | None]] = []
    for item in value:
        if not isinstance(item, dict):
            continue
        permission_code = str(item.get("permission_code") or "").strip()
        if not permission_code:
            continue
        project_raw = str(item.get("project_id") or "").strip().upper()
        effect = str(item.get("effect") or "allow").strip().lower()
        if effect not in {"allow", "deny"}:
            effect = "allow"
        result.append(
            {
                "permission_code": permission_code,
                "project_id": project_raw or None,
                "effect": effect,
            }
        )
    return result


def _normalize_role_scopes(value: Any) -> list[dict[str, str | None]]:
    if not isinstance(value, list):
        return []

    result: list[dict[str, str | None]] = []
    for item in value:
        if not isinstance(item, dict):
            continue
        role_name = str(item.get("role_name") or item.get("role") or "").strip().upper()
        if not role_name:
            continue
        project_raw = str(item.get("project_id") or "").strip().upper()
        result.append(
            {
                "role_name": role_name,
                "project_id": project_raw or None,
            }
        )
    return result


def _to_datetime(value: Any) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value)
        except ValueError:
            return None
    return None


def _normalize_status(value: Any) -> UserStatus:
    try:
        return UserStatus(str(value).lower())
    except Exception:
        return UserStatus.ACTIVE


def _principal_from_doc(payload: dict[str, Any]) -> FirestoreUserPrincipal | None:
    user_id_raw = payload.get("id")
    email = str(payload.get("email") or "").strip().lower()
    if not user_id_raw or not email:
        return None

    try:
        user_id = UUID(str(user_id_raw))
    except ValueError:
        return None

    roles_value = payload.get("roles") or []
    if isinstance(roles_value, list):
        roles = [str(item).strip().upper() for item in roles_value if str(item).strip()]
    else:
        roles = []

    project_ids_value = payload.get("project_ids") or []
    if isinstance(project_ids_value, list):
        project_ids = [str(item).strip() for item in project_ids_value if str(item).strip()]
    else:
        project_ids = []

    return FirestoreUserPrincipal(
        id=user_id,
        email=email,
        full_name=str(payload.get("full_name") or ""),
        status=_normalize_status(payload.get("status")),
        created_at=_to_datetime(payload.get("created_at")),
        last_login_at=_to_datetime(payload.get("last_login_at")),
        last_logout_at=_to_datetime(payload.get("last_logout_at")),
        roles=roles,
        project_ids=project_ids,
        first_name=str(payload.get("first_name") or "") or None,
        last_name=str(payload.get("last_name") or "") or None,
        second_last_name=str(payload.get("second_last_name") or "") or None,
        birth_date=str(payload.get("birth_date") or "") or None,
        scopes=_normalize_role_scopes(payload.get("scopes")),
        permission_scopes=_normalize_permission_scopes(payload.get("permission_scopes")),
        password_hash=str(payload.get("password_hash") or "") or None,
        pin_hash=str(payload.get("pin_hash") or "") or None,
    )


def get_firestore_user_by_id(user_id: str | UUID) -> FirestoreUserPrincipal | None:
    import logging
    logger = logging.getLogger(__name__)
    
    client = get_firestore_client()
    snap = client.collection("users").document(str(user_id)).get()
    if not snap.exists:
        logger.warning(f"User {user_id} not found in Firestore")
        return None
    
    payload = snap.to_dict() or {}
    logger.info(f"get_firestore_user_by_id({user_id}): email={payload.get('email')} roles={payload.get('roles')}")
    
    principal = _principal_from_doc(payload)
    if principal:
        logger.info(f"  → Principal created: {principal.full_name} roles={principal.roles}")
    return principal


def get_firestore_user_by_email(email: str) -> FirestoreUserPrincipal | None:
    client = get_firestore_client()
    normalized = email.strip().lower()
    docs = (
        client.collection("users")
        .where("email", "==", normalized)
        .limit(1)
        .stream()
    )
    for doc in docs:
        return _principal_from_doc(doc.to_dict() or {})
    return None


def update_last_login(user_id: UUID) -> None:
    client = get_firestore_client()
    client.collection("users").document(str(user_id)).set(
        {"last_login_at": datetime.now(timezone.utc).isoformat()}, merge=True
    )


def update_last_logout(user_id: UUID) -> None:
    client = get_firestore_client()
    client.collection("users").document(str(user_id)).set(
        {"last_logout_at": datetime.now(timezone.utc).isoformat()}, merge=True
    )


def _matches_requested_role(principal_roles: list[str], requested_role: str | None) -> bool:
    if requested_role is None or not requested_role.strip():
        return True

    normalized_roles = {str(role).strip().upper() for role in principal_roles if str(role).strip()}
    requested = requested_role.strip().upper()
    role_aliases: dict[str, set[str]] = {
        "OPERATIVO": {"OPERATIVO", "OPERARIO", "TECNICO", "T\u00c9CNICO"},
    }
    allowed = role_aliases.get(requested, {requested})
    return any(role in allowed for role in normalized_roles)


# ---------------------------------------------------------------------------
# User management (Firestore-only mode)
# ---------------------------------------------------------------------------

def list_firestore_users(role: str | None = None) -> list[FirestoreUserPrincipal]:
    """List all users from Firestore, optionally filtered by role."""
    client = get_firestore_client()
    docs = client.collection("users").stream()
    result: list[FirestoreUserPrincipal] = []
    for doc in docs:
        principal = _principal_from_doc(doc.to_dict() or {})
        if principal is None:
            continue
        if not _matches_requested_role(principal.roles, role):
            continue
        result.append(principal)
    result.sort(key=lambda u: u.full_name.lower())
    return result


def create_firestore_user(
    email: str,
    full_name: str,
    password_hash: str,
    roles: list[str],
    project_ids: list[str],
    first_name: str | None = None,
    last_name: str | None = None,
    second_last_name: str | None = None,
    birth_date: str | None = None,
    scopes: list[dict[str, str | None]] | None = None,
    permission_scopes: list[dict[str, str | None]] | None = None,
) -> FirestoreUserPrincipal:
    """Create a new user document in Firestore. Returns the created principal."""
    import uuid as _uuid_mod

    user_id = _uuid_mod.uuid4()
    now = datetime.now(timezone.utc).isoformat()
    payload: dict[str, Any] = {
        "id": str(user_id),
        "email": email.strip().lower(),
        "full_name": full_name.strip(),
        "password_hash": password_hash,
        "status": "active",
        "roles": [r.strip().upper() for r in roles],
        "project_ids": [p.strip().upper() for p in project_ids if p.strip()],
        "scopes": _normalize_role_scopes(scopes or []),
        "permission_scopes": permission_scopes or [],
        "created_at": now,
        "last_login_at": None,
        "pin_hash": None,
    }
    if first_name is not None:
        payload["first_name"] = first_name.strip()
    if last_name is not None:
        payload["last_name"] = last_name.strip()
    if second_last_name is not None:
        payload["second_last_name"] = second_last_name.strip()
    if birth_date is not None:
        payload["birth_date"] = birth_date
    client = get_firestore_client()
    client.collection("users").document(str(user_id)).set(payload)
    principal = _principal_from_doc(payload)
    if principal is None:
        raise RuntimeError("Failed to build principal from created user payload")
    return principal


def update_firestore_user(
    user_id: UUID,
    full_name: str | None = None,
    status: str | None = None,
    roles: list[str] | None = None,
    project_ids: list[str] | None = None,
    first_name: str | None = None,
    last_name: str | None = None,
    second_last_name: str | None = None,
    birth_date: str | None = None,
    scopes: list[dict[str, str | None]] | None = None,
    permission_scopes: list[dict[str, str | None]] | None = None,
) -> FirestoreUserPrincipal | None:
    """Update an existing user document in Firestore. Returns updated principal or None if not found."""
    client = get_firestore_client()
    ref = client.collection("users").document(str(user_id))
    snap = ref.get()
    if not snap.exists:
        return None

    updates: dict[str, Any] = {}
    if full_name is not None:
        updates["full_name"] = full_name.strip()
    if status is not None:
        updates["status"] = status.lower()
    if roles is not None:
        updates["roles"] = [r.strip().upper() for r in roles]
    if project_ids is not None:
        updates["project_ids"] = [p.strip().upper() for p in project_ids if p.strip()]
    if first_name is not None:
        updates["first_name"] = first_name.strip()
    if last_name is not None:
        updates["last_name"] = last_name.strip()
    if second_last_name is not None:
        updates["second_last_name"] = second_last_name.strip()
    if birth_date is not None:
        updates["birth_date"] = birth_date
    if scopes is not None:
        updates["scopes"] = _normalize_role_scopes(scopes)
    if permission_scopes is not None:
        updates["permission_scopes"] = permission_scopes

    if updates:
        ref.set(updates, merge=True)

    refreshed = ref.get()
    return _principal_from_doc(refreshed.to_dict() or {})


def delete_firestore_user(user_id: UUID) -> bool:
    """Delete an existing user document in Firestore. Returns True if deleted."""
    client = get_firestore_client()
    ref = client.collection("users").document(str(user_id))
    snap = ref.get()
    if not snap.exists:
        return False
    ref.delete()
    return True
