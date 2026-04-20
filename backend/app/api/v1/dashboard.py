from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.deps import (
    get_current_user,
    resolve_user_project_access,
    user_has_permission,
    verify_project_access,
)
from app.core.firestore import get_firestore_client
from typing import Any

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


def _normalize_review_decision(value: Any) -> str:
    normalized = str(value or "").strip().upper().replace(" ", "_")
    if normalized in {"APPROVE", "APPROVED", "APROBADO", "APROBADA"}:
        return "APPROVED"
    if normalized in {"REJECT", "REJECTED", "RECHAZADO", "RECHAZADA"}:
        return "REJECTED"
    if normalized in {"NEEDS_FIX", "CHANGES_REQUIRED", "NECESITA_CORRECCION"}:
        return "CHANGES_REQUIRED"
    if normalized in {"PENDING", "PENDIENTE", "PENDIENTE_REVISION", "EN_REVISION"}:
        return "PENDING_REVIEW"
    return normalized


def _empty_dashboard_payload(project_id: str | None, now: datetime) -> dict:
    return {
        "project_id": project_id.strip().upper() if project_id else "ALL",
        "generated_at": now.isoformat(),
        "kpis": {
            "total": 0,
            "pending_review": 0,
            "in_progress": 0,
            "completed": 0,
            "completed_today": 0,
        },
        "recent_items": [],
    }


def _dashboard_kpis_firestore(project_id: str | None, now: datetime, *, scoped_project_ids: list[str] | None = None) -> dict:
    """Compute dashboard KPIs from Firestore activities collection."""
    client = get_firestore_client()
    day_start = datetime(now.year, now.month, now.day, tzinfo=timezone.utc).isoformat()

    if scoped_project_ids is not None and not scoped_project_ids:
        return _empty_dashboard_payload(project_id, now)

    if scoped_project_ids is None:
        query = client.collection("activities")
        if project_id:
            query = query.where("project_id", "==", project_id.strip().upper())
        docs = list(query.stream())
    else:
        docs = []
        for scoped_project_id in scoped_project_ids:
            docs.extend(
                list(
                    client.collection("activities")
                    .where("project_id", "==", scoped_project_id)
                    .stream()
                )
            )
    pending_review = 0
    in_progress = 0
    completed = 0
    completed_today = 0
    total = 0
    recent_docs: list[dict] = []

    for doc in docs:
        payload = doc.to_dict() or {}
        if payload.get("deleted_at") is not None:
            continue
        total += 1
        state = str(payload.get("execution_state") or "").strip().upper()
        review_decision = _normalize_review_decision(
            payload.get("review_decision") or payload.get("review_status")
        )
        updated_at_raw = payload.get("updated_at")
        updated_at_str = updated_at_raw.isoformat() if hasattr(updated_at_raw, "isoformat") else str(updated_at_raw or "")

        if review_decision == "APPROVED" or state == "COMPLETADA":
            completed += 1
            if updated_at_str >= day_start:
                completed_today += 1
        elif review_decision == "REJECTED":
            pending_review += 0
        elif review_decision == "CHANGES_REQUIRED" or state == "EN_CURSO":
            in_progress += 1
        elif state == "REVISION_PENDIENTE":
            pending_review += 1

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
    _current_user: Any = Depends(get_current_user),
):
    now = datetime.now(timezone.utc)
    normalized_project_id = (project_id or "").strip().upper() or None

    if normalized_project_id is not None:
        verify_project_access(_current_user, normalized_project_id, None)
        if not user_has_permission(
            _current_user,
            "activity.view",
            None,
            project_id=normalized_project_id,
        ):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Missing permission: activity.view for project: {normalized_project_id}",
            )
        return _dashboard_kpis_firestore(
            normalized_project_id,
            now,
            scoped_project_ids=[normalized_project_id],
        )

    has_global_scope, allowed_project_ids = resolve_user_project_access(_current_user)
    if has_global_scope:
        return _dashboard_kpis_firestore(None, now, scoped_project_ids=None)

    scoped_project_ids = [
        project_id
        for project_id in sorted(allowed_project_ids)
        if user_has_permission(_current_user, "activity.view", None, project_id=project_id)
    ]
    return _dashboard_kpis_firestore(None, now, scoped_project_ids=scoped_project_ids)
