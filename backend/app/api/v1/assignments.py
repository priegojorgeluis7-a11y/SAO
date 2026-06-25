import logging
import re
from datetime import datetime, timedelta, timezone
from uuid import UUID
from uuid import uuid4

from google.cloud.firestore_v1 import Increment as _FSIncrement

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from app.core.api_errors import api_error

from app.api.deps import get_current_user, require_any_role, resolve_user_project_access, user_has_any_role
from app.core.config import settings
from app.core.firestore import get_firestore_client
from typing import Any
from app.core.enums import UserStatus
from app.services.audit_service import canonicalize_role_name, write_firestore_audit_log
from app.services.firestore_identity_service import get_firestore_user_by_id, list_firestore_users
from app.services.push_notification_service import notify_new_assignment
from app.services.notification_service import (
    create_user_notification,
    update_notification_response,
)
from app.core.utils import parse_firestore_dt
from app.schemas.assignment import (
    AssignmentAssigneeOption,
    AssignmentCancelRequest,
    AssignmentCancelResponse,
    AssignmentCreate,
    AssignmentListItem,
    AssignmentTransferRequest,
)

router = APIRouter(prefix="/assignments", tags=["assignments"])
logger = logging.getLogger(__name__)


def _safe_float(v: object) -> float | None:
    if v is None:
        return None
    try:
        return float(v)
    except (ValueError, TypeError):
        return None


def _extract_scope_from_text(*values: str | None) -> tuple[str, str]:
    merged = " | ".join([(value or "").strip() for value in values if (value or "").strip()])
    if not merged:
        return "", ""
    estado_match = re.search(r"estado\s*:\s*([^|Â·;,]+)", merged, flags=re.IGNORECASE)
    municipio_match = re.search(r"municipio\s*:\s*([^|Â·;,]+)", merged, flags=re.IGNORECASE)
    estado = (estado_match.group(1) if estado_match else "").strip()
    municipio = (municipio_match.group(1) if municipio_match else "").strip()
    return estado, municipio


def _safe_uuid_str(value: object) -> str:
    raw = str(value or "").strip()
    if not raw:
        return ""
    try:
        return str(UUID(raw))
    except (ValueError, TypeError):
        return ""


def _to_dt(value: object) -> datetime:
    result = parse_firestore_dt(value)
    return result if result is not None else datetime.now(timezone.utc)


def _assignment_window(payload: dict[str, Any]) -> tuple[datetime, datetime]:
    start_at = _to_dt(
        payload.get("assignment_start_at")
        or payload.get("start_at")
        or payload.get("created_at")
    )
    end_at = _to_dt(
        payload.get("assignment_end_at")
        or payload.get("end_at")
        or payload.get("updated_at")
    )
    if end_at <= start_at:
        end_at = start_at + timedelta(hours=1)
    return start_at, end_at


def _next_project_sync_version(client: Any, project_id: str) -> int:
    """Atomically increment and return the project-level sync version counter.

    Uses a Firestore server-side INCREMENT transform on a dedicated counter
    document so that concurrent requests cannot read the same max value and
    produce duplicate sync_version numbers.
    """
    normalized_project_id = str(project_id or "").strip().upper()
    if not normalized_project_id:
        return 1

    counter_ref = client.collection("project_sync_counters").document(normalized_project_id)
    try:
        counter_ref.set({"sync_version": _FSIncrement(1)}, merge=True)
        snap = counter_ref.get()
        return int((snap.to_dict() or {}).get("sync_version") or 1)
    except Exception as exc:
        logger.warning(
            "Falling back to activity scan for sync_version project=%s: %s",
            normalized_project_id,
            exc,
        )

    # Fallback: scan activities for the current max (non-atomic, used only if
    # the counter collection is unavailable)
    max_sync_version = 0
    try:
        base_query = client.collection("activities").where("project_id", "==", normalized_project_id)
        for doc in base_query.stream():
            try:
                sv = int((doc.to_dict() or {}).get("sync_version") or 0)
            except (TypeError, ValueError):
                sv = 0
            if sv > max_sync_version:
                max_sync_version = sv
    except Exception as exc2:
        logger.warning(
            "Unable to scan sync_version for project=%s: %s",
            normalized_project_id,
            exc2,
        )
    return max_sync_version + 1


def _is_privileged_assignment_manager(current_user: Any) -> bool:
    return user_has_any_role(
        current_user,
        ["ADMIN", "COORD", "SUPERVISOR", "DESARROLLADOR", "DEVELOPER", "DEV"],
        None,
    )


def _principal_role_name(principal: Any | None) -> str | None:
    if principal is None:
        return None
    roles = getattr(principal, "roles", []) or []
    if isinstance(roles, str):
        roles = [roles]
    for role in roles:
        normalized = canonicalize_role_name(role)
        if normalized:
            return normalized
    return None


def _assignment_assignee_projection(
    assignee_user_id: str | None,
    assignee_principal: Any | None,
    *,
    participant_principals: list[Any] | None = None,
) -> dict[str, Any]:
    normalized_assignee_user_id = _safe_uuid_str(assignee_user_id)
    full_name = getattr(assignee_principal, "full_name", None) if assignee_principal else None
    email = getattr(assignee_principal, "email", None) if assignee_principal else None
    participant_ids: list[str] = []
    participant_names: list[str] = []
    for principal in participant_principals or []:
        principal_id = _safe_uuid_str(getattr(principal, "id", None))
        if not principal_id or principal_id in participant_ids:
            continue
        participant_ids.append(principal_id)
        display_name = str(getattr(principal, "full_name", "") or "").strip()
        if display_name:
            participant_names.append(display_name)
    if normalized_assignee_user_id and normalized_assignee_user_id not in participant_ids:
        participant_ids.insert(0, normalized_assignee_user_id)
    if full_name and full_name not in participant_names:
        participant_names.insert(0, full_name)
    return {
        "assigned_to_user_id": normalized_assignee_user_id or None,
        "assigned_to_user_name": full_name,
        "assigned_to_user_email": email,
        "assigned_to_name": full_name,
        "assigned_to_role": _principal_role_name(assignee_principal),
        "participant_user_ids": participant_ids,
        "participant_user_names": participant_names,
    }


def _normalized_participant_ids(payload: dict[str, Any]) -> list[str]:
    values = payload.get("participant_user_ids")
    if isinstance(values, list):
        normalized: list[str] = []
        for value in values:
            candidate = _safe_uuid_str(value)
            if candidate and candidate not in normalized:
                normalized.append(candidate)
        if normalized:
            return normalized

    fallback_assignee = _safe_uuid_str(payload.get("assigned_to_user_id"))
    fallback_creator = _safe_uuid_str(payload.get("created_by_user_id"))
    normalized = []
    if fallback_assignee:
        normalized.append(fallback_assignee)
    if fallback_creator and fallback_creator not in normalized:
        normalized.append(fallback_creator)
    return normalized


_HIDDEN_TEMPLATE_PROJECT_IDS = {"PROJECT_0", "P0"}


def _is_hidden_template_project(project_id: str | None) -> bool:
    return (project_id or "").strip().upper() in _HIDDEN_TEMPLATE_PROJECT_IDS


def _normalize_project_id(project_id: str | None) -> str:
    return (project_id or "").strip().upper()


