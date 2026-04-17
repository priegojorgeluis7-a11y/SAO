from datetime import datetime, timezone
import hashlib
import json
import logging

from fastapi import APIRouter, Depends, Query, status

from app.api.deps import require_any_role
from app.core.firestore import get_firestore_client
from app.core.utils import parse_firestore_dt
from typing import Any

_logger = logging.getLogger(__name__)

router = APIRouter(prefix="/reports", tags=["reports"])

_ALL_FRONTS = {"todos", "todo", "all", "*"}


def _parse_dt(value: object) -> datetime | None:
    return parse_firestore_dt(value)


def _report_dt(doc: dict) -> datetime | None:
    return (
        _parse_dt(doc.get("last_reviewed_at"))
        or _parse_dt(doc.get("updated_at"))
        or _parse_dt(doc.get("created_at"))
    )


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
    return "PENDING_REVIEW"


def _build_users_map(client) -> dict[str, str]:
    users_map: dict[str, str] = {}
    for doc in client.collection("users").stream():
        payload = doc.to_dict() or {}
        name = str(
            payload.get("display_name") or payload.get("name") or payload.get("email") or ""
        ).strip()
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
        name = str(payload.get("display_name") or payload.get("name") or payload.get("email") or "").strip()
        if name:
            result[user_id] = name
    return result


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
    _current_user: Any = Depends(require_any_role(["ADMIN", "SUPERVISOR", "COORD"])),
):
    client = get_firestore_client()

    front_raw = front.strip().lower() if front and front.strip() else None
    front_filter = None if front_raw in _ALL_FRONTS else front_raw
    project_filter = project_id.strip().upper() if project_id and project_id.strip() else None
    status_filter = status.strip().upper() if status and status.strip() else None

    query = client.collection("activities")
    if project_filter:
        query = query.where("project_id", "==", project_filter)
    docs = [d.to_dict() or {} for d in query.stream()]

    candidate_docs: list[dict[str, Any]] = []
    front_ids: set[str] = set()
    user_ids: set[str] = set()
    for doc in docs:
        if doc.get("deleted_at") is not None:
            continue
        if doc.get("report_generated_at") is not None and not include_already_reported:
            continue
        if project_filter and str(doc.get("project_id") or "").upper() != project_filter:
            continue
        if status_filter and str(doc.get("execution_state") or "") != status_filter:
            continue
        report_dt = _report_dt(doc)
        if date_from and (report_dt is None or report_dt < date_from):
            continue
        if date_to and (report_dt is None or report_dt > date_to):
            continue
        candidate_docs.append(doc)
        front_ids.add(str(doc.get("front_id") or "").strip())
        user_ids.add(str(doc.get("assigned_to_user_id") or "").strip())

    fronts_map = _load_front_names(client, front_ids)
    users_map = _load_user_names(client, user_ids)

    items: list[dict] = []
    for doc in candidate_docs:
        created_dt = _report_dt(doc)
        front_id = str(doc.get("front_id") or "")
        front_name = fronts_map.get(front_id, "")
        assigned_to_user_id = str(doc.get("assigned_to_user_id") or "").strip()
        review_decision = str(doc.get("review_decision") or "").upper() or None
        if front_filter and front_filter not in front_name.lower():
            continue
        items.append(
            {
                "id": str(doc.get("uuid") or ""),
                "project_id": str(doc.get("project_id") or ""),
                "activity_type": str(doc.get("activity_type_code") or ""),
                "title": str(doc.get("title") or "") or None,
                "pk": doc.get("pk_start"),
                "pk_start": doc.get("pk_start"),
                "pk_end": doc.get("pk_end"),
                "front": front_name,
                "municipality": str(doc.get("municipio") or doc.get("municipality") or "") or None,
                "state": str(doc.get("estado") or doc.get("state") or "") or None,
                "latitude": doc.get("latitude"),
                "longitude": doc.get("longitude"),
                "risk": _risk_from_activity(doc),
                "status": str(doc.get("execution_state") or ""),
                "review_decision": review_decision,
                "review_status": _review_status_from_activity(doc),
                "has_report": bool(doc.get("report_generated_at")),
                "assigned_to_user_id": assigned_to_user_id or None,
                "assigned_name": users_map.get(assigned_to_user_id, "") or None,
                "created_at": created_dt.isoformat() if created_dt else "",
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
