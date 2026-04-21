"""Completed Activities endpoint — read-only view of approved activities with full traceability."""

import json
import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from app.api.deps import require_any_role, user_has_permission, verify_project_access
from app.core.firestore import get_firestore_client

router = APIRouter(prefix="/completed-activities", tags=["completed-activities"])
logger = logging.getLogger(__name__)

_APPROVED_DECISIONS = {"APPROVE", "APPROVE_EXCEPTION"}

_VIEWER_ROLES = ["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO", "LECTOR"]
_WRITER_ROLES = ["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"]


class RelatedActivityLinkItem(BaseModel):
    activity_id: str
    relation_type: str = "seguimiento"
    status: str = "abierta"
    reason: str = ""
    next_action: str = ""
    due_date: str = ""
    created_at: str = ""
    created_by: str = ""


class RelatedActivityLinksPayload(BaseModel):
    related_activity_ids: list[str] = Field(default_factory=list)
    related_links: list[RelatedActivityLinkItem] = Field(default_factory=list)


def _pk_label(pk_start: Any, pk_end: Any) -> str:
    def _fmt(val: Any) -> str | None:
        try:
            n = int(val)
            return f"{n // 1000}+{n % 1000:03d}"
        except (TypeError, ValueError):
            return str(val) if val else None

    start = _fmt(pk_start)
    end   = _fmt(pk_end)
    if start is None:
        return ""
    if end is not None and pk_end != pk_start:
        return f"PK {start}-{end}"
    return f"PK {start}"


def _iso(val: Any) -> str:
    if isinstance(val, datetime):
        return val.isoformat()
    return str(val) if val else ""


def _normalize_action_token(action: Any) -> str:
    return str(action or "").strip().upper()


def _normalized_project_id(project_id: Any) -> str:
    return str(project_id or "").strip().upper()


def _user_can_access_completed_project(user: Any, project_id: Any) -> bool:
    normalized_project_id = _normalized_project_id(project_id)
    if not normalized_project_id:
        return False
    try:
        verify_project_access(user, normalized_project_id, None)
    except HTTPException:
        return False
    return user_has_permission(user, "activity.view", None, project_id=normalized_project_id)


def _require_completed_project_access(user: Any, project_id: Any, *, permission_code: str = "activity.view") -> str:
    normalized_project_id = _normalized_project_id(project_id)
    if not normalized_project_id:
        raise HTTPException(status_code=400, detail="project_id is required")

    verify_project_access(user, normalized_project_id, None)
    if not user_has_permission(user, permission_code, None, project_id=normalized_project_id):
        raise HTTPException(
            status_code=403,
            detail=f"Missing permission: {permission_code} for project: {normalized_project_id}",
        )
    return normalized_project_id


def _normalize_related_activity_ids(raw: Any, current_id: str = "") -> list[str]:
    if not isinstance(raw, list):
        return []

    normalized: list[str] = []
    seen: set[str] = set()
    current = str(current_id or "").strip()
    for item in raw:
        value = str(item or "").strip()
        if not value or value.lower() == "null" or value == current or value in seen:
            continue
        seen.add(value)
        normalized.append(value)
    return normalized


def _normalize_related_links(raw: Any, current_id: str = "") -> list[dict[str, Any]]:
    if not isinstance(raw, list):
        return []

    normalized: list[dict[str, Any]] = []
    seen: set[str] = set()
    current = str(current_id or "").strip()

    for item in raw:
        if isinstance(item, dict):
            activity_id = str(item.get("activity_id") or item.get("activityId") or "").strip()
            relation_type = str(item.get("relation_type") or item.get("relationType") or "seguimiento").strip() or "seguimiento"
            status = str(item.get("status") or "abierta").strip() or "abierta"
            reason = str(item.get("reason") or "").strip()
            next_action = str(item.get("next_action") or item.get("nextAction") or "").strip()
            due_date = str(item.get("due_date") or item.get("dueDate") or "").strip()
            created_at = str(item.get("created_at") or item.get("createdAt") or "").strip()
            created_by = str(item.get("created_by") or item.get("createdBy") or "").strip()
        else:
            activity_id = str(item or "").strip()
            relation_type = "seguimiento"
            status = "abierta"
            reason = ""
            next_action = ""
            due_date = ""
            created_at = ""
            created_by = ""

        if not activity_id or activity_id.lower() == "null" or activity_id == current or activity_id in seen:
            continue

        seen.add(activity_id)
        normalized.append(
            {
                "activity_id": activity_id,
                "relation_type": relation_type,
                "status": status,
                "reason": reason,
                "next_action": next_action,
                "due_date": due_date,
                "created_at": created_at,
                "created_by": created_by,
            }
        )

    return normalized


