"""Completed Activities endpoint — read-only view of approved activities with full traceability."""

import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query

from app.api.deps import require_any_role
from app.core.firestore import get_firestore_client

router = APIRouter(prefix="/completed-activities", tags=["completed-activities"])
logger = logging.getLogger(__name__)

_APPROVED_DECISIONS = {"APPROVE", "APPROVE_EXCEPTION"}

_VIEWER_ROLES = ["ADMIN", "COORD", "SUPERVISOR", "LECTOR"]
_WRITER_ROLES = ["ADMIN", "COORD", "SUPERVISOR"]


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
    explicit_front = str(activity_payload.get("front") or activity_payload.get("front_name") or "").strip()
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


def _evidence_count_map(client, activity_ids: set[str]) -> dict[str, int]:
    result: dict[str, int] = {}
    for activity_id in activity_ids:
        if not activity_id:
            continue
        result[activity_id] = sum(
            1
            for _ in client.collection("evidences")
            .where("activity_id", "==", activity_id)
            .stream()
        )
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
            "assigned_name":    assigned_name,
            "reviewed_by_name": users_map.get(reviewer_uid, ""),
            "review_decision":  decision,
        })

    items.sort(key=lambda x: x["reviewed_at"] or x["created_at"], reverse=True)
    total = len(items)
    start = (page - 1) * page_size
    paged_items = items[start : start + page_size]
    counts = _evidence_count_map(client, {str(item["id"]) for item in paged_items})
    for item in paged_items:
        item["evidence_count"] = counts.get(str(item["id"]), 0)

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
    doc_ref = client.collection("activities").document(activity_id)
    snap = doc_ref.get()
    if not snap.exists:
        docs = list(
            client.collection("activities")
            .where("uuid", "==", activity_id)
            .limit(1)
            .stream()
        )
        if not docs:
            raise HTTPException(status_code=404, detail="Actividad no encontrada")
        snap = docs[0]

    doc = snap.to_dict() or {}
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
    project_id = str(doc.get("project_id") or "").strip()
    project_front_scope_map = _load_project_front_scope_map(client, {project_id} if project_id else set())
    front_name = _resolve_activity_front_name(doc, front_lookup, project_front_scope_map) or ""

    # ── Audit trail ───────────────────────────────────────────────────────────
    audit_trail: list[dict] = []
    for row in _fetch_audit_logs_for_entity_ids(client, {resolved_id, snap.id}):
        log = row["payload"]
        ts = log.get("timestamp") or log.get("created_at")
        audit_trail.append({
            "id":          row["id"],
            "action":      str(log.get("action") or ""),
            "actor_email": str(log.get("actor_email") or ""),
            "actor_name":  str(log.get("actor_name") or ""),
            "changes":     log.get("changes") or {},
            "notes":       str(log.get("notes") or log.get("comment") or ""),
            "timestamp":   _iso(ts),
        })
    audit_trail.sort(key=lambda x: x["timestamp"], reverse=True)

    # ── Evidences ─────────────────────────────────────────────────────────────
    evidences: list[dict] = []
    evidence_rows = _fetch_evidence_rows(client, {resolved_id, snap.id})
    uploader_ids = {
        str(row["payload"].get("uploaded_by") or row["payload"].get("user_id") or "").strip()
        for row in evidence_rows
    }
    assigned_uid  = _effective_assignee_user_id(doc)
    reviewer_uid  = str(doc.get("last_reviewed_by") or "").strip()
    users_map = _build_users_map(client, uploader_ids | {assigned_uid, reviewer_uid})
    for row in evidence_rows:
        ev = row["payload"]
        ts = ev.get("uploaded_at") or ev.get("created_at")
        uploader_uid = str(ev.get("uploaded_by") or ev.get("user_id") or "")
        evidences.append({
            "id":            row["id"],
            "type":          str(ev.get("evidence_type") or ev.get("type") or "PHOTO"),
            "description":   str(ev.get("description") or ev.get("caption") or ev.get("notes") or ""),
            "gcs_path":      str(ev.get("gcs_path") or ev.get("storage_path") or ev.get("object_path") or ""),
            "uploaded_at":   _iso(ts),
            "uploader_name": users_map.get(uploader_uid, ""),
        })
    evidences.sort(key=lambda x: x["uploaded_at"], reverse=True)

    # ── Build response ────────────────────────────────────────────────────────
    decision      = str(doc.get("review_decision") or "").upper()
    activity_type = str(doc.get("activity_type_code") or "")
    title         = str(doc.get("title") or activity_type or "")

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
        "has_report":       bool(doc.get("report_generated_at")),
        "reviewed_at":      _iso(doc.get("last_reviewed_at")),
        "created_at":       _iso(doc.get("created_at")),
        "evidence_count":   len(evidences),
        "assigned_name":    users_map.get(assigned_uid, ""),
        "reviewed_by_name": users_map.get(reviewer_uid, ""),
        "review_decision":  decision,
        # Detail-only fields
        "colonia":          str(doc.get("colonia") or ""),
        "review_notes":     str(doc.get("review_notes") or doc.get("rejection_reason") or ""),
        "data_fields":      doc.get("data_fields") or {},
        "sync_version":     int(doc.get("sync_version") or 0),
        "audit_trail":      audit_trail,
        "evidences":        evidences,
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

    doc_ref = client.collection("activities").document(activity_id)
    snap = doc_ref.get()
    if not snap.exists:
        docs = list(
            client.collection("activities")
            .where("uuid", "==", activity_id)
            .limit(1)
            .stream()
        )
        if not docs:
            raise HTTPException(status_code=404, detail="Actividad no encontrada")
        doc_ref = docs[0].reference

    doc_ref.set({"report_generated_at": now}, merge=True)
    return {"ok": True, "report_generated_at": now.isoformat()}
