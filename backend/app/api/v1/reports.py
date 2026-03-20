from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query

from app.api.deps import require_any_role
from app.core.firestore import get_firestore_client
from typing import Any

router = APIRouter(prefix="/reports", tags=["reports"])


def _parse_dt(value: object) -> datetime | None:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if isinstance(value, str):
        raw = value.strip()
        if not raw:
            return None
        if raw.endswith("Z"):
            raw = raw[:-1] + "+00:00"
        try:
            parsed = datetime.fromisoformat(raw)
            return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
        except ValueError:
            return None
    return None


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
        return "RECHAZADO"
    if decision in {"APPROVE", "APPROVE_EXCEPTION"}:
        return "APROBADO"
    if str(doc.get("execution_state") or "") == "REVISION_PENDIENTE":
        return "PENDIENTE_REVISION"
    return "PENDIENTE_REVISION"


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


@router.get("/activities")
def list_report_activities(
    project_id: str | None = Query(None),
    front: str | None = Query(None),
    date_from: datetime | None = Query(None),
    date_to: datetime | None = Query(None),
    status: str | None = Query(None),
    _current_user: Any = Depends(require_any_role(["ADMIN", "SUPERVISOR", "COORD"])),
):
    client = get_firestore_client()

    # Build front_id -> name lookup from Firestore fronts collection
    fronts_map: dict[str, str] = {}
    for doc in client.collection("fronts").stream():
        d = doc.to_dict() or {}
        fid = str(d.get("id") or doc.id)
        fronts_map[fid] = str(d.get("name") or "")
    users_map = _build_users_map(client)

    docs = [d.to_dict() or {} for d in client.collection("activities").stream()]

    front_filter = front.strip().lower() if front and front.strip() else None
    project_filter = project_id.strip().upper() if project_id and project_id.strip() else None
    status_filter = status.strip().upper() if status and status.strip() else None

    items: list[dict] = []
    for doc in docs:
        if doc.get("deleted_at") is not None:
            continue
        if project_filter and str(doc.get("project_id") or "").upper() != project_filter:
            continue
        if status_filter and str(doc.get("execution_state") or "") != status_filter:
            continue
        created_dt = _parse_dt(doc.get("created_at"))
        if date_from and (created_dt is None or created_dt < date_from):
            continue
        if date_to and (created_dt is None or created_dt > date_to):
            continue
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
                "assigned_to_user_id": assigned_to_user_id or None,
                "assigned_name": users_map.get(assigned_to_user_id, "") or None,
                "created_at": created_dt.isoformat() if created_dt else "",
            }
        )

    items.sort(key=lambda x: x["created_at"], reverse=True)
    items = items[:1000]

    return {
        "meta": {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "generated_by": str(_current_user.id),
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