def _stream_project_activities_with_fallback(
    client: Any,
    *,
    normalized_project_id: str,
    limit: int = 1000,
) -> list[Any]:
    """Load project activities using indexed query.
    
    OPTIMIZATION: Removed full table scan fallback to reduce Firestore costs.
    Only uses indexed equality queries on project_id field.
    """
    docs: list[Any] = []
    seen_doc_ids: set[str] = set()

    # Use indexed equality query on project_id
    query = client.collection("activities").where("project_id", "==", normalized_project_id)
    
    # Apply limit to prevent excessive reads
    query = query.limit(limit)
    
    for doc in query.stream():
        doc_id = str(getattr(doc, "id", "") or "")
        if doc_id and doc_id in seen_doc_ids:
            continue
        if doc_id:
            seen_doc_ids.add(doc_id)
        docs.append(doc)

    return docs


def _project_aliases(payload: dict[str, Any], doc_id: str) -> set[str]:
    aliases = {
        _normalize_project_id(doc_id),
        _normalize_project_id(payload.get("id")),
        _normalize_project_id(payload.get("code")),
        _normalize_project_id(payload.get("project_id")),
    }
    return {alias for alias in aliases if alias}


def _catalog_activity_codes_from_payload(payload: dict[str, Any]) -> set[str]:
    activity_codes: set[str] = set()

    activities = payload.get("activities")
    if isinstance(activities, dict):
        activity_codes.update(
            str(code or "").strip().upper()
            for code in activities.keys()
            if str(code or "").strip()
        )
    elif isinstance(activities, list):
        activity_codes.update(
            str(row.get("id") or "").strip().upper()
            for row in activities
            if isinstance(row, dict) and str(row.get("id") or "").strip()
        )

    effective = payload.get("effective") if isinstance(payload, dict) else None
    entities = effective.get("entities") if isinstance(effective, dict) else None
    nested_activities = entities.get("activities") if isinstance(entities, dict) else None
    if isinstance(nested_activities, list):
        activity_codes.update(
            str(row.get("id") or "").strip().upper()
            for row in nested_activities
            if isinstance(row, dict) and str(row.get("id") or "").strip()
        )

    return activity_codes


def _resolve_catalog_activity_codes(
    client: Any,
    *,
    project_id: str,
    catalog_version_id: str | None,
) -> set[str]:
    normalized_project = project_id.strip().upper()
    resolved_version = str(catalog_version_id or "").strip()

    snapshots = []
    if resolved_version:
        snapshots.extend(
            [
                client.collection("catalog_effective").document(f"{normalized_project}:{resolved_version}").get(),
                client.collection("catalog_effective").document(normalized_project).collection("versions").document(resolved_version).get(),
                client.collection("catalog_versions").document(resolved_version).get(),
                client.collection("catalog_bundles").document(f"{normalized_project}:{resolved_version}").get(),
            ]
        )

    snapshots.extend(
        [
            client.collection("catalog_effective").document(normalized_project).get(),
            client.collection("catalog_bundles").document(normalized_project).get(),
        ]
    )

    for snap in snapshots:
        if not snap.exists:
            continue
        payload = snap.to_dict() or {}
        codes = _catalog_activity_codes_from_payload(payload)
        if codes:
            return codes

    return set()


def _validate_transfer_target(
    *,
    project_id: str,
    assignee_user_id: str,
) -> Any:
    assignee_principal = get_firestore_user_by_id(assignee_user_id)
    if assignee_principal is None or assignee_principal.status != UserStatus.ACTIVE:
        raise api_error(
            status_code=status.HTTP_404_NOT_FOUND,
            code="ASSIGNMENT_ASSIGNEE_NOT_FOUND",
            message="Assignee not found or inactive",
        )

    allowed_roles = {"OPERATIVO", "SUPERVISOR", "COORD", "ADMIN"}
    principal_roles = {
        canonicalize_role_name(role) or ""
        for role in assignee_principal.roles
        if str(role).strip()
    }
    if not principal_roles.intersection(allowed_roles):
        raise api_error(
            status_code=status.HTTP_400_BAD_REQUEST,
            code="ASSIGNMENT_ASSIGNEE_INVALID_ROLE",
            message="Assignee role is not allowed for assignments",
        )

    project_ids = {project.strip().upper() for project in assignee_principal.project_ids if project.strip()}
    if project_ids and project_id not in project_ids:
        raise api_error(
            status_code=status.HTTP_400_BAD_REQUEST,
            code="ASSIGNMENT_ASSIGNEE_PROJECT_MISMATCH",
            message="Assignee does not belong to the requested project",
        )
    return assignee_principal


def _build_assignment_list_item(
    *,
    doc_id: str,
    payload: dict[str, Any],
    project_id: str,
    assignee_principal: Any | None,
) -> AssignmentListItem:
    start_at, end_at = _assignment_window(payload)
    state = str(payload.get("execution_state") or "PENDIENTE")
    raw_front = str(
        payload.get("frente")
        or payload.get("front_name")
        or payload.get("front")
        or ""
    ).strip()
    estado = str(payload.get("estado") or "").strip()
    municipio = str(payload.get("municipio") or "").strip()
    if not estado or not municipio:
        parsed_estado, parsed_municipio = _extract_scope_from_text(
            str(payload.get("title") or ""),
            str(payload.get("description") or ""),
        )
        estado = estado or parsed_estado
        municipio = municipio or parsed_municipio
    safe_title = _safe_assignment_title(payload)
    return AssignmentListItem(
        id=str(payload.get("uuid") or doc_id),
        project_id=str(payload.get("project_id") or project_id),
        assignee_user_id=UUID(str(payload.get("assigned_to_user_id"))),
        assignee_name=(assignee_principal.full_name if assignee_principal else "Sin responsable"),
        assignee_email=(assignee_principal.email if assignee_principal else None),
        activity_id=str(payload.get("uuid") or doc_id),
        title=safe_title,
        frente=raw_front,
        municipio=municipio,
        estado=estado,
        pk=payload.get("pk_start") or 0,
        start_at=start_at,
        end_at=end_at,
        risk="bajo",
        status=("PROGRAMADA" if state == "PENDIENTE" else state),
    )


def _safe_assignment_title(payload: dict[str, Any]) -> str:
    """Return a title compatible with legacy mobile local constraints.

    Older clients derive an activity-type seed from assignment title when opening
    agenda actions. Their local catalog code field is capped to 40 chars.
    """
    title = str(payload.get("title") or "").strip()
    activity_type_code = str(payload.get("activity_type_code") or "").strip()

    if title and len(title) <= 40:
        return title
    if activity_type_code and len(activity_type_code) <= 40:
        return activity_type_code
    if title:
        return title[:40].rstrip()
    if activity_type_code:
        return activity_type_code[:40].rstrip()
    return "Actividad"


