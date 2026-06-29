from datetime import datetime, timezone
import hashlib
import json
import logging

from fastapi import APIRouter, Depends, Query, status

from app.api.deps import get_current_user, require_any_role, resolve_user_project_access
from app.core.firestore import get_firestore_client
from app.core.utils import parse_firestore_dt
from typing import Any

_logger = logging.getLogger(__name__)

router = APIRouter(prefix="/reports", tags=["reports"])

_ALL_FRONTS = {"todos", "todo", "all", "*"}


def _parse_dt(value: object) -> datetime | None:
    return parse_firestore_dt(value)


def _report_dt(doc: dict) -> datetime | None:
    # Use created_at as the primary date for filtering so that activities
    # are found regardless of when they were reviewed or when the PDF was generated.
    # This ensures that when a user selects a date range, all activities created
    # within that range are included, even if their updated_at has changed due to
    # report generation or other post-processing.
    return _parse_dt(doc.get("created_at"))


def _risk_from_activity(doc: dict) -> str:
    raw_risk = str(doc.get("risk") or "").strip().lower()
    if raw_risk in {"bajo", "medio", "alto", "prioritario"}:
        return raw_risk
    if bool(doc.get("gps_mismatch", False)):
        return "alto"
    if bool(doc.get("catalog_changed", False)):
        return "medio"
    return "bajo"


def _review_status_from_activity(doc: dict) -> str:
    decision = str(doc.get("review_decision") or "").upper()
    if decision == "REJECT":
        return "REJECTED"
    if decision in {"APPROVE", "APPROVE_EXCEPTION"}:
        return "APPROVED"
    if decision in {"CHANGES_REQUIRED", "REQUEST_CHANGES", "REQUIRES_CHANGES"}:
        return "CHANGES_REQUIRED"
    if str(doc.get("execution_state") or "") == "REVISION_PENDIENTE":
        return "PENDING_REVIEW"
    # Si la actividad está completada pero sin decisión de revisión, se considera
    # aprobada para efectos de generación de reportes (son actividades terminadas
    # que pueden generar PDF).
    if str(doc.get("execution_state") or "") == "COMPLETADA":
        return "APPROVED"
    return "NOT_REVIEWED"


def _name_from_email(raw: str) -> str:
    """Derive a display name from an email address or email-like string."""
    raw = raw.strip()
    if "@" not in raw:
        return raw
    local = raw.split("@")[0]
    for sep in (".", "_", "-", "+"):
        local = local.replace(sep, " ")
    return " ".join(word.capitalize() for word in local.split() if word)


def _sanitize_display_name(raw: str) -> str:
    """Always convert email-like strings to readable names, even when stored as display_name."""
    raw = raw.strip()
    return _name_from_email(raw) if raw else ""


def _build_users_map(client) -> dict[str, str]:
    users_map: dict[str, str] = {}
    for doc in client.collection("users").stream():
        payload = doc.to_dict() or {}
        raw_name = str(
            payload.get("full_name")
            or payload.get("fullName")
            or payload.get("display_name")
            or payload.get("name")
            or payload.get("email")
            or ""
        ).strip()
        name = _sanitize_display_name(raw_name)
        if name:
            users_map[str(doc.id)] = name
    return users_map


def _load_front_names(client, front_ids: set[str]) -> dict[str, str]:
    result: dict[str, str] = {}
    for front_id in front_ids:
        if not front_id:
            continue
        snap = client.collection("fronts").document(front_id).get()
        if not snap.exists:
            continue
        result[front_id] = str((snap.to_dict() or {}).get("name") or "")
    return result


def _load_user_names(client, user_ids: set[str]) -> dict[str, str]:
    if not user_ids:
        return {}
    result: dict[str, str] = {}
    for user_id in user_ids:
        if not user_id:
            continue
        snap = client.collection("users").document(user_id).get()
        if not snap.exists:
            continue
        payload = snap.to_dict() or {}
        raw_name = str(
            payload.get("full_name")
            or payload.get("fullName")
            or payload.get("display_name")
            or payload.get("name")
            or payload.get("email")
            or ""
        ).strip()
        name = _sanitize_display_name(raw_name)
        if name:
            result[user_id] = name
    return result


