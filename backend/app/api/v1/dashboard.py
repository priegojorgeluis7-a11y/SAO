from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query

from app.api.deps import require_any_role
from app.core.firestore import get_firestore_client
from typing import Any

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


def _dashboard_kpis_firestore(project_id: str | None, now: datetime) -> dict:
    """Compute dashboard KPIs from Firestore activities collection."""
    client = get_firestore_client()
    day_start = datetime(now.year, now.month, now.day, tzinfo=timezone.utc).isoformat()

    query = client.collection("activities")
    if project_id:
        query = query.where("project_id", "==", project_id.strip().upper())

    docs = list(query.stream())
    total = len(docs)
    pending_review = 0
    in_progress = 0
    completed = 0
    completed_today = 0
    recent_docs: list[dict] = []

    for doc in docs:
        payload = doc.to_dict() or {}
        if payload.get("deleted_at") is not None:
            continue
        state = str(payload.get("execution_state") or "")
        updated_at_raw = payload.get("updated_at")
        updated_at_str = updated_at_raw.isoformat() if hasattr(updated_at_raw, "isoformat") else str(updated_at_raw or "")

        if state == "REVISION_PENDIENTE":
            pending_review += 1
        elif state == "EN_CURSO":
            in_progress += 1
        elif state == "COMPLETADA":
            completed += 1
            if updated_at_str >= day_start:
                completed_today += 1

        recent_docs.append({
            "id": str(payload.get("uuid") or doc.id),
            "activity_type": str(payload.get("activity_type_code") or ""),
            "pk": payload.get("pk_start"),
            "front": "",
            "status": state,
            "created_at": str(payload.get("created_at") or ""),
            "project_id": str(payload.get("project_id") or ""),
            "updated_at_str": updated_at_str,
        })

    recent_docs.sort(key=lambda x: x["updated_at_str"], reverse=True)
    recent_items = [
        {k: v for k, v in item.items() if k != "updated_at_str"}
        for item in recent_docs[:5]
    ]

    return {
        "project_id": project_id.strip().upper() if project_id else "ALL",
        "generated_at": now.isoformat(),
        "kpis": {
            "total": total,
            "pending_review": pending_review,
            "in_progress": in_progress,
            "completed": completed,
            "completed_today": completed_today,
        },
        "recent_items": recent_items,
    }


@router.get("/kpis")
def get_dashboard_kpis(
    project_id: str | None = Query(None),
    _current_user: Any = Depends(require_any_role(["ADMIN", "SUPERVISOR", "COORD"])),
):
    now = datetime.now(timezone.utc)
    return _dashboard_kpis_firestore(project_id, now)