@router.get("", response_model=list[AssignmentListItem])
def list_assignments(
    project_id: str = Query(..., description="Project filter"),
    from_dt: datetime = Query(..., alias="from", description="Range start (ISO-8601)"),
    to_dt: datetime = Query(..., alias="to", description="Range end (ISO-8601)"),
    include_all: bool = Query(False, description="If true, privileged roles can view all assignees"),
    current_user: Any = Depends(get_current_user),
):
    normalized_project_id = project_id.strip().upper()

    def _ensure_aware_utc(value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc)

    range_start = _ensure_aware_utc(from_dt)
    range_end = _ensure_aware_utc(to_dt)
    if range_end <= range_start:
        range_end = range_start + timedelta(days=1)

    can_view_all = include_all and user_has_any_role(
        current_user,
        [
            "ADMIN",
            "COORD",
            "SUPERVISOR",
            "OPERATIVO",
            "DESARROLLADOR",
            "DEVELOPER",
            "DEV",
        ],
        None,
    )
    current_user_id = str(getattr(current_user, "id", ""))
    has_global_scope, accessible_project_ids = resolve_user_project_access(current_user)

    client = get_firestore_client()
    principals = list_firestore_users()
    principal_by_id = {str(p.id): p for p in principals}

    _ALL_PROJECTS_SENTINEL = "TODOS"
    if normalized_project_id == _ALL_PROJECTS_SENTINEL:
        if has_global_scope:
            project_ids_to_query = sorted({
                str((doc.to_dict() or {}).get("id") or doc.id).strip().upper()
                for doc in client.collection("projects").stream()
                if str((doc.to_dict() or {}).get("id") or doc.id).strip()
            })
        else:
            project_ids_to_query = sorted({pid for pid in accessible_project_ids if pid})
        raw_docs: list[Any] = []
        for pid in project_ids_to_query:
            raw_docs.extend(client.collection("activities").where("project_id", "==", pid).stream())
        docs = iter(raw_docs)
    else:
        if not has_global_scope and normalized_project_id not in accessible_project_ids:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No access to this project",
            )
        docs = iter(
            _stream_project_activities_with_fallback(
                client,
                normalized_project_id=normalized_project_id,
            )
        )

    items: list[AssignmentListItem] = []
    seeded_project_ids: set[str] = set()
    _seen_groups_assign: set[str] = set()
    _seen_legacy_assign: set[str] = set()
    for doc in docs:
        payload = doc.to_dict() or {}
        is_canceled = payload.get("deleted_at") is not None
        # Keep canceled assignments visible for planning views (include_all=true)
        # while preserving legacy personal-agenda behavior.
        if is_canceled and not include_all:
            continue
        payload_project_id = str(payload.get("project_id") or normalized_project_id).strip().upper()
        if payload_project_id:
            seeded_project_ids.add(payload_project_id)
        assignee_user_id = _safe_uuid_str(payload.get("assigned_to_user_id"))
        participant_user_ids = _normalized_participant_ids(payload)
        created_by_user_id = _safe_uuid_str(payload.get("created_by_user_id"))
        effective_assignee_user_id = assignee_user_id or created_by_user_id
        if not effective_assignee_user_id:
            continue
        if not can_view_all and current_user_id and current_user_id not in participant_user_ids:
            continue

        start_at, end_at = _assignment_window(payload)
        if end_at < range_start or start_at > range_end:
            continue
        state = str(payload.get("execution_state") or "PENDIENTE")
        raw_front = str(
            payload.get("frente")
            or payload.get("front_name")
            or payload.get("front")
            or ""
        ).strip()
        estado = str(payload.get("estado") or "").strip()
        municipio = str(payload.get("municipio") or "").strip()
        if not estado or not municipio:
            parsed_estado, parsed_municipio = _extract_scope_from_text(
                str(payload.get("title") or ""),
                str(payload.get("description") or ""),
            )
            estado = estado or parsed_estado
            municipio = municipio or parsed_municipio
        # Deduplicate multi-responsible activities: each activity_group counts as 1.
        _gid_a = str(payload.get("activity_group_id") or "").strip()
        if _gid_a:
            if _gid_a in _seen_groups_assign:
                continue
            _seen_groups_assign.add(_gid_a)
        else:
            _start_at_a = str(payload.get("assignment_start_at") or "").strip()
            if _start_at_a:
                _lka = "|".join([
                    str(payload.get("project_id") or ""),
                    str(payload.get("activity_type_code") or ""),
                    _start_at_a,
                    str(payload.get("assignment_end_at") or ""),
                    str(payload.get("created_by_user_id") or ""),
                    str(payload.get("front_id") or ""),
                    str(payload.get("pk_start") or ""),
                ])
                if _lka in _seen_legacy_assign:
                    continue
                _seen_legacy_assign.add(_lka)
        principal = principal_by_id.get(effective_assignee_user_id)
        response_project_id = payload_project_id or str(payload.get("project_id") or "").strip().upper()
        if not response_project_id and normalized_project_id != _ALL_PROJECTS_SENTINEL:
            response_project_id = normalized_project_id
        if not response_project_id:
            # Skip malformed payloads in all-project views to avoid leaking sentinel values.
            continue

        items.append(
            AssignmentListItem(
                id=str(payload.get("uuid") or doc.id),
                project_id=response_project_id,
                assignee_user_id=effective_assignee_user_id,
                assignee_name=(principal.full_name if principal else "Sin responsable"),
                assignee_email=(principal.email if principal else None),
                activity_id=str(payload.get("uuid") or doc.id),
                title=_safe_assignment_title(payload),
                frente=raw_front,
                municipio=municipio,
                estado=estado,
                pk=payload.get("pk_start"),
                start_at=start_at,
                end_at=end_at,
                risk="bajo",
                status=("CANCELADA" if is_canceled else ("PROGRAMADA" if state == "PENDIENTE" else state)),
                latitude=_safe_float(payload.get("latitude")),
                longitude=_safe_float(payload.get("longitude")),
            )
        )

    return items


@router.get("/transfer-candidates", response_model=list[AssignmentAssigneeOption])
def list_transfer_candidates(
    project_id: str = Query(..., description="Project scope filter"),
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
):
    """Return all active project members eligible to receive an assignment transfer.

    Unlike /assignees, this endpoint does NOT restrict OPERATIVO callers to
    seeing only themselves — OPERATIVO needs the full list so they can pick a
    recipient when transferring one of their activities.
    ADMIN users are excluded: they are system administrators, not field workers.
    """
    _assignable_roles = {"OPERATIVO", "SUPERVISOR", "COORD"}
    normalized_project_id = project_id.strip().upper()

    principals = list_firestore_users()
    options: list[AssignmentAssigneeOption] = []
    for p in principals:
        if p.status != UserStatus.ACTIVE:
            continue
        principal_roles = {
            canonicalize_role_name(role) or ""
            for role in (p.roles or [])
            if str(role).strip()
        }
        if not principal_roles.intersection(_assignable_roles):
            continue
        if p.project_ids and normalized_project_id not in p.project_ids:
            continue
        options.append(
            AssignmentAssigneeOption(
                user_id=p.id,
                full_name=p.full_name,
                email=p.email,
                role_name=_principal_role_name(p) or "",
            )
        )
    options.sort(key=lambda item: (item.full_name.lower(), item.email.lower()))
    return options