def _parse_log_details(log: dict[str, Any]) -> tuple[dict[str, Any], str]:
    details: dict[str, Any] = {}
    raw_details = log.get("details_json")
    if isinstance(raw_details, str) and raw_details.strip():
        try:
            decoded = json.loads(raw_details)
            if isinstance(decoded, dict):
                details = decoded
        except (TypeError, ValueError, json.JSONDecodeError):
            details = {}
    elif isinstance(raw_details, dict):
        details = {str(key): value for key, value in raw_details.items()}

    legacy_changes = log.get("changes")
    if isinstance(legacy_changes, dict):
        details = {**legacy_changes, **details}

    notes = str(
        details.get("message")
        or details.get("notes")
        or details.get("note")
        or log.get("notes")
        or log.get("comment")
        or ""
    ).strip()
    return details, notes


def _build_supplemental_audit_trail(
    doc: dict[str, Any],
    users_map: dict[str, str],
    assigned_name: str,
    reviewed_by_name: str,
    evidences: list[dict[str, Any]],
    documents: list[dict[str, Any]],
    existing_actions: set[str],
) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    has_create_event = any("CREATE" in action or "ASSIGN" in action for action in existing_actions)
    has_review_event = any(
        "REVIEW" in action or "APPROVE" in action or "REJECT" in action
        for action in existing_actions
    )
    has_report_event = any("REPORT" in action for action in existing_actions)
    has_evidence_event = any("EVIDENCE" in action for action in existing_actions)

    created_at = doc.get("created_at")
    created_by_uid = str(doc.get("created_by_user_id") or "").strip()
    if created_at and not has_create_event:
        actor_name = users_map.get(created_by_uid, "") or assigned_name
        entries.append(
            {
                "id": f"synthetic-create-{str(doc.get('uuid') or '')}",
                "action": "ACTIVITY_CREATED",
                "actor_email": "",
                "actor_name": actor_name,
                "changes": {},
                "notes": "Actividad registrada en expediente.",
                "timestamp": _iso(created_at),
            }
        )

    if evidences and not has_evidence_event:
        latest_evidence = max(evidences, key=lambda item: item.get("uploaded_at") or "")
        entries.append(
            {
                "id": f"synthetic-evidence-{latest_evidence.get('id') or 'latest'}",
                "action": "EVIDENCE_UPLOADED",
                "actor_email": "",
                "actor_name": str(latest_evidence.get("uploader_name") or assigned_name),
                "changes": {},
                "notes": str(latest_evidence.get("description") or "Evidencia agregada al expediente."),
                "timestamp": str(latest_evidence.get("uploaded_at") or ""),
            }
        )

    reviewed_at = doc.get("last_reviewed_at")
    review_decision = _normalize_action_token(doc.get("review_decision"))
    review_notes = str(doc.get("review_notes") or doc.get("rejection_reason") or "").strip()
    if reviewed_at and not has_review_event:
        review_action = "REVIEW_UPDATED"
        if review_decision in {"APPROVE", "APPROVE_EXCEPTION"}:
            review_action = "REVIEW_APPROVED"
        elif review_decision == "REJECT":
            review_action = "REVIEW_REJECTED"
        entries.append(
            {
                "id": f"synthetic-review-{str(doc.get('uuid') or '')}",
                "action": review_action,
                "actor_email": "",
                "actor_name": reviewed_by_name or assigned_name,
                "changes": {"review_decision": review_decision},
                "notes": review_notes or "Revisión registrada en expediente.",
                "timestamp": _iso(reviewed_at),
            }
        )

    report_generated_at = doc.get("report_generated_at")
    if documents and not has_report_event:
        latest_document = max(documents, key=lambda item: item.get("uploaded_at") or "")
        entries.append(
            {
                "id": f"synthetic-report-{latest_document.get('id') or 'latest'}",
                "action": "REPORT_GENERATE",
                "actor_email": "",
                "actor_name": str(latest_document.get("uploader_name") or reviewed_by_name or assigned_name),
                "changes": {},
                "notes": str(latest_document.get("description") or "Reporte operativo generado."),
                "timestamp": _iso(report_generated_at) or str(latest_document.get("uploaded_at") or ""),
            }
        )

    return [entry for entry in entries if entry.get("timestamp")]


def _effective_assignee_user_id(activity_payload: dict[str, Any]) -> str:
    return str(
        activity_payload.get("assigned_to_user_id")
        or activity_payload.get("created_by_user_id")
        or ""
    ).strip()


