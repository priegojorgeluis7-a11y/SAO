import json
import logging
from datetime import datetime, timezone
from typing import Any
from uuid import UUID, uuid4

from app.core.firestore import get_firestore_client


logger = logging.getLogger(__name__)


def canonicalize_role_name(role: Any | None) -> str | None:
    raw = str(role or "").strip()
    if not raw:
        return None

    normalized = (
        raw.upper()
        .replace("Á", "A")
        .replace("É", "E")
        .replace("Í", "I")
        .replace("Ó", "O")
        .replace("Ú", "U")
    )

    if normalized in {"ADMIN", "ADMINISTRADOR"}:
        return "ADMIN"
    if normalized in {"COORD", "COORDINADOR", "COORDINATOR"}:
        return "COORD"
    if normalized in {"SUPERVISOR"}:
        return "SUPERVISOR"
    if normalized in {"LECTOR", "LECTURA", "VIEWER", "CONSULTA"}:
        return "LECTOR"
    if normalized in {
        "OPERATIVO",
        "OPERARIO",
        "OPERADOR",
        "TECNICO",
        "INGENIERO",
        "ING",
        "TOPOGRAFO",
    }:
        return "OPERATIVO"
    return normalized


def _normalize_actor_roles(actor: Any | None) -> list[str]:
    raw_roles = getattr(actor, "roles", []) if actor is not None else []
    if isinstance(raw_roles, str):
        raw_roles = [raw_roles]
    if not isinstance(raw_roles, list):
        return []

    normalized_roles: list[str] = []
    for role in raw_roles:
        canonical = canonicalize_role_name(role)
        if canonical and canonical not in normalized_roles:
            normalized_roles.append(canonical)
    return normalized_roles


def _json_safe(value: Any) -> Any:
    if isinstance(value, dict):
        return {str(key): _json_safe(item) for key, item in value.items()}
    if isinstance(value, (list, tuple, set)):
        return [_json_safe(item) for item in value]
    if isinstance(value, datetime):
        return value.astimezone(timezone.utc).isoformat()
    if isinstance(value, UUID):
        return str(value)
    return value


def write_firestore_audit_log(
    *,
    action: str,
    entity: str | None = None,
    entity_id: str | None = None,
    actor: Any | None = None,
    details: Any | None = None,
    **legacy_kwargs: Any,
) -> None:
    """Write an audit log entry directly to Firestore (Firestore-only path).

    Supports the current signature and legacy callers that still pass
    resource_type/resource_id/user_id/project_id/changes.
    """
    try:
        actor_id = str(
            getattr(actor, "id", "") or legacy_kwargs.get("user_id") or ""
        ).strip()
        actor_email = str(
            getattr(actor, "email", "") or legacy_kwargs.get("actor_email") or ""
        ).strip().lower()
        actor_name = str(
            getattr(actor, "full_name", "")
            or getattr(actor, "name", "")
            or legacy_kwargs.get("actor_name")
            or ""
        ).strip()
        actor_roles = _normalize_actor_roles(actor)
        if not actor_roles and legacy_kwargs.get("actor_role"):
            canonical_legacy_role = canonicalize_role_name(legacy_kwargs.get("actor_role"))
            actor_roles = [canonical_legacy_role] if canonical_legacy_role else []
        actor_role = actor_roles[0] if actor_roles else None

        merged_details: dict[str, Any] = {}
        if isinstance(details, dict):
            merged_details.update(details)
        elif details not in (None, ""):
            merged_details["message"] = str(details)

        legacy_changes = legacy_kwargs.get("changes")
        if isinstance(legacy_changes, dict):
            merged_details.update(legacy_changes)

        legacy_detail_text = legacy_kwargs.get("details")
        if legacy_detail_text not in (None, "") and "message" not in merged_details:
            merged_details["message"] = str(legacy_detail_text)

        project_id = str(legacy_kwargs.get("project_id") or "").strip().upper()
        if project_id and "project_id" not in merged_details:
            merged_details["project_id"] = project_id

        doc = {
            "id": str(uuid4()),
            "created_at": datetime.now(timezone.utc),
            "actor_id": actor_id or None,
            "actor_email": actor_email or None,
            "actor_name": actor_name or None,
            "actor_role": actor_role,
            "actor_roles": actor_roles,
            "action": str(action or "").strip().upper(),
            "entity": str(entity or legacy_kwargs.get("resource_type") or "unknown").strip().lower(),
            "entity_id": str(entity_id or legacy_kwargs.get("resource_id") or "").strip(),
            "details_json": json.dumps(_json_safe(merged_details), ensure_ascii=False),
        }
        get_firestore_client().collection("audit_logs").document(doc["id"]).set(doc)
    except Exception:
        logger.warning(
            "write_firestore_audit_log failed action=%s entity=%s entity_id=%s",
            action,
            entity,
            entity_id,
            exc_info=True,
        )