@router.get("/assignees", response_model=list[AssignmentAssigneeOption])
def list_assignees(
    project_id: str = Query(..., description="Project filter"),
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
):
    _assignable_roles = {"OPERATIVO", "SUPERVISOR", "COORD"}

    # All callers (including OPERATIVO) now see all active project members.
    # Restricting OPERATIVO to self-only prevented co-responsible candidate
    # lists from working.  The create_assignment endpoint still enforces that
    # OPERATIVO can only create assignments that include themselves.

    principals = list_firestore_users()
    options: list[AssignmentAssigneeOption] = []
    for p in principals:
        if p.status != UserStatus.ACTIVE:
            continue
        principal_roles = {
            canonicalize_role_name(role) or ""
            for role in (p.roles or [])
            if str(role).strip()
        }
        if not principal_roles.intersection(_assignable_roles):
            continue
        # ADMIN/SUPERVISOR/COORD have global scope: if project_ids is empty they
        # appear in all projects; if set, it must include the requested project.
        # OPERATIVO must be explicitly assigned to the project (project_ids required).
        _global_scope_roles = {"ADMIN", "SUPERVISOR", "COORD"}
        has_global_scope = bool(principal_roles.intersection(_global_scope_roles))
        normalised_pid = project_id.strip().upper()
        user_pids = {str(pid).strip().upper() for pid in (p.project_ids or []) if str(pid).strip()}
        if has_global_scope:
            if user_pids and normalised_pid not in user_pids:
                continue
        else:
            # OPERATIVO: require explicit project membership
            if not user_pids or normalised_pid not in user_pids:
                continue
        options.append(
            AssignmentAssigneeOption(
                user_id=p.id,
                full_name=p.full_name,
                email=p.email,
                role_name=_principal_role_name(p) or "",
            )
        )
    options.sort(key=lambda item: (item.full_name.lower(), item.email.lower()))
    return options


def _resolve_front_ids_to_assign(
    client: Any,
    project_id: str,
    payload: AssignmentCreate,
) -> list[tuple[str | None, str]]:
    """Resolve which fronts to assign based on payload flags.
    
    Returns a list of (front_id, front_name) tuples.
    """
    # Case 1: all_fronts flag - query all fronts from the project
    if payload.all_fronts:
        front_docs = list(
            client.collection("fronts")
            .where("project_id", "==", project_id)
            .stream()
        )
        result = []
        for doc in front_docs:
            doc_data = doc.to_dict() or {}
            front_id = doc.id
            front_name = str(doc_data.get("name") or "").strip()
            result.append((front_id, front_name))
        return result if result else [(None, payload.front_ref or "")]
    
    # Case 2: explicit front_ids list
    if payload.front_ids:
        result = []
        for fid in payload.front_ids:
            front_id_str = str(fid)
            # Get front name from firestore
            front_doc = client.collection("fronts").document(front_id_str).get()
            if front_doc.exists:
                front_name = str(front_doc.to_dict().get("name") or "").strip()
            else:
                front_name = ""
            result.append((front_id_str, front_name))
        return result
    
    # Case 3: backward compatibility - single front_id
    if payload.front_id:
        front_id_str = str(payload.front_id)
        front_doc = client.collection("fronts").document(front_id_str).get()
        if front_doc.exists:
            front_name = str(front_doc.to_dict().get("name") or "").strip()
        else:
            front_name = (payload.front_ref or "").strip()
        return [(front_id_str, front_name)]
    
    # Case 4: only front_ref (no front_id)
    if payload.front_ref:
        return [(None, (payload.front_ref or "").strip())]
    
    # No front specified
    return []