def _build_users_map(client, user_ids: set[str]) -> dict[str, str]:
    result: dict[str, str] = {}
    for user_id in user_ids:
        if not user_id:
            continue
        doc = client.collection("users").document(user_id).get()
        if not doc.exists:
            continue
        u = doc.to_dict() or {}
        name = str(
            u.get("full_name")
            or u.get("fullName")
            or u.get("display_name")
            or u.get("name")
            or u.get("email")
            or ""
        ).strip()
        if name:
            result[str(user_id)] = name
    return result


def _build_fronts_map(client, front_ids: set[str]) -> dict[str, dict[str, str]]:
    result: dict[str, dict[str, str]] = {}
    for front_id in front_ids:
        if not front_id:
            continue
        doc = client.collection("fronts").document(front_id).get()
        if not doc.exists:
            continue
        payload = doc.to_dict() or {}
        result[front_id] = {
            "name": str(payload.get("name") or ""),
            "code": str(payload.get("code") or ""),
        }
    return result


def _normalize_lookup_key(value: Any) -> str:
    return str(value or "").strip().lower()


def _load_project_front_scope_map(client, project_ids: set[str]) -> dict[str, dict[str, str]]:
    result: dict[str, dict[str, str]] = {}
    normalized_ids = [str(project_id or "").strip() for project_id in project_ids if str(project_id or "").strip()]
    if not normalized_ids:
        return result

    refs = [client.collection("projects").document(project_id) for project_id in normalized_ids]
    snapshots = client.get_all(refs) if hasattr(client, "get_all") else [ref.get() for ref in refs]
    for snap in snapshots:
        if not snap.exists:
            continue
        payload = snap.to_dict() or {}
        raw_scope = payload.get("front_location_scope") or payload.get("front_location_scopes") or []
        if not isinstance(raw_scope, list):
            continue

        project_scope: dict[str, str] = {}
        for row in raw_scope:
            if not isinstance(row, dict):
                continue
            municipality = str(row.get("municipio") or row.get("municipality") or "").strip()
            front_name = str(row.get("front_name") or row.get("frontName") or row.get("name") or "").strip()
            if municipality and front_name:
                project_scope[_normalize_lookup_key(municipality)] = front_name

        if project_scope:
            result[str(snap.id)] = project_scope
    return result


def _extract_activity_municipality(activity_payload: dict[str, Any]) -> str | None:
    municipality = str(
        activity_payload.get("municipio")
        or activity_payload.get("municipality")
        or ""
    ).strip()
    if municipality:
        return municipality

    wizard_payload = activity_payload.get("wizard_payload")
    if isinstance(wizard_payload, dict):
        location_payload = wizard_payload.get("location")
        if isinstance(location_payload, dict):
            municipality = str(
                location_payload.get("municipio")
                or location_payload.get("municipality")
                or ""
            ).strip()
            if municipality:
                return municipality
    return None


def _resolve_activity_front_name(
    activity_payload: dict[str, Any],
    front_names: dict[str, str],
    project_front_scope_map: dict[str, dict[str, str]],
) -> str | None:
    explicit_front = str(
        activity_payload.get("front")
        or activity_payload.get("front_name")
        or activity_payload.get("frente")
        or ""
    ).strip()
    if explicit_front:
        return explicit_front

    front_id = str(activity_payload.get("front_id") or "").strip()
    if front_id:
        front_name = str(front_names.get(front_id) or "").strip()
        if front_name:
            return front_name

    municipality = _extract_activity_municipality(activity_payload)
    project_id = str(activity_payload.get("project_id") or "").strip()
    if project_id and municipality:
        inferred_front = project_front_scope_map.get(project_id, {}).get(_normalize_lookup_key(municipality), "")
        if inferred_front:
            return inferred_front
    return None


def _is_document_evidence(evidence_payload: dict[str, Any]) -> bool:
    type_token = str(
        evidence_payload.get("evidence_type")
        or evidence_payload.get("type")
        or evidence_payload.get("mime_type")
        or ""
    ).strip().lower()
    gcs_path = str(
        evidence_payload.get("gcs_path")
        or evidence_payload.get("storage_path")
        or evidence_payload.get("object_path")
        or ""
    ).strip().lower()
    file_name = str(evidence_payload.get("original_file_name") or "").strip().lower()
    return (
        "pdf" in type_token
        or "document" in type_token
        or gcs_path.endswith(".pdf")
        or file_name.endswith(".pdf")
    )


def _evidence_count_map(client, activity_ids: set[str]) -> dict[str, int]:
    result: dict[str, int] = {}
    for activity_id in activity_ids:
        if not activity_id:
            continue
        count = 0
        for doc in client.collection("evidences").where("activity_id", "==", activity_id).stream():
            ev = doc.to_dict() or {}
            gcs_path = str(ev.get("gcs_path") or ev.get("storage_path") or ev.get("object_path") or "").strip()
            if gcs_path and not _is_document_evidence(ev):
                count += 1
        result[activity_id] = count
    return result