def _participant_user_ids(doc: dict[str, Any]) -> list[str]:
    values = doc.get("participant_user_ids")
    if isinstance(values, list):
        normalized: list[str] = []
        for value in values:
            candidate = str(value or "").strip()
            if candidate and candidate not in normalized:
                normalized.append(candidate)
        if normalized:
            return normalized
    fallback = str(doc.get("assigned_to_user_id") or "").strip()
    return [fallback] if fallback else []


@router.get("/activities")
def list_report_activities(
    project_id: str | None = Query(None),
    front: str | None = Query(None),
    date_from: datetime | None = Query(None),
    date_to: datetime | None = Query(None),
    status: str | None = Query(None),
    include_already_reported: bool = Query(False),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    _current_user: Any = Depends(require_any_role(["ADMIN", "SUPERVISOR", "COORD", "OPERATIVO", "LECTOR"])),
):
    client = get_firestore_client()

    front_raw = front.strip().lower() if front and front.strip() else None
    front_filter = None if front_raw in _ALL_FRONTS else front_raw
    project_filter = project_id.strip().upper() if project_id and project_id.strip() else None
    status_filter = status.strip().upper() if status and status.strip() else None

    # Resolve which projects this user can see
    has_global_scope, allowed_project_ids = resolve_user_project_access(_current_user)

    # OPERATIVO can only see activities assigned to them
    caller_roles = {str(r).strip().upper() for r in (getattr(_current_user, "roles", []) or [])}
    is_operativo = caller_roles == {"OPERATIVO"} or ("OPERATIVO" in caller_roles and "SUPERVISOR" not in caller_roles and "ADMIN" not in caller_roles)
    caller_user_id = str(_current_user.id)

    # OPTIMIZATION: Use indexed query instead of full table scan
    query = client.collection("activities")
    if project_filter:
        # Verify the requesting user has access to this specific project
        if not has_global_scope and project_filter not in allowed_project_ids:
            return {"items": [], "total": 0, "page": page, "page_size": page_size}
        query = query.where("project_id", "==", project_filter)
        
        # Add date range filters if provided to reduce document reads
        if date_from:
            query = query.where("created_at", ">=", date_from)
        if date_to:
            query = query.where("created_at", "<=", date_to)
        
        # Order by created_at DESC to use the new index efficiently
        query = query.order_by("created_at", direction="DESCENDING")
        
        # Apply pagination at Firestore level to reduce reads
        offset = (page - 1) * page_size
        query = query.limit(page_size).offset(offset)
    
    # Only execute query if we have a project filter (use indexed query)
    # For queries without project filter, use a more selective approach
    if project_filter:
        docs = [d.to_dict() or {} for d in query.stream()]
    else:
        # Without project filter, load all (legacy behavior, but with date limits if provided)
        base_query = client.collection("activities")
        if date_from:
            base_query = base_query.where("created_at", ">=", date_from)
        if date_to:
            base_query = base_query.where("created_at", "<=", date_to)
        base_query = base_query.order_by("created_at", direction="DESCENDING")
        
        # Limit initial fetch for non-filtered queries
        docs = [d.to_dict() or {} for d in base_query.limit(1000).stream()]

    # If no specific project requested, restrict to allowed projects for non-global users
    if not project_filter and not has_global_scope:
        docs = [d for d in docs if str(d.get("project_id") or "").upper() in allowed_project_ids]

    candidate_docs: list[dict[str, Any]] = []
    front_ids: set[str] = set()
    user_ids: set[str] = set()
    _APPROVED_DECISIONS = {"APPROVE", "APPROVE_EXCEPTION", "APPROVED"}
    for doc in docs:
        # Include activities that are:
        # 1. Already approved (review_decision in APPROVED_DECISIONS)
        # 2. OR completed but not yet reviewed (execution_state == COMPLETADA without review_decision)
        review_decision = str(doc.get("review_decision") or "").upper()
        execution_state = str(doc.get("execution_state") or "").upper()
        is_completed_not_reviewed = (
            execution_state == "COMPLETADA" 
            and review_decision not in {"APPROVE", "APPROVE_EXCEPTION", "APPROVED", "REJECTED", "CHANGES_REQUIRED"}
        )
        if review_decision not in _APPROVED_DECISIONS and not is_completed_not_reviewed:
            continue
        # OPERATIVO ownership guard: must also be a participant.
        if is_operativo:
            participant_user_ids = _participant_user_ids(doc)
            if caller_user_id not in participant_user_ids:
                continue
        if doc.get("deleted_at") is not None:
            continue
        if doc.get("report_generated_at") is not None and not include_already_reported:
            continue
        if project_filter and str(doc.get("project_id") or "").upper() != project_filter:
            continue
        if status_filter and str(doc.get("execution_state") or "") != status_filter:
            continue
        report_dt = _report_dt(doc)
        if date_from and report_dt is not None and report_dt < date_from:
            continue
        if date_to and report_dt is not None and report_dt > date_to:
            continue
        candidate_docs.append(doc)
        front_ids.add(str(doc.get("front_id") or "").strip())
        user_ids.add(str(doc.get("assigned_to_user_id") or "").strip())

    # Deduplicate multi-responsible activities: each activity_group counts as 1.
    # For new activities: use activity_group_id.
    # For legacy activities (no activity_group_id): use composite key.
    _seen_groups_list: set[str] = set()
    _seen_legacy_list: set[str] = set()
    _deduped_candidates: list = []
    for _cd in candidate_docs:
        _gid = str(_cd.get("activity_group_id") or "").strip()
        if _gid:
            if _gid in _seen_groups_list:
                continue
            _seen_groups_list.add(_gid)
        else:
            _start_at_list = str(_cd.get("assignment_start_at") or "").strip()
            if _start_at_list:
                _lk = "|".join([
                    str(_cd.get("project_id") or ""),
                    str(_cd.get("activity_type_code") or ""),
                    _start_at_list,
                    str(_cd.get("assignment_end_at") or ""),
                    str(_cd.get("created_by_user_id") or ""),
                    str(_cd.get("front_id") or ""),
                    str(_cd.get("pk_start") or ""),
                ])
                if _lk in _seen_legacy_list:
                    continue
                _seen_legacy_list.add(_lk)
        _deduped_candidates.append(_cd)
    candidate_docs = _deduped_candidates

    fronts_map = _load_front_names(client, front_ids)
    users_map = _load_user_names(client, user_ids)

    items: list[dict] = []
    for doc in candidate_docs:
        created_dt = _report_dt(doc)
        front_id = str(doc.get("front_id") or "")
        front_name = fronts_map.get(front_id, "") or str(doc.get("frente") or doc.get("front_name") or "").strip()
        assigned_to_user_id = str(doc.get("assigned_to_user_id") or "").strip()
        review_decision = str(doc.get("review_decision") or "").upper() or None
        if front_filter and front_filter not in front_name.lower():
            continue
        # Resolve result name from wizard_payload.result so clients receive the
        # human-readable text rather than just the catalog ID (e.g. "R01").
        _wp = doc.get("wizard_payload") or {}
        _wp = _wp if isinstance(_wp, dict) else {}
        _res = _wp.get("result") if isinstance(_wp, dict) else None
        if isinstance(_res, dict):
            _result_obj = _res
        elif isinstance(_res, str) and _res:
            _result_obj = {"id": _res, "name": _res}
        else:
            _result_obj = None

        # ── Municipio ─────────────────────────────────────────────────
        # Check top-level first, then wizard_payload.location, then wizard_payload itself
        _municipality = str(doc.get("municipio") or doc.get("municipality") or "").strip()
        if not _municipality:
            _loc = _wp.get("location") or {}
            if isinstance(_loc, dict):
                _municipality = str(_loc.get("municipio") or _loc.get("municipality") or "").strip()
        if not _municipality:
            _municipality = str(
                _wp.get("municipio") or _wp.get("municipality")
                or (_wp.get("context") or {}).get("municipio")
                or (_wp.get("context") or {}).get("municipality")
                or ""
            ).strip()

        # ── Estado ────────────────────────────────────────────────────
        _state = str(doc.get("estado") or doc.get("state") or "").strip()
        if not _state:
            _loc2 = _wp.get("location") or {}
            if isinstance(_loc2, dict):
                _state = str(_loc2.get("estado") or _loc2.get("state") or "").strip()
        if not _state:
            _state = str(
                _wp.get("estado") or _wp.get("state")
                or (_wp.get("context") or {}).get("estado")
                or ""
            ).strip()

        # ── Frente ────────────────────────────────────────────────────
        # wizard_payload.location.front_name is the canonical source
        if not front_name:
            _loc_f = _wp.get("location") or {}
            if isinstance(_loc_f, dict):
                front_name = str(
                    _loc_f.get("front_name") or _loc_f.get("frente") or _loc_f.get("front") or ""
                ).strip()
        if not front_name:
            front_name = str(
                _wp.get("front_name") or _wp.get("frente") or _wp.get("front")
                or (_wp.get("context") or {}).get("front_name")
                or (_wp.get("context") or {}).get("frente")
                or ""
            ).strip()

        # ── Subcategoría ──────────────────────────────────────────────
        # Check wizard_payload first, then top-level doc fields
        _raw_sub = (
            _wp.get("subcategory")
            or (_wp.get("context") or {}).get("subcategory")
            or _wp.get("subtipo")
            or (_wp.get("context") or {}).get("subtipo")
            or doc.get("subcategory")
            or doc.get("subcategoria")
            or doc.get("subtipo")
        )
        if isinstance(_raw_sub, dict):
            _sub_name = str(_raw_sub.get("name") or _raw_sub.get("id") or "").strip()
            _subcategory = None if not _sub_name or _sub_name.upper().startswith("CUSTOM_") else _sub_name
        elif isinstance(_raw_sub, str) and _raw_sub.strip():
            _s = _raw_sub.strip()
            _subcategory = None if _s.upper().startswith("CUSTOM_") else _s
        else:
            _subcategory = None

        # ── Temas tratados ────────────────────────────────────────────
        _raw_topics = _wp.get("topics") or _wp.get("temas") or _wp.get("temas_tratados")
        if isinstance(_raw_topics, list):
            def _topic_display_name(t):
                if isinstance(t, dict):
                    n = str(t.get("name") or t.get("label") or t.get("id") or "").strip()
                else:
                    n = str(t).strip()
                return "" if not n or n.upper().startswith("CUSTOM_") else n
            _topics = [n for t in _raw_topics if t for n in (_topic_display_name(t),) if n]
        elif isinstance(_raw_topics, str) and _raw_topics.strip():
            _topics = [t.strip() for t in _raw_topics.replace(";", ",").split(",") if t.strip() and not t.strip().upper().startswith("CUSTOM_")]
        else:
            _topics = []

        # ── Propósito ─────────────────────────────────────────────────
        _raw_purpose = _wp.get("purpose") or (_wp.get("context") or {}).get("purpose")
        if isinstance(_raw_purpose, dict):
            _pur_name = str(_raw_purpose.get("name") or _raw_purpose.get("id") or "").strip()
            _purpose = None if not _pur_name or _pur_name.upper().startswith("CUSTOM_") else _pur_name
        elif isinstance(_raw_purpose, str) and _raw_purpose.strip():
            _p = _raw_purpose.strip()
            _purpose = None if _p.upper().startswith("CUSTOM_") else _p
        else:
            _purpose = None

        # ── Desarrollo / Detalle ──────────────────────────────────────
        # wizard_payload.notes is what operatives fill in "Desarrollo / Notas".
        # Mirrors the Flutter normalizer that maps wizard_payload.notes → description.
        _detail = str(
            _wp.get("detail") or _wp.get("description") or _wp.get("descripcion")
            or _wp.get("minuta") or _wp.get("notes") or doc.get("description") or ""
        ).strip() or None

        # ── Notas / Minuta (campo "Desarrollo / Notas" del wizard) ───────
        # Mirrors the Flutter normalizer: wizard_payload.notes → data_fields.report_notes
        _df = doc.get("data_fields") or {}
        _df = _df if isinstance(_df, dict) else {}
        _notes = (
            str(_wp.get("notes") or "").strip()
            or str(_df.get("report_notes") or "").strip()
            or None
        )

        # ── Acuerdos ──────────────────────────────────────────────────
        _agreements = str(
            _wp.get("agreements") or _wp.get("acuerdos") or _wp.get("commitments") or ""
        ).strip() or None

        # Resolve a human-readable activity type label.
        # CUSTOM_ACT_* codes are internal IDs — use wizard_payload.activity.name
        # or the activity title instead so reports don't show raw IDs.
        _raw_type_code = str(doc.get("activity_type_code") or "").strip()
        if _raw_type_code.upper().startswith("CUSTOM_"):
            _wp_act = _wp.get("activity") if isinstance(_wp, dict) else None
            _act_name = (
                str((_wp_act or {}).get("name") or "").strip()
                if isinstance(_wp_act, dict)
                else ""
            )
            _activity_type_label = (
                _act_name
                or str(doc.get("title") or "").strip()
                or _raw_type_code
            )
        else:
            _activity_type_label = _raw_type_code

        items.append(
            {
                "id": str(doc.get("uuid") or ""),
                "project_id": str(doc.get("project_id") or ""),
                "activity_type": _activity_type_label,
                "title": str(doc.get("title") or "") or None,
                "pk": doc.get("pk_start"),
                "pk_start": doc.get("pk_start"),
                "pk_end": doc.get("pk_end"),
                "front": front_name,
                "municipality": _municipality or None,
                "state": _state or None,
                "latitude": doc.get("latitude"),
                "longitude": doc.get("longitude"),
                "risk": _risk_from_activity(doc),
                "risk_level": _risk_from_activity(doc),
                "subcategory": _subcategory,
                "topics": _topics,
                "purpose": _purpose,
                "detail": _detail,
                "notes": _notes,
                "agreements": _agreements,
                "status": str(doc.get("execution_state") or ""),
                "review_decision": review_decision,
                "review_status": _review_status_from_activity(doc),
                "has_report": bool(doc.get("report_generated_at")),
                "assigned_to_user_id": assigned_to_user_id or None,
                "assigned_name": users_map.get(assigned_to_user_id, "") or None,
                "created_at": created_dt.isoformat() if created_dt else "",
                "result": _result_obj,
            }
        )

    items.sort(key=lambda x: x["created_at"], reverse=True)
    total = len(items)
    start = (page - 1) * page_size
    items = items[start : start + page_size]

    return {
        "meta": {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "generated_by": str(_current_user.id),
            "total": total,
            "page": page,
            "page_size": page_size,
            "has_next": start + len(items) < total,
            "filters": {
                "project_id": project_id,
                "front": front,
                "date_from": date_from.isoformat() if date_from else None,
                "date_to": date_to.isoformat() if date_to else None,
                "status": status,
            },
        },
        "items": items,
    }