@router.post("", response_model=list[AssignmentListItem], status_code=status.HTTP_201_CREATED)
def create_assignment(
    payload: AssignmentCreate,
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
):
    project_id = payload.project_id.strip().upper()
    participant_candidates = [str(payload.assignee_user_id)] + [str(v) for v in (payload.assignee_user_ids or [])]
    participant_user_ids: list[str] = []
    for candidate in participant_candidates:
        normalized_candidate = _safe_uuid_str(candidate)
        if normalized_candidate and normalized_candidate not in participant_user_ids:
            participant_user_ids.append(normalized_candidate)
    if not participant_user_ids:
        raise api_error(
            status_code=status.HTTP_400_BAD_REQUEST,
            code="ASSIGNMENT_PARTICIPANTS_REQUIRED",
            message="At least one assignee is required",
        )
    primary_assignee_user_id = participant_user_ids[0]

    # OPERATIVO can only create assignments for themselves.
    if user_has_any_role(current_user, ["OPERATIVO"], None) and not user_has_any_role(
        current_user, ["ADMIN", "COORD", "SUPERVISOR"], None
    ):
        if str(current_user.id).strip() not in participant_user_ids:
            raise api_error(
                status_code=status.HTTP_403_FORBIDDEN,
                code="ASSIGNMENT_SELF_ONLY",
                message="Operativo users can only create assignments that include themselves.",
            )

    if payload.end_at <= payload.start_at:
        raise api_error(status_code=status.HTTP_400_BAD_REQUEST, code="ASSIGNMENT_INVALID_DATE_RANGE", message="end_at must be greater than start_at")

    client = get_firestore_client()
    
    # Resolve fronts to assign
    fronts_to_assign = _resolve_front_ids_to_assign(client, project_id, payload)
    if not fronts_to_assign:
        raise api_error(
            status_code=status.HTTP_400_BAD_REQUEST,
            code="ASSIGNMENT_FRONT_REQUIRED",
            message="At least one front is required. Use 'front_ids' for specific fronts or 'all_fronts' for all project fronts.",
        )
    
    estado = (payload.estado or "").strip()
    municipio = (payload.municipio or "").strip()
    description_parts = [f"planned:{payload.risk.strip().lower()}"]
    if estado:
        description_parts.append(f"estado={estado}")
    if municipio:
        description_parts.append(f"municipio={municipio}")
    description_value = ";".join(description_parts)

    type_code = payload.activity_type_code.strip().upper()
    title = payload.title.strip() if payload.title and payload.title.strip() else type_code
    assignee_principal = get_firestore_user_by_id(primary_assignee_user_id)
    participant_principals: list[Any] = []
    for participant_id in participant_user_ids:
        principal = get_firestore_user_by_id(participant_id)
        if principal is not None:
            participant_principals.append(principal)
    
    # Resolve current catalog version for the project
    catalog_version_id = None
    
    # Try to get catalog_current first
    current_snap = client.collection("catalog_current").document(project_id).get()
    if current_snap.exists:
        payload_snap = current_snap.to_dict() or {}
        catalog_version_id = str(payload_snap.get("version_id") or "").strip() or None
    
    # Fallback: look for is_current=True in catalog_versions
    if not catalog_version_id:
        catalog_docs = (
            client.collection("catalog_versions")
            .where("project_id", "==", project_id)
            .where("is_current", "==", True)
            .limit(1)
            .stream()
        )
        for doc in catalog_docs:
            doc_data = doc.to_dict() or {}
            catalog_version_id = str(doc_data.get("version_id") or doc_data.get("id") or doc.id).strip() or None
            if catalog_version_id:
                break
    
    # Validate activity_type_code against catalog if we have a catalog version
    if catalog_version_id:
        try:
            activities_in_catalog = _resolve_catalog_activity_codes(
                client,
                project_id=project_id,
                catalog_version_id=catalog_version_id,
            )
            if activities_in_catalog and type_code not in activities_in_catalog:
                logger.warning(
                    "Assignment activity_type_code not present in resolved catalog; continuing "
                    "project=%s type_code=%s version=%s candidates=%s",
                    project_id,
                    type_code,
                    catalog_version_id,
                    sorted(activities_in_catalog),
                )
        except HTTPException:
            raise
        except Exception as e:
            logger.warning(f"Failed to validate activity type against catalog: {e}")
            # Continue anyway with the assignment
    
    # Create one activity per front, with each participant having their own document
    # linked by activity_group_id when multiple participants or multiple fronts exist.
    should_use_groups = len(fronts_to_assign) > 1 or len(participant_user_ids) > 1
    activity_group_id = str(uuid4()) if should_use_groups else None
    base_sync_version = _next_project_sync_version(client, project_id)

    created_items: list[AssignmentListItem] = []
    global_sync_offset = 0
    
    for front_id, front_name in fronts_to_assign:
        # For each front, create one activity per participant
        for idx, participant_id in enumerate(participant_user_ids):
            participant_uuid = uuid4()
            participant_principal_obj = participant_principals[idx] if idx < len(participant_principals) else None
            doc_payload = {
                "uuid": str(participant_uuid),
                "server_id": None,
                "project_id": project_id,
                "front_id": front_id,
                "frente": front_name,
                "estado": estado or None,
                "municipio": municipio or None,
                "colonia": (payload.colonia or "").strip() or None,
                "pk_start": payload.pk,
                "pk_end": None,
                "execution_state": "PENDIENTE",
                **_assignment_assignee_projection(
                    participant_id,
                    participant_principal_obj,
                    participant_principals=[participant_principal_obj] if participant_principal_obj else [],
                ),
                "created_by_user_id": str(current_user.id),
                "catalog_version_id": catalog_version_id,
                "activity_type_code": type_code,
                "title": title,
                "description": description_value,
                "gps_mismatch": False,
                "catalog_changed": type_code.startswith("CUSTOM_"),
                "latitude": str(payload.latitude) if payload.latitude is not None else None,
                "longitude": str(payload.longitude) if payload.longitude is not None else None,
                "assignment_start_at": payload.start_at.isoformat(),
                "assignment_end_at": payload.end_at.isoformat(),
                "created_at": payload.start_at.isoformat(),
                "updated_at": payload.end_at.isoformat(),
                "deleted_at": None,
                "sync_version": base_sync_version + global_sync_offset,
                "activity_group_id": activity_group_id,
                "is_primary_responsible": (idx == 0 and fronts_to_assign.index((front_id, front_name)) == 0),
            }
            client.collection("activities").document(str(participant_uuid)).set(doc_payload)
            global_sync_offset += 1
            
            # Build response item for this created activity
            created_items.append(
                AssignmentListItem(
                    id=str(participant_uuid),
                    project_id=project_id,
                    assignee_user_id=UUID(participant_id),
                    assignee_name=(participant_principal_obj.full_name if participant_principal_obj else "Sin responsable"),
                    assignee_email=(participant_principal_obj.email if participant_principal_obj else None),
                    activity_id=str(participant_uuid),
                    title=title,
                    frente=front_name,
                    municipio=municipio,
                    estado=estado,
                    pk=payload.pk,
                    start_at=payload.start_at,
                    end_at=payload.end_at,
                    risk=payload.risk,
                    status="PROGRAMADA",
                    latitude=payload.latitude,
                    longitude=payload.longitude,
                )
            )

    # When the activity type code is CUSTOM_*, create a catalog_candidates
    # entry so admins can review / approve it from the Verificación tab.
    if type_code.startswith("CUSTOM_"):
        now = datetime.now(timezone.utc)
        coll = client.collection("catalog_candidates")
        doc_id = f"{project_id}__activity__{type_code}"
        ref = coll.document(doc_id)
        snap = ref.get()
        # Use the first activity's UUID for tracking
        first_activity_uuid = created_items[0].id if created_items else str(uuid4())
        if not snap.exists:
            ref.set({
                "id": doc_id,
                "custom_id": type_code,
                "type": "activity",
                "name": title,
                "project_id": project_id,
                "proposed_by_user_id": str(current_user.id),
                "activity_id": first_activity_uuid,
                "status": "pending",
                "proposed_at": now,
                "last_seen_at": now,
                "reviewed_at": None,
                "reviewed_by_user_id": None,
                "review_comment": None,
            })
            logger.info(
                "CATALOG_CANDIDATE_CREATED_FROM_ASSIGNMENT custom_id=%s name=%s project=%s",
                type_code,
                title,
                project_id,
            )
        elif (snap.to_dict() or {}).get("status") == "pending":
            ref.set({"last_seen_at": now, "activity_id": first_activity_uuid}, merge=True)

    write_firestore_audit_log(
        action="ASSIGNMENT_CREATED",
        entity="activity",
        entity_id=str(created_items[0].id if created_items else ""),
        actor=current_user,
        details={
            "project_id": project_id,
            "title": title,
            "assigned_to_user_id": primary_assignee_user_id,
            "participant_user_ids": participant_user_ids,
            "activity_group_id": activity_group_id,
            "assigned_to_name": assignee_principal.full_name if assignee_principal else None,
            "assigned_to_role": _principal_role_name(assignee_principal),
            "start_at": payload.start_at.isoformat(),
            "end_at": payload.end_at.isoformat(),
            "risk": payload.risk,
            "num_fronts_assigned": len(fronts_to_assign),
        },
    )

    # Fire-and-forget push notification + in-app notification to all participants.
    is_multi_participant = len(participant_user_ids) > 1
    actor_name = getattr(current_user, "full_name", None)
    for item in created_items:
        try:
            notify_new_assignment(
                project_id=project_id,
                activity_id=item.id,
                activity_title=title,
                assignee_user_id=str(item.assignee_user_id),
                assigned_by_name=actor_name,
                is_transfer=False,
                municipio=municipio or None,
                estado=estado or None,
                frente=item.frente or None,
                start_at=payload.start_at.isoformat(),
            )
        except Exception:
            logger.exception("notify_new_assignment failed for activity %s", item.id)

        try:
            notif_type = "co_responsable_added" if (is_multi_participant and str(item.assignee_user_id) != primary_assignee_user_id) else "new_assignment"
            create_user_notification(
                recipient_user_id=str(item.assignee_user_id),
                notification_type=notif_type,
                activity_id=item.id,
                activity_title=title,
                project_id=project_id,
                from_user_id=str(current_user.id),
                from_user_name=actor_name,
                requires_acceptance=True,
                metadata={
                    "activity_group_id": activity_group_id,
                    "municipio": municipio or None,
                    "estado": estado or None,
                    "frente": item.frente or None,
                    "start_at": payload.start_at.isoformat(),
                    "end_at": payload.end_at.isoformat(),
                },
            )
        except Exception:
            logger.exception("create_user_notification failed for activity %s", item.id)

    return created_items