def _document_count_map(client, activity_ids: set[str]) -> dict[str, int]:
    result: dict[str, int] = {}
    for activity_id in activity_ids:
        if not activity_id:
            continue
        count = 0
        for doc in client.collection("evidences").where("activity_id", "==", activity_id).stream():
            ev = doc.to_dict() or {}
            gcs_path = str(ev.get("gcs_path") or ev.get("storage_path") or ev.get("object_path") or "").strip()
            if gcs_path and _is_document_evidence(ev):
                count += 1
        result[activity_id] = count
    return result


def _fetch_audit_logs_for_entity_ids(client, entity_ids: set[str]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    seen: set[str] = set()
    for entity_id in entity_ids:
        if not entity_id:
            continue
        for log_doc in (
            client.collection("audit_logs")
            .where("entity_id", "==", entity_id)
            .order_by("created_at", "DESCENDING")
            .limit(50)
            .stream()
        ):
            if log_doc.id in seen:
                continue
            seen.add(log_doc.id)
            rows.append({"id": str(log_doc.id), "payload": log_doc.to_dict() or {}})
    return rows


def _fetch_evidence_rows(client, activity_ids: set[str]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    seen: set[str] = set()
    for activity_id in activity_ids:
        if not activity_id:
            continue
        for ev_doc in client.collection("evidences").where("activity_id", "==", activity_id).stream():
            if ev_doc.id in seen:
                continue
            seen.add(ev_doc.id)
            rows.append({"id": str(ev_doc.id), "payload": ev_doc.to_dict() or {}})
    return rows


def _resolve_activity_doc_ref(client, activity_id: str):
    doc_ref = client.collection("activities").document(activity_id)
    snap = doc_ref.get()
    if snap.exists:
        return doc_ref, snap, snap.to_dict() or {}

    docs = list(
        client.collection("activities")
        .where("uuid", "==", activity_id)
        .limit(1)
        .stream()
    )
    if not docs:
        raise HTTPException(status_code=404, detail="Actividad no encontrada")
    snap = docs[0]
    return snap.reference, snap, snap.to_dict() or {}


def _resolve_uploader_name(
    evidence_payload: dict[str, Any],
    users_map: dict[str, str],
    uploader_uid: str,
) -> str:
    for key in (
        "uploader_name",
        "uploaded_by_name",
        "user_name",
        "actor_name",
        "created_by_name",
        "uploaded_by_email",
        "uploader_email",
        "created_by_email",
        "created_by_user_email",
    ):
        value = str(evidence_payload.get(key) or "").strip()
        if value:
            return value

    for candidate_uid in (
        uploader_uid,
        str(evidence_payload.get("uploaded_by") or "").strip(),
        str(evidence_payload.get("user_id") or "").strip(),
        str(evidence_payload.get("created_by") or "").strip(),
        str(evidence_payload.get("created_by_user_id") or "").strip(),
    ):
        if not candidate_uid:
            continue
        mapped_name = str(users_map.get(candidate_uid) or "").strip()
        if mapped_name:
            return mapped_name
        if "@" in candidate_uid:
            return candidate_uid

    return ""


# ─────────────────────────────────────────────────────────────────────────────
# GET /completed-activities  —  list
# ─────────────────────────────────────────────────────────────────────────────

@router.get("")
def list_completed_activities(
    project_id: str | None = Query(None),
    frente: str | None = Query(None),
    tema: str | None = Query(None),
    estado: str | None = Query(None),
    municipio: str | None = Query(None),
    usuario: str | None = Query(None, description="Filtrar por nombre del responsable (búsqueda parcial)"),
    q: str | None = Query(None, description="Búsqueda libre en título, PK y frente"),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    _current_user: Any = Depends(require_any_role(_VIEWER_ROLES)),
):
    """Returns approved activities with optional filters including responsible user."""
    client = get_firestore_client()

    # ── Normalise filters ─────────────────────────────────────────────────────
    project_filter  = project_id.strip().upper() if project_id and project_id.strip() else None
    if project_filter:
        project_filter = _require_completed_project_access(_current_user, project_filter)
    frente_filter   = frente.strip().lower()   if frente and frente.strip()   else None
    tema_filter     = tema.strip().upper()     if tema and tema.strip()       else None
    estado_filter   = estado.strip().lower()   if estado and estado.strip()   else None
    municipio_filter = municipio.strip().lower() if municipio and municipio.strip() else None
    usuario_filter  = usuario.strip().lower()  if usuario and usuario.strip() else None
    q_filter        = q.strip().lower()        if q and q.strip()            else None

    # ── Fetch + filter ────────────────────────────────────────────────────────
    query = client.collection("activities")
    if project_filter:
        query = query.where("project_id", "==", project_filter)
    raw_docs = [d.to_dict() or {} for d in query.stream()]

    candidate_docs: list[dict[str, Any]] = []
    front_ids: set[str] = set()
    project_ids: set[str] = set()
    user_ids: set[str] = set()
    for doc in raw_docs:
        if doc.get("deleted_at") is not None:
            continue
        if not _user_can_access_completed_project(_current_user, doc.get("project_id")):
            continue
        decision = str(doc.get("review_decision") or "").upper()
        if decision not in _APPROVED_DECISIONS:
            continue
        activity_id = str(doc.get("uuid") or "")
        if not activity_id:
            continue

        estado_val = str(doc.get("estado") or doc.get("state") or "")
        municipio_val = str(doc.get("municipio") or doc.get("municipality") or "")
        activity_type = str(doc.get("activity_type_code") or "")

        if tema_filter and activity_type.upper() != tema_filter:
            continue
        if estado_filter and estado_filter not in estado_val.lower():
            continue
        if municipio_filter and municipio_filter not in municipio_val.lower():
            continue

        candidate_docs.append(doc)
        front_ids.add(str(doc.get("front_id") or "").strip())
        project_ids.add(str(doc.get("project_id") or "").strip())
        user_ids.add(_effective_assignee_user_id(doc))
        user_ids.add(str(doc.get("last_reviewed_by") or "").strip())

    fronts_map = _build_fronts_map(client, front_ids)
    front_names = {
        front_id: str(payload.get("name") or "").strip()
        for front_id, payload in fronts_map.items()
    }
    project_front_scope_map = _load_project_front_scope_map(client, project_ids)
    users_map = _build_users_map(client, user_ids)

    items: list[dict] = []
    now = datetime.now(timezone.utc)

    for doc in candidate_docs:
        activity_id = str(doc.get("uuid") or "")

        # Resolve lookup values before filtering on them
        front_name = _resolve_activity_front_name(doc, front_names, project_front_scope_map) or ""

        assigned_uid  = _effective_assignee_user_id(doc)
        assigned_name = users_map.get(assigned_uid, "")

        estado_val   = str(doc.get("estado") or doc.get("state") or "")
        municipio_val = str(doc.get("municipio") or doc.get("municipality") or "")
        activity_type = str(doc.get("activity_type_code") or "")
        title         = str(doc.get("title") or activity_type or "")
        pk_label      = _pk_label(doc.get("pk_start"), doc.get("pk_end"))

        # Apply filters
        if frente_filter   and frente_filter   not in front_name.lower():        continue
        if usuario_filter  and usuario_filter  not in assigned_name.lower():     continue

        searchable = f"{pk_label} {title} {front_name} {activity_type}".lower()
        if q_filter and q_filter not in searchable:
            continue

        reviewer_uid = str(doc.get("last_reviewed_by") or "").strip()
        items.append({
            "id":               activity_id,
            "project_id":       str(doc.get("project_id") or ""),
            "title":            title,
            "activity_type":    activity_type,
            "pk":               pk_label,
            "front":            front_name,
            "estado":           estado_val,
            "municipio":        municipio_val,
            "has_report":       bool(doc.get("report_generated_at")),
            "reviewed_at":      _iso(doc.get("last_reviewed_at")),
            "created_at":       _iso(doc.get("created_at")),
            "evidence_count":   0,
            "document_count":   0,
            "assigned_name":    assigned_name,
            "reviewed_by_name": users_map.get(reviewer_uid, ""),
            "review_decision":  decision,
        })

    items.sort(key=lambda x: x["reviewed_at"] or x["created_at"], reverse=True)
    total = len(items)
    start = (page - 1) * page_size
    paged_items = items[start : start + page_size]
    activity_ids = {str(item["id"]) for item in paged_items}
    counts = _evidence_count_map(client, activity_ids)
    document_counts = _document_count_map(client, activity_ids)
    for item in paged_items:
        item["evidence_count"] = counts.get(str(item["id"]), 0)
        item["document_count"] = max(document_counts.get(str(item["id"]), 0), 1 if item.get("has_report") else 0)
        if item["document_count"] > 0:
            item["has_report"] = True

    return {
        "items":        paged_items,
        "total":        total,
        "page":         page,
        "page_size":    page_size,
        "has_next":     start + len(paged_items) < total,
        "generated_at": now.isoformat(),
    }


# ─────────────────────────────────────────────────────────────────────────────
# GET /completed-activities/filter-options  —  distinct values for dropdowns
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/filter-options")
def get_filter_options(
    project_id: str | None = Query(None),
    _current_user: Any = Depends(require_any_role(_VIEWER_ROLES)),
):
    """Returns distinct frentes, temas, estados, municipios and users
    from approved activities — scoped to project_id if provided."""
    client = get_firestore_client()

    project_filter = project_id.strip().upper() if project_id and project_id.strip() else None
    if project_filter:
        project_filter = _require_completed_project_access(_current_user, project_filter)

    query = client.collection("activities")
    if project_filter:
        query = query.where("project_id", "==", project_filter)

    frentes: set[str] = set()
    temas: set[str] = set()
    estados: set[str] = set()
    municipios: set[str] = set()
    usuarios: set[str] = set()

    docs: list[dict[str, Any]] = []
    front_ids: set[str] = set()
    project_ids: set[str] = set()
    user_ids: set[str] = set()

    for doc_snap in query.stream():
        doc = doc_snap.to_dict() or {}
        if doc.get("deleted_at") is not None:
            continue
        if not _user_can_access_completed_project(_current_user, doc.get("project_id")):
            continue
        decision = str(doc.get("review_decision") or "").upper()
        if decision not in _APPROVED_DECISIONS:
            continue

        docs.append(doc)
        front_ids.add(str(doc.get("front_id") or "").strip())
        project_ids.add(str(doc.get("project_id") or "").strip())
        user_ids.add(_effective_assignee_user_id(doc))

    users_map = _build_users_map(client, user_ids)
    fronts_map = {
        front_id: str(payload.get("name") or "").strip()
        for front_id, payload in _build_fronts_map(client, front_ids).items()
    }
    project_front_scope_map = _load_project_front_scope_map(client, project_ids)

    for doc in docs:

        front_name = _resolve_activity_front_name(doc, fronts_map, project_front_scope_map)
        if front_name:
            frentes.add(front_name)

        tipo = str(doc.get("activity_type_code") or "").strip()
        if tipo:
            temas.add(tipo)

        estado = str(doc.get("estado") or doc.get("state") or "").strip()
        if estado:
            estados.add(estado)

        municipio = str(doc.get("municipio") or doc.get("municipality") or "").strip()
        if municipio:
            municipios.add(municipio)

        assigned_uid = _effective_assignee_user_id(doc)
        name = users_map.get(assigned_uid, "").strip()
        if name:
            usuarios.add(name)

    return {
        "frentes":    sorted(frentes,    key=str.lower),
        "temas":      sorted(temas,      key=str.lower),
        "estados":    sorted(estados,    key=str.lower),
        "municipios": sorted(municipios, key=str.lower),
        "usuarios":   sorted(usuarios,   key=str.lower),
    }


# ─────────────────────────────────────────────────────────────────────────────
# GET /completed-activities/{activity_id}  —  full traceability detail
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/{activity_id}")
def get_completed_activity_detail(
    activity_id: str,
    _current_user: Any = Depends(require_any_role(_VIEWER_ROLES)),
):
    """Full traceability for a single completed activity: details + audit trail + evidences."""
    client = get_firestore_client()

    # ── Locate the activity doc ───────────────────────────────────────────────
    doc_ref, snap, doc = _resolve_activity_doc_ref(client, activity_id)
    resolved_id = str(doc.get("uuid") or snap.id)

    # ── Lookup maps ───────────────────────────────────────────────────────────
    front_lookup: dict[str, str] = {}
    front_id = str(doc.get("front_id") or "")
    if front_id:
        f_snap = client.collection("fronts").document(front_id).get()
        if f_snap.exists:
            f = f_snap.to_dict() or {}
            front_name = str(f.get("name") or "").strip()
            if front_name:
                front_lookup[front_id] = front_name
    project_id = _require_completed_project_access(_current_user, doc.get("project_id"))
    project_front_scope_map = _load_project_front_scope_map(client, {project_id} if project_id else set())
    front_name = _resolve_activity_front_name(doc, front_lookup, project_front_scope_map) or ""

    assigned_uid = _effective_assignee_user_id(doc)
    reviewer_uid = str(doc.get("last_reviewed_by") or "").strip()
    creator_uid = str(doc.get("created_by_user_id") or "").strip()
    users_map = _build_users_map(client, {assigned_uid, reviewer_uid, creator_uid})

    # ── Audit trail ───────────────────────────────────────────────────────────
    audit_trail: list[dict] = []
    for row in _fetch_audit_logs_for_entity_ids(client, {resolved_id, snap.id}):
        log = row["payload"]
        ts = log.get("timestamp") or log.get("created_at")
        changes, notes = _parse_log_details(log)
        actor_id = str(log.get("actor_id") or "").strip()
        actor_name = str(log.get("actor_name") or "").strip() or users_map.get(actor_id, "")
        audit_trail.append({
            "id":          row["id"],
            "action":      str(log.get("action") or ""),
            "actor_email": str(log.get("actor_email") or ""),
            "actor_name":  actor_name,
            "changes":     changes,
            "notes":       notes,
            "timestamp":   _iso(ts),
        })

    # ── Evidences / Documents ─────────────────────────────────────────────────
    evidences: list[dict] = []
    documents: list[dict] = []
    evidence_rows = _fetch_evidence_rows(client, {resolved_id, snap.id})
    uploader_ids = {
        str(
            row["payload"].get("uploaded_by")
            or row["payload"].get("user_id")
            or row["payload"].get("created_by")
            or row["payload"].get("created_by_user_id")
            or ""
        ).strip()
        for row in evidence_rows
    }
    users_map = _build_users_map(client, uploader_ids | {assigned_uid, reviewer_uid, creator_uid})
    for row in evidence_rows:
        ev = row["payload"]
        gcs_path = str(ev.get("gcs_path") or ev.get("storage_path") or ev.get("object_path") or "").strip()
        if not gcs_path:
            continue  # skip evidencias sin archivo adjunto
        ts = ev.get("uploaded_at") or ev.get("created_at")
        uploader_uid = str(
            ev.get("uploaded_by")
            or ev.get("user_id")
            or ev.get("created_by")
            or ev.get("created_by_user_id")
            or ""
        ).strip()
        entry = {
            "id":            row["id"],
            "type":          str(ev.get("evidence_type") or ev.get("type") or "PHOTO"),
            "description":   str(ev.get("description") or ev.get("caption") or ev.get("notes") or ""),
            "gcs_path":      gcs_path,
            "uploaded_at":   _iso(ts),
            "uploader_name": _resolve_uploader_name(ev, users_map, uploader_uid),
        }
        if _is_document_evidence(ev):
            documents.append(entry)
        else:
            evidences.append(entry)
    evidences.sort(key=lambda x: x["uploaded_at"], reverse=True)
    documents.sort(key=lambda x: x["uploaded_at"], reverse=True)

    existing_actions = {_normalize_action_token(entry.get("action")) for entry in audit_trail}
    audit_trail.extend(
        _build_supplemental_audit_trail(
            doc,
            users_map,
            users_map.get(assigned_uid, ""),
            users_map.get(reviewer_uid, ""),
            evidences,
            documents,
            existing_actions,
        )
    )
    audit_trail.sort(key=lambda x: x["timestamp"], reverse=True)

    # ── Build response ────────────────────────────────────────────────────────
    decision      = str(doc.get("review_decision") or "").upper()
    activity_type = str(doc.get("activity_type_code") or "")
    title         = str(doc.get("title") or activity_type or "")

    normalized_related_links = _normalize_related_links(
        doc.get("related_links") or doc.get("related_activity_ids"),
        resolved_id,
    )

    return {
        # List-compatible fields
        "id":               resolved_id,
        "project_id":       str(doc.get("project_id") or ""),
        "title":            title,
        "activity_type":    activity_type,
        "pk":               _pk_label(doc.get("pk_start"), doc.get("pk_end")),
        "front":            front_name,
        "estado":           str(doc.get("estado") or doc.get("state") or ""),
        "municipio":        str(doc.get("municipio") or doc.get("municipality") or ""),
        "has_report":       bool(doc.get("report_generated_at")) or bool(documents),
        "reviewed_at":      _iso(doc.get("last_reviewed_at")),
        "created_at":       _iso(doc.get("created_at")),
        "evidence_count":   len(evidences),
        "document_count":   len(documents),
        "assigned_name":    users_map.get(assigned_uid, ""),
        "reviewed_by_name": users_map.get(reviewer_uid, ""),
        "review_decision":  decision,
        # Detail-only fields
        "colonia":          str(doc.get("colonia") or ""),
        "review_notes":     str(doc.get("review_notes") or doc.get("rejection_reason") or ""),
        "data_fields":      doc.get("data_fields") or {},
        "related_activity_ids": [item["activity_id"] for item in normalized_related_links],
        "related_links":    normalized_related_links,
        "sync_version":     int(doc.get("sync_version") or 0),
        "audit_trail":      audit_trail,
        "evidences":        evidences,
        "documents":        documents,
    }


# ─────────────────────────────────────────────────────────────────────────────
# POST /completed-activities/{activity_id}/related-links
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/{activity_id}/related-links")
def save_related_links(
    activity_id: str,
    payload: RelatedActivityLinksPayload,
    _current_user: Any = Depends(require_any_role(_WRITER_ROLES)),
):
    """Persist manual links between related activities for expediente history."""
    client = get_firestore_client()
    now = datetime.now(timezone.utc)

    current_ref, current_snap, current_doc = _resolve_activity_doc_ref(client, activity_id)
    current_project_id = _require_completed_project_access(
        _current_user,
        current_doc.get("project_id"),
        permission_code="activity.edit",
    )
    current_id = str(current_doc.get("uuid") or current_snap.id)
    current_actor = str(
        getattr(_current_user, "full_name", "")
        or getattr(_current_user, "email", "")
        or ""
    ).strip()
    previous_links = _normalize_related_links(
        current_doc.get("related_links") or current_doc.get("related_activity_ids"),
        current_id,
    )
    previous_ids = {item["activity_id"] for item in previous_links}

    requested_payload = (
        [item.model_dump() for item in payload.related_links]
        if payload.related_links
        else payload.related_activity_ids
    )

    next_links: list[dict[str, Any]] = []
    seen: set[str] = set()
    resolved_refs: dict[str, Any] = {}
    for requested_link in _normalize_related_links(requested_payload, current_id):
        candidate_id = str(requested_link.get("activity_id") or "").strip()
        if not candidate_id or candidate_id == current_id or candidate_id in seen:
            continue
        try:
            target_ref, target_snap, target_doc = _resolve_activity_doc_ref(client, candidate_id)
        except HTTPException:
            continue
        if target_doc.get("deleted_at") is not None:
            continue
        if _normalized_project_id(target_doc.get("project_id")) != current_project_id:
            continue
        if not _user_can_access_completed_project(_current_user, target_doc.get("project_id")):
            continue
        resolved_target_id = str(target_doc.get("uuid") or target_snap.id)
        if not resolved_target_id or resolved_target_id == current_id or resolved_target_id in seen:
            continue

        seen.add(resolved_target_id)
        normalized_link = {
            **requested_link,
            "activity_id": resolved_target_id,
            "created_at": requested_link.get("created_at") or now.isoformat(),
            "created_by": requested_link.get("created_by") or current_actor,
        }
        next_links.append(normalized_link)
        resolved_refs[resolved_target_id] = (target_ref, target_doc, normalized_link)

    next_ids = [item["activity_id"] for item in next_links]
    current_ref.set(
        {
            "related_activity_ids": next_ids,
            "related_links": next_links,
            "updated_at": now,
        },
        merge=True,
    )

    removed_ids = previous_ids - set(next_ids)
    for removed_id in removed_ids:
        try:
            removed_ref, _removed_snap, removed_doc = _resolve_activity_doc_ref(client, removed_id)
        except HTTPException:
            continue
        existing_links = _normalize_related_links(
            removed_doc.get("related_links") or removed_doc.get("related_activity_ids"),
            removed_id,
        )
        remaining_links = [item for item in existing_links if item["activity_id"] != current_id]
        removed_ref.set(
            {
                "related_activity_ids": [item["activity_id"] for item in remaining_links],
                "related_links": remaining_links,
                "updated_at": now,
            },
            merge=True,
        )

    for target_id, (target_ref, target_doc, link_payload) in resolved_refs.items():
        existing_links = _normalize_related_links(
            target_doc.get("related_links") or target_doc.get("related_activity_ids"),
            target_id,
        )
        mirrored_link = {
            **link_payload,
            "activity_id": current_id,
        }
        existing_links = [item for item in existing_links if item["activity_id"] != current_id]
        existing_links.append(mirrored_link)
        target_ref.set(
            {
                "related_activity_ids": [item["activity_id"] for item in existing_links],
                "related_links": existing_links,
                "updated_at": now,
            },
            merge=True,
        )

    return {
        "ok": True,
        "related_activity_ids": next_ids,
        "related_links": next_links,
        "updated_at": now.isoformat(),
    }


# ─────────────────────────────────────────────────────────────────────────────
# POST /completed-activities/{activity_id}/mark-report-generated
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/{activity_id}/mark-report-generated")
def mark_report_generated(
    activity_id: str,
    _current_user: Any = Depends(require_any_role(_WRITER_ROLES)),
):
    """Mark that a PDF report has been generated for this activity."""
    client = get_firestore_client()
    now = datetime.now(timezone.utc)

    doc_ref, _snap, _doc = _resolve_activity_doc_ref(client, activity_id)
    _require_completed_project_access(
        _current_user,
        _doc.get("project_id"),
        permission_code="activity.edit",
    )

    doc_ref.set({"report_generated_at": now}, merge=True)
    return {"ok": True, "report_generated_at": now.isoformat()}