@router.post("/generate", status_code=status.HTTP_200_OK)
def generate_auditab_report(
    project_id: str = Query(..., min_length=1),
    date_from: str | None = Query(None),
    date_to: str | None = Query(None),
    status_filter: str | None = Query(None),
    front_id: str | None = Query(None),
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "LECTOR"])),
):
    """
    Generate auditable report with hash verification.
    
    Response includes hash for verification that backend data matches exported PDF/CSV.
    """
    try:
        client = get_firestore_client()
        now = datetime.now(timezone.utc)
        trace_id = f"report-{now.timestamp()}-{current_user.id}"

        project_id_upper = project_id.strip().upper()
        
        query = client.collection("activities").where("project_id", "==", project_id_upper)

        if status_filter:
            query = query.where("execution_state", "==", status_filter.strip().upper())

        if front_id:
            query = query.where("front_id", "==", front_id.strip())

        if date_from:
            query = query.where("created_at", ">=", date_from)
        if date_to:
            query = query.where("created_at", "<=", date_to)

        docs = list(query.stream())
        activities = [doc.to_dict() for doc in docs if doc.to_dict()]

        # Deduplicate multi-responsible activities: each activity_group counts as 1.
        # For new activities: use activity_group_id.
        # For legacy activities (no activity_group_id): use composite key.
        _seen_groups_gen: set[str] = set()
        _seen_legacy_gen: set[str] = set()
        _deduped_activities: list = []
        for _a in activities:
            _gid = str(_a.get("activity_group_id") or "").strip()
            if _gid:
                if _gid in _seen_groups_gen:
                    continue
                _seen_groups_gen.add(_gid)
            else:
                _start_at_gen = str(_a.get("assignment_start_at") or "").strip()
                if _start_at_gen:
                    _lkey = "|".join([
                        str(_a.get("project_id") or ""),
                        str(_a.get("activity_type_code") or ""),
                        _start_at_gen,
                        str(_a.get("assignment_end_at") or ""),
                        str(_a.get("created_by_user_id") or ""),
                        str(_a.get("front_id") or ""),
                        str(_a.get("pk_start") or ""),
                    ])
                    if _lkey in _seen_legacy_gen:
                        continue
                    _seen_legacy_gen.add(_lkey)
            _deduped_activities.append(_a)
        activities = _deduped_activities

        report_data = []
        for activity in activities:
            report_data.append({
                "uuid": activity.get("uuid"),
                "project_id": activity.get("project_id"),
                "execution_state": activity.get("execution_state"),
                "activity_type_code": activity.get("activity_type_code"),
                "title": activity.get("title"),
                "pk_start": activity.get("pk_start"),
                "created_at": activity.get("created_at"),
                "assigned_to_user_id": activity.get("assigned_to_user_id"),
            })

        # Compute hash for verification
        hashable_content = json.dumps(
            {
                "data": report_data,
                "generated_at": now.isoformat(),
                "generated_by": str(current_user.id),
                "filters": {
                    "project_id": project_id_upper,
                    "date_from": date_from,
                    "date_to": date_to,
                    "status_filter": status_filter,
                    "front_id": front_id,
                },
            },
            sort_keys=True,
        )
        report_hash = hashlib.sha256(hashable_content.encode()).hexdigest()

        # Audit log
        write_firestore_audit_log(
            action="REPORT_GENERATE",
            entity="report",
            entity_id=trace_id,
            actor=current_user,
            details={
                "project_id": project_id_upper,
                "generated_at": now.isoformat(),
                "report_hash": report_hash,
                "activity_count": len(report_data),
                "generated_by_user_id": str(current_user.id),
                "generated_by_name": current_user.full_name,
            },
        )

        _logger.info(f"Report generated: project={project_id_upper}, activities={len(report_data)}, hash={report_hash[:16]}...")

        return {
            "trace_id": trace_id,
            "generated_at": now.isoformat(),
            "generated_by_user_id": str(current_user.id),
            "project_id": project_id_upper,
            "data": report_data,
            "count": len(report_data),
            "hash": report_hash,
            "hash_algorithm": "SHA256",
        }

    except Exception as e:
        _logger.error(f"Error generating report: {e}")
        raise