@router.post("/{assignment_id}/cancel", response_model=AssignmentCancelResponse)
def cancel_assignment(
    assignment_id: UUID,
    payload: AssignmentCancelRequest | None = None,
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR"])),
):
    client = get_firestore_client()
    ref = client.collection("activities").document(str(assignment_id))
    snap = ref.get()
    if not snap.exists:
        raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="ASSIGNMENT_NOT_FOUND", message="Assignment not found")
    doc = snap.to_dict() or {}
    cancel_reason = payload.reason.strip() if payload and payload.reason else None
    current_assignee_user_id = _safe_uuid_str(doc.get("assigned_to_user_id"))
    current_assignee_principal = (
        get_firestore_user_by_id(current_assignee_user_id)
        if current_assignee_user_id
        else None
    )

    # If already soft-deleted, keep endpoint idempotent.
    if doc.get("deleted_at") is not None:
        return AssignmentCancelResponse(
            id=str(assignment_id),
            canceled=False,
            execution_state=str(doc.get("execution_state") or "PENDIENTE"),
            canceled_at=None,
            canceled_by_user_id=current_user.id,
            cancel_reason=cancel_reason,
        )

    canceled_at = datetime.now(timezone.utc)
    ref.set(
        {
            **_assignment_assignee_projection(None, None),
            "execution_state": "PENDIENTE",
            "deleted_at": canceled_at.isoformat(),
            "updated_at": canceled_at.isoformat(),
            "sync_version": _next_project_sync_version(client, str(doc.get("project_id") or "")),
        },
        merge=True,
    )
    write_firestore_audit_log(
        action="ASSIGNMENT_CANCELLED",
        entity="activity",
        entity_id=str(assignment_id),
        actor=current_user,
        details={
            "project_id": str(doc.get("project_id") or "").strip().upper() or None,
            "title": str(doc.get("title") or "").strip() or None,
            "previous_assignee_user_id": current_assignee_user_id or None,
            "previous_assignee_name": current_assignee_principal.full_name if current_assignee_principal else None,
            "previous_assignee_role": _principal_role_name(current_assignee_principal),
            "reason": cancel_reason,
        },
    )

    # Notify the previously assigned user that their activity was cancelled.
    if current_assignee_user_id:
        _cancel_project_id = str(doc.get("project_id") or "").strip().upper()
        _cancel_title = str(doc.get("title") or doc.get("activity_type_code") or "Actividad").strip()
        try:
            from app.services.push_notification_service import notify_user as _notify_user
            _notify_user(
                user_id=current_assignee_user_id,
                title="Actividad cancelada",
                body=f'"{_cancel_title}" fue cancelada.' + (f" Motivo: {cancel_reason}." if cancel_reason else ""),
                data={"type": "activity_update", "project_id": _cancel_project_id, "activity_id": str(assignment_id)},
                project_id=_cancel_project_id or None,
            )
        except Exception:
            logger.exception("notify_user (cancel) failed for activity %s", assignment_id)
        try:
            create_user_notification(
                recipient_user_id=current_assignee_user_id,
                notification_type="assignment_cancelled",
                activity_id=str(assignment_id),
                activity_title=_cancel_title,
                project_id=_cancel_project_id,
                from_user_id=str(getattr(current_user, "id", "")),
                from_user_name=getattr(current_user, "full_name", None),
                requires_acceptance=False,
                metadata={"reason": cancel_reason},
            )
        except Exception:
            logger.exception("create_user_notification (cancel) failed for activity %s", assignment_id)

    return AssignmentCancelResponse(
        id=str(assignment_id),
        canceled=True,
        execution_state="PENDIENTE",
        canceled_at=canceled_at,
        canceled_by_user_id=current_user.id,
        cancel_reason=cancel_reason,
    )


@router.post("/{assignment_id}/transfer", response_model=AssignmentListItem)
def transfer_assignment(
    assignment_id: UUID,
    payload: AssignmentTransferRequest,
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
):
    client = get_firestore_client()
    ref = client.collection("activities").document(str(assignment_id))
    snap = ref.get()
    if not snap.exists:
        raise api_error(
            status_code=status.HTTP_404_NOT_FOUND,
            code="ASSIGNMENT_NOT_FOUND",
            message="Assignment not found",
        )

    doc = snap.to_dict() or {}
    project_id = str(doc.get("project_id") or "").strip().upper()
    if not project_id:
        raise api_error(
            status_code=status.HTTP_400_BAD_REQUEST,
            code="ASSIGNMENT_PROJECT_REQUIRED",
            message="Assignment project is missing",
        )

    current_assignee_user_id = _safe_uuid_str(doc.get("assigned_to_user_id"))
    if not current_assignee_user_id:
        raise api_error(
            status_code=status.HTTP_409_CONFLICT,
            code="ASSIGNMENT_NOT_ASSIGNED",
            message="Assignment has no current assignee",
        )

    actor_user_id = _safe_uuid_str(getattr(current_user, "id", None))
    existing_participant_user_ids = _normalized_participant_ids(doc)
    if not _is_privileged_assignment_manager(current_user) and actor_user_id not in existing_participant_user_ids:
        raise api_error(
            status_code=status.HTTP_403_FORBIDDEN,
            code="ASSIGNMENT_TRANSFER_FORBIDDEN",
            message="Operative can only transfer activities where they are participants",
        )

    next_assignee_user_id = str(payload.assignee_user_id)
    if next_assignee_user_id == current_assignee_user_id:
        raise api_error(
            status_code=status.HTTP_409_CONFLICT,
            code="ASSIGNMENT_TRANSFER_SAME_ASSIGNEE",
            message="Assignment is already assigned to that user",
        )

    next_assignee_principal = _validate_transfer_target(
        project_id=project_id,
        assignee_user_id=next_assignee_user_id,
    )
    participant_user_ids = [next_assignee_user_id]
    for participant_user_id in existing_participant_user_ids:
        if participant_user_id not in participant_user_ids:
            participant_user_ids.append(participant_user_id)
    participant_principals: list[Any] = [next_assignee_principal]
    for participant_user_id in participant_user_ids[1:]:
        principal = get_firestore_user_by_id(participant_user_id)
        if principal is not None:
            participant_principals.append(principal)
    previous_assignee_principal = get_firestore_user_by_id(current_assignee_user_id)
    transfer_at = datetime.now(timezone.utc)
    next_sync_version = _next_project_sync_version(client, project_id)
    ref.set(
        {
            **_assignment_assignee_projection(
                next_assignee_user_id,
                next_assignee_principal,
                participant_principals=participant_principals,
            ),
            "updated_at": transfer_at.isoformat(),
            "sync_version": next_sync_version,
        },
        merge=True,
    )

    updated_payload = dict(doc)
    updated_payload.update(
        _assignment_assignee_projection(
            next_assignee_user_id,
            next_assignee_principal,
            participant_principals=participant_principals,
        )
    )
    updated_payload["updated_at"] = transfer_at.isoformat()
    updated_payload["sync_version"] = next_sync_version

    write_firestore_audit_log(
        action="ASSIGNMENT_TRANSFERRED",
        entity="activity",
        entity_id=str(assignment_id),
        actor=current_user,
        details={
            "project_id": project_id,
            "from_assignee_user_id": current_assignee_user_id,
            "from_assignee_name": previous_assignee_principal.full_name if previous_assignee_principal else None,
            "from_assignee_role": _principal_role_name(previous_assignee_principal),
            "to_assignee_user_id": next_assignee_user_id,
            "participant_user_ids": participant_user_ids,
            "to_assignee_name": next_assignee_principal.full_name,
            "to_assignee_role": _principal_role_name(next_assignee_principal),
            "reason": payload.reason,
        },
    )

    # Fire-and-forget push notification to the new assignee.
    try:
        notify_new_assignment(
            project_id=project_id,
            activity_id=str(assignment_id),
            activity_title=str(doc.get("title") or doc.get("activity_type_code") or "Actividad"),
            assignee_user_id=next_assignee_user_id,
            assigned_by_name=getattr(current_user, "full_name", None),
            is_transfer=True,
            municipio=str(doc.get("municipio") or "").strip() or None,
            estado=str(doc.get("estado") or "").strip() or None,
            frente=str(doc.get("frente") or "").strip() or None,
            start_at=str(doc.get("assignment_start_at") or "").strip() or None,
        )
    except Exception:
        logger.exception("notify_new_assignment (transfer) failed for activity %s", assignment_id)

    # In-app notification for the new assignee.
    try:
        create_user_notification(
            recipient_user_id=next_assignee_user_id,
            notification_type="assignment_transferred",
            activity_id=str(assignment_id),
            activity_title=str(doc.get("title") or doc.get("activity_type_code") or "Actividad"),
            project_id=project_id,
            from_user_id=str(getattr(current_user, "id", "")),
            from_user_name=getattr(current_user, "full_name", None),
            requires_acceptance=True,
            metadata={
                "reason": payload.reason,
                "previous_assignee_user_id": current_assignee_user_id,
                "previous_assignee_name": previous_assignee_principal.full_name if previous_assignee_principal else None,
                "municipio": str(doc.get("municipio") or "").strip() or None,
                "estado": str(doc.get("estado") or "").strip() or None,
                "frente": str(doc.get("frente") or "").strip() or None,
            },
        )
    except Exception:
        logger.exception("create_user_notification (transfer) failed for activity %s", assignment_id)

    return _build_assignment_list_item(
        doc_id=str(assignment_id),
        payload=updated_payload,
        project_id=project_id,
        assignee_principal=next_assignee_principal,
    )


