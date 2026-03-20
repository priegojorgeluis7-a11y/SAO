"""Completed Activities endpoint — read-only view of APROBADO activities with full traceability."""

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


def _build_users_map(client) -> dict[str, str]:
    result: dict[str, str] = {}
    for doc in client.collection("users").stream():
        u = doc.to_dict() or {}
        name = str(
            u.get("display_name") or u.get("name") or u.get("email") or ""
        ).strip()
        if name:
            result[str(doc.id)] = name
    return result


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
    _current_user: Any = Depends(require_any_role(_VIEWER_ROLES)),
):
    """Returns approved activities with optional filters including responsible user."""
    client = get_firestore_client()

    # ── Build lookup maps ─────────────────────────────────────────────────────
    fronts_map: dict[str, dict] = {}
    for doc in client.collection("fronts").stream():
        d = doc.to_dict() or {}
        fid = str(d.get("id") or doc.id)
        fronts_map[fid] = {
            "name": str(d.get("name") or ""),
            "code": str(d.get("code") or ""),
        }

    users_map = _build_users_map(client)

    evidence_count_map: dict[str, int] = {}
    for doc in client.collection("evidences").stream():
        ev = doc.to_dict() or {}
        aid = str(ev.get("activity_id") or "")
        if aid:
            evidence_count_map[aid] = evidence_count_map.get(aid, 0) + 1

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

    items: list[dict] = []
    now = datetime.now(timezone.utc)

    for doc in raw_docs:
        if doc.get("deleted_at") is not None:
            continue
        decision = str(doc.get("review_decision") or "").upper()
        if decision not in _APPROVED_DECISIONS:
            continue
        activity_id = str(doc.get("uuid") or "")
        if not activity_id:
            continue

        # Resolve lookup values before filtering on them
        front_id    = str(doc.get("front_id") or "")
        front_info  = fronts_map.get(front_id, {})
        front_name  = front_info.get("name", "")

        assigned_uid  = str(doc.get("assigned_to_user_id") or "").strip()
        assigned_name = users_map.get(assigned_uid, "")

        estado_val   = str(doc.get("estado") or doc.get("state") or "")
        municipio_val = str(doc.get("municipio") or doc.get("municipality") or "")
        activity_type = str(doc.get("activity_type_code") or "")
        title         = str(doc.get("title") or activity_type or "")
        pk_label      = _pk_label(doc.get("pk_start"), doc.get("pk_end"))

        # Apply filters
        if frente_filter   and frente_filter   not in front_name.lower():        continue
        if tema_filter     and activity_type.upper() != tema_filter:             continue
        if estado_filter   and estado_filter   not in estado_val.lower():        continue
        if municipio_filter and municipio_filter not in municipio_val.lower():   continue
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
            "evidence_count":   evidence_count_map.get(activity_id, 0),
            "assigned_name":    assigned_name,
            "reviewed_by_name": users_map.get(reviewer_uid, ""),
            "review_decision":  decision,
        })

    items.sort(key=lambda x: x["reviewed_at"] or x["created_at"], reverse=True)

    return {
        "items":        items[:2000],
        "total":        len(items),
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

    users_map = _build_users_map(client)

    fronts_map: dict[str, str] = {}
    for doc in client.collection("fronts").stream():
        d = doc.to_dict() or {}
        fid = str(d.get("id") or doc.id)
        name = str(d.get("name") or "").strip()
        if name:
            fronts_map[fid] = name

    project_filter = project_id.strip().upper() if project_id and project_id.strip() else None

    query = client.collection("activities")
    if project_filter:
        query = query.where("project_id", "==", project_filter)

    frentes: set[str] = set()
    temas: set[str] = set()
    estados: set[str] = set()
    municipios: set[str] = set()
    usuarios: set[str] = set()

    for doc_snap in query.stream():
        doc = doc_snap.to_dict() or {}
        if doc.get("deleted_at") is not None:
            continue
        decision = str(doc.get("review_decision") or "").upper()
        if decision not in _APPROVED_DECISIONS:
            continue

        front_id = str(doc.get("front_id") or "")
        if front_id and fronts_map.get(front_id):
            frentes.add(fronts_map[front_id])

        tipo = str(doc.get("activity_type_code") or "").strip()
        if tipo:
            temas.add(tipo)

        estado = str(doc.get("estado") or doc.get("state") or "").strip()
        if estado:
            estados.add(estado)

        municipio = str(doc.get("municipio") or doc.get("municipality") or "").strip()
        if municipio:
            municipios.add(municipio)

        assigned_uid = str(doc.get("assigned_to_user_id") or "").strip()
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
    users_map = _build_users_map(client)

    front_name = ""
    front_id = str(doc.get("front_id") or "")
    if front_id:
        f_snap = client.collection("fronts").document(front_id).get()
        if f_snap.exists:
            f = f_snap.to_dict() or {}
            front_name = str(f.get("name") or "")

    # ── Audit trail ───────────────────────────────────────────────────────────
    audit_trail: list[dict] = []
    for log_doc in client.collection("audit_logs").stream():
        log = log_doc.to_dict() or {}
        entity_id = str(log.get("entity_id") or "")
        if entity_id != resolved_id and entity_id != snap.id:
            continue
        ts = log.get("timestamp") or log.get("created_at")
        audit_trail.append({
            "id":          str(log_doc.id),
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
    for ev_doc in client.collection("evidences").stream():
        ev = ev_doc.to_dict() or {}
        aid = str(ev.get("activity_id") or "")
        if aid not in (resolved_id, snap.id):
            continue
        ts = ev.get("uploaded_at") or ev.get("created_at")
        uploader_uid = str(ev.get("uploaded_by") or ev.get("user_id") or "")
        evidences.append({
            "id":            str(ev_doc.id),
            "type":          str(ev.get("evidence_type") or ev.get("type") or "PHOTO"),
            "description":   str(ev.get("description") or ""),
            "gcs_path":      str(ev.get("gcs_path") or ev.get("storage_path") or ""),
            "uploaded_at":   _iso(ts),
            "uploader_name": users_map.get(uploader_uid, ""),
        })
    evidences.sort(key=lambda x: x["uploaded_at"], reverse=True)

    # ── Build response ────────────────────────────────────────────────────────
    assigned_uid  = str(doc.get("assigned_to_user_id") or "").strip()
    reviewer_uid  = str(doc.get("last_reviewed_by") or "").strip()
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