class AssignmentAddParticipantRequest(BaseModel):
    user_id: UUID


@router.post("/{assignment_id}/add-participant", response_model=AssignmentListItem)
def add_participant(
    assignment_id: UUID,
    payload: AssignmentAddParticipantRequest,
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
):
    """Add a co-responsible to an existing activity without changing the primary assignee.

    OPERATIVO callers must already be participants in the activity.
    ADMIN/COORD/SUPERVISOR can add participants to any activity.
    The new participant receives a notification.
    """
    client = get_firestore_client()
    ref = client.collection("activities").document(str(assignment_id))
    snap = ref.get()
    if not snap.exists:
        raise api_error(
            status_code=status.HTTP_404_NOT_FOUND,
            code="ASSIGNMENT_NOT_FOUND",
            message="Assignment not found",
        )

    doc = snap.to_dict() or {}
    project_id = str(doc.get("project_id") or "").strip().upper()
    actor_user_id = _safe_uuid_str(getattr(current_user, "id", None))
    existing_participant_user_ids = _normalized_participant_ids(doc)

    if not _is_privileged_assignment_manager(current_user) and actor_user_id not in existing_participant_user_ids:
        raise api_error(
            status_code=status.HTTP_403_FORBIDDEN,
            code="ADD_PARTICIPANT_FORBIDDEN",
            message="Operativo can only add participants to activities where they are participants",
        )

    new_participant_id = str(payload.user_id)
    if new_participant_id in existing_participant_user_ids:
        raise api_error(
            status_code=status.HTTP_409_CONFLICT,
            code="ADD_PARTICIPANT_ALREADY_EXISTS",
            message="User is already a participant of this activity",
        )

    new_participant_principal = _validate_transfer_target(
        project_id=project_id,
        assignee_user_id=new_participant_id,
    )

    updated_participant_ids = list(existing_participant_user_ids) + [new_participant_id]
    participant_principals: list[Any] = []
    for pid in updated_participant_ids:
        p = get_firestore_user_by_id(pid)
        if p is not None:
            participant_principals.append(p)

    primary_assignee_user_id = _safe_uuid_str(doc.get("assigned_to_user_id")) or (
        existing_participant_user_ids[0] if existing_participant_user_ids else None
    )
    primary_assignee_principal = (
        get_firestore_user_by_id(primary_assignee_user_id) if primary_assignee_user_id else None
    )

    now = datetime.now(timezone.utc)
    next_sync_version = _next_project_sync_version(client, project_id)

    participant_names = [
        str(getattr(p, "full_name", "") or "").strip()
        for p in participant_principals
        if str(getattr(p, "full_name", "") or "").strip()
    ]
    ref.set(
        {
            "participant_user_ids": updated_participant_ids,
            "participant_user_names": participant_names,
            "updated_at": now.isoformat(),
            "sync_version": next_sync_version,
        },
        merge=True,
    )

    updated_payload = dict(doc)
    updated_payload.update({
        "participant_user_ids": updated_participant_ids,
        "participant_user_names": participant_names,
        "updated_at": now.isoformat(),
        "sync_version": next_sync_version,
    })

    write_firestore_audit_log(
        client=client,
        actor_user_id=actor_user_id or "",
        actor_name=getattr(current_user, "full_name", None),
        action="ADD_PARTICIPANT",
        resource_type="activity",
        resource_id=str(assignment_id),
        project_id=project_id,
        metadata={
            "new_participant_user_id": new_participant_id,
            "new_participant_name": new_participant_principal.full_name,
            "participant_user_ids": updated_participant_ids,
        },
    )

    try:
        notify_new_assignment(
            project_id=project_id,
            activity_id=str(assignment_id),
            activity_title=str(doc.get("title") or doc.get("activity_type_code") or "Actividad"),
            assignee_user_id=new_participant_id,
            assigned_by_name=getattr(current_user, "full_name", None),
            is_transfer=False,
            municipio=str(doc.get("municipio") or "").strip() or None,
            estado=str(doc.get("estado") or "").strip() or None,
            frente=str(doc.get("frente") or "").strip() or None,
            start_at=str(doc.get("assignment_start_at") or "").strip() or None,
        )
    except Exception:
        logger.exception("notify_new_assignment (add_participant) failed for activity %s", assignment_id)

    try:
        create_user_notification(
            recipient_user_id=new_participant_id,
            notification_type="co_responsable_added",
            activity_id=str(assignment_id),
            activity_title=str(doc.get("title") or doc.get("activity_type_code") or "Actividad"),
            project_id=project_id,
            from_user_id=actor_user_id or "",
            from_user_name=getattr(current_user, "full_name", None),
            requires_acceptance=True,
            metadata={
                "primary_assignee_user_id": primary_assignee_user_id,
                "primary_assignee_name": primary_assignee_principal.full_name if primary_assignee_principal else None,
                "municipio": str(doc.get("municipio") or "").strip() or None,
                "estado": str(doc.get("estado") or "").strip() or None,
                "frente": str(doc.get("frente") or "").strip() or None,
            },
        )
    except Exception:
        logger.exception("create_user_notification (add_participant) failed for activity %s", assignment_id)

    return _build_assignment_list_item(
        doc_id=str(assignment_id),
        payload=updated_payload,
        project_id=project_id,
        assignee_principal=primary_assignee_principal,
    )


class AssignmentRespondRequest(BaseModel):
    notification_id: str | None = None


@router.post("/{assignment_id}/accept", status_code=status.HTTP_204_NO_CONTENT)
def accept_assignment(
    assignment_id: UUID,
    payload: AssignmentRespondRequest | None = None,
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
):
    """Accept a pending assignment, transfer, or co-responsable notification.

    Marks the activity as explicitly accepted by the recipient.  If a
    ``notification_id`` is provided the corresponding notification record is
    updated to status ``accepted``; otherwise all unresponded notifications for
    this user / activity are accepted.
    """
    client = get_firestore_client()
    activity_ref = client.collection("activities").document(str(assignment_id))
    snap = activity_ref.get()
    if not snap.exists:
        raise api_error(
            status_code=status.HTTP_404_NOT_FOUND,
            code="ASSIGNMENT_NOT_FOUND",
            message="Assignment not found",
        )

    doc = snap.to_dict() or {}
    current_user_id = str(getattr(current_user, "id", "")).strip()
    participant_user_ids = _normalized_participant_ids(doc)

    if current_user_id not in participant_user_ids and not _is_privileged_assignment_manager(current_user):
        raise api_error(
            status_code=status.HTTP_403_FORBIDDEN,
            code="ASSIGNMENT_NOT_PARTICIPANT",
            message="You are not a participant of this activity",
        )

    # Mark acceptance on the activity document.
    now = datetime.now(timezone.utc)
    activity_ref.set(
        {
            f"acceptance_by_{current_user_id}": "accepted",
            "updated_at": now.isoformat(),
        },
        merge=True,
    )

    # Update the notification record if a notification_id is provided.
    notif_id = (payload.notification_id or "").strip() if payload else ""
    if notif_id:
        update_notification_response(
            notification_id=notif_id,
            user_id=current_user_id,
            response="accepted",
        )
    else:
        # Try to auto-resolve the pending notification for this activity+user.
        try:
            pending_notifs = list(
                client.collection("user_notifications")
                .where("recipient_user_id", "==", current_user_id)
                .where("activity_id", "==", str(assignment_id))
                .where("status", "==", "unread")
                .limit(5)
                .stream()
            )
            for n in pending_notifs:
                n.reference.set(
                    {"status": "accepted", "responded_at": now.isoformat(), "read_at": now.isoformat()},
                    merge=True,
                )
        except Exception:
            logger.warning("Could not auto-resolve notifications for activity %s", assignment_id)

    write_firestore_audit_log(
        action="ASSIGNMENT_ACCEPTED",
        entity="activity",
        entity_id=str(assignment_id),
        actor=current_user,
        details={"project_id": str(doc.get("project_id") or "").strip().upper()},
    )


@router.post("/{assignment_id}/decline", status_code=status.HTTP_204_NO_CONTENT)
def decline_assignment(
    assignment_id: UUID,
    payload: AssignmentRespondRequest | None = None,
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
):
    """Decline a pending assignment, transfer, or co-responsable notification.

    Removes the current user from the activity's participant list and marks the
    notification as ``declined``.
    """
    client = get_firestore_client()
    activity_ref = client.collection("activities").document(str(assignment_id))
    snap = activity_ref.get()
    if not snap.exists:
        raise api_error(
            status_code=status.HTTP_404_NOT_FOUND,
            code="ASSIGNMENT_NOT_FOUND",
            message="Assignment not found",
        )

    doc = snap.to_dict() or {}
    current_user_id = str(getattr(current_user, "id", "")).strip()
    participant_user_ids = _normalized_participant_ids(doc)

    if current_user_id not in participant_user_ids:
        raise api_error(
            status_code=status.HTTP_409_CONFLICT,
            code="ASSIGNMENT_NOT_PARTICIPANT",
            message="You are not a participant of this activity",
        )

    # Use is_primary_responsible to distinguish the primary activity from a sibling.
    # Sibling activities have assigned_to_user_id = co-responsible, but is_primary_responsible = False.
    # Checking only assigned_to_user_id would incorrectly treat sibling declines as primary declines.
    is_primary_responsible = bool(doc.get("is_primary_responsible", True))
    is_primary_assignee = is_primary_responsible and _safe_uuid_str(doc.get("assigned_to_user_id")) == current_user_id
    is_sibling_activity = not is_primary_responsible
    activity_group_id = str(doc.get("activity_group_id") or "").strip()

    now = datetime.now(timezone.utc)
    next_sync_version = _next_project_sync_version(client, str(doc.get("project_id") or "").strip().upper())

    if is_sibling_activity:
        # Co-responsable declining their own sibling activity: cancel (soft-delete) the sibling
        # and remove them from the primary activity's participant list.
        activity_ref.set(
            {
                "execution_state": "CANCELADA",
                "deleted_at": now.isoformat(),
                "updated_at": now.isoformat(),
                "sync_version": next_sync_version,
                f"acceptance_by_{current_user_id}": "declined",
            },
            merge=True,
        )
        # Update the primary activity in the same group to remove current user from participants.
        if activity_group_id:
            try:
                primary_docs = list(
                    client.collection("activities")
                    .where("activity_group_id", "==", activity_group_id)
                    .where("is_primary_responsible", "==", True)
                    .limit(1)
                    .stream()
                )
                if primary_docs:
                    primary_ref = primary_docs[0].reference
                    primary_data = primary_docs[0].to_dict() or {}
                    primary_participants = _normalized_participant_ids(primary_data)
                    updated_primary_participants = [uid for uid in primary_participants if uid != current_user_id]
                    primary_sync_version = _next_project_sync_version(
                        client, str(primary_data.get("project_id") or "").strip().upper()
                    )
                    primary_ref.set(
                        {
                            "participant_user_ids": updated_primary_participants,
                            "updated_at": now.isoformat(),
                            "sync_version": primary_sync_version,
                        },
                        merge=True,
                    )
            except Exception:
                logger.warning(
                    "Could not update primary activity participant list for group %s", activity_group_id
                )
    elif is_primary_assignee:
        # Primary declining: soft-remove them, leave activity unassigned.
        updated_participant_ids = [uid for uid in participant_user_ids if uid != current_user_id]
        activity_ref.set(
            {
                "assigned_to_user_id": updated_participant_ids[0] if updated_participant_ids else None,
                "participant_user_ids": updated_participant_ids,
                "updated_at": now.isoformat(),
                "sync_version": next_sync_version,
                f"acceptance_by_{current_user_id}": "declined",
            },
            merge=True,
        )
    else:
        # Co-responsable declining (activity has is_primary_responsible=True but user is a participant).
        updated_participant_ids = [uid for uid in participant_user_ids if uid != current_user_id]
        activity_ref.set(
            {
                "participant_user_ids": updated_participant_ids,
                "updated_at": now.isoformat(),
                "sync_version": next_sync_version,
                f"acceptance_by_{current_user_id}": "declined",
            },
            merge=True,
        )

    # Update notification record.
    notif_id = (payload.notification_id or "").strip() if payload else ""
    if notif_id:
        update_notification_response(
            notification_id=notif_id,
            user_id=current_user_id,
            response="declined",
        )
    else:
        try:
            pending_notifs = list(
                client.collection("user_notifications")
                .where("recipient_user_id", "==", current_user_id)
                .where("activity_id", "==", str(assignment_id))
                .where("status", "==", "unread")
                .limit(5)
                .stream()
            )
            for n in pending_notifs:
                n.reference.set(
                    {"status": "declined", "responded_at": now.isoformat(), "read_at": now.isoformat()},
                    merge=True,
                )
        except Exception:
            logger.warning("Could not auto-resolve notifications for activity %s", assignment_id)

    write_firestore_audit_log(
        action="ASSIGNMENT_DECLINED",
        entity="activity",
        entity_id=str(assignment_id),
        actor=current_user,
        details={
            "project_id": str(doc.get("project_id") or "").strip().upper(),
            "was_primary_assignee": is_primary_assignee,
            "was_sibling_activity": is_sibling_activity,
        },
    )

