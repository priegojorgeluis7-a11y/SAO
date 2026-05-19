"""Catalog candidates API — custom items proposed by operatives that require admin approval."""

import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, Query, status

from app.api.deps import get_current_user, user_has_permission
from app.core.api_errors import api_error
from app.core.firestore import get_firestore_client

router = APIRouter(prefix="/catalog", tags=["catalog-candidates"])
logger = logging.getLogger(__name__)

_CANDIDATE_TYPES = {"activity", "subcategory", "purpose", "result", "topic", "attendee"}
_ALLOWED_STATUSES = {"pending", "approved", "rejected"}


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _require_catalog_edit(current_user: Any, db: Any) -> None:
    if not user_has_permission(current_user, "catalog.edit", db):
        raise api_error(
            status_code=status.HTTP_403_FORBIDDEN,
            code="AUTH_MISSING_PERMISSION",
            message="Se requiere permiso catalog.edit",
        )


def _candidate_to_dict(doc_id: str, data: dict) -> dict:
    return {
        "id": doc_id,
        "custom_id": str(data.get("custom_id") or ""),
        "type": str(data.get("type") or ""),
        "name": str(data.get("name") or ""),
        "project_id": str(data.get("project_id") or ""),
        "proposed_by_user_id": str(data.get("proposed_by_user_id") or ""),
        "activity_id": str(data.get("activity_id") or ""),
        "status": str(data.get("status") or "pending"),
        "proposed_at": (data.get("proposed_at") or "").isoformat()
        if hasattr(data.get("proposed_at"), "isoformat")
        else str(data.get("proposed_at") or ""),
        "last_seen_at": (data.get("last_seen_at") or "").isoformat()
        if hasattr(data.get("last_seen_at"), "isoformat")
        else str(data.get("last_seen_at") or ""),
        "reviewed_at": (data.get("reviewed_at") or "").isoformat()
        if data.get("reviewed_at") and hasattr(data.get("reviewed_at"), "isoformat")
        else (str(data.get("reviewed_at")) if data.get("reviewed_at") else None),
        "reviewed_by_user_id": data.get("reviewed_by_user_id"),
        "review_comment": data.get("review_comment"),
    }


# ---------------------------------------------------------------------------
# GET /catalog/candidates
# ---------------------------------------------------------------------------

@router.get("/candidates")
def list_catalog_candidates(
    project_id: str = Query(..., description="ID del proyecto"),
    candidate_status: str = Query("pending", alias="status", description="pending | approved | rejected"),
    current_user: Any = Depends(get_current_user),
    db: Any = Depends(get_firestore_client),
):
    """Lista los candidatos de ítems custom pendientes de aprobación (requiere catalog.edit)."""
    _require_catalog_edit(current_user, db)

    if candidate_status not in _ALLOWED_STATUSES:
        raise api_error(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="INVALID_STATUS",
            message=f"status debe ser uno de: {', '.join(sorted(_ALLOWED_STATUSES))}",
        )

    client = get_firestore_client()
    query = (
        client.collection("catalog_candidates")
        .where("project_id", "==", project_id)
        .where("status", "==", candidate_status)
        .order_by("proposed_at")
    )
    docs = list(query.stream())
    return [_candidate_to_dict(doc.id, doc.to_dict() or {}) for doc in docs]


# ---------------------------------------------------------------------------
# POST /catalog/candidates/{candidate_id}/approve
# ---------------------------------------------------------------------------

@router.post("/candidates/{candidate_id}/approve", status_code=status.HTTP_200_OK)
def approve_catalog_candidate(
    candidate_id: str,
    comment: str | None = None,
    current_user: Any = Depends(get_current_user),
    db: Any = Depends(get_firestore_client),
):
    """Aprueba un candidato de catálogo (requiere catalog.edit).

    El ítem queda marcado como *approved*.  El administrador debe actualizar
    manualmente el bundle de catálogo para que el nombre quede disponible como
    opción oficial en futuras actividades.
    """
    _require_catalog_edit(current_user, db)

    client = get_firestore_client()
    ref = client.collection("catalog_candidates").document(candidate_id)
    snap = ref.get()
    if not snap.exists:
        raise api_error(
            status_code=status.HTTP_404_NOT_FOUND,
            code="CANDIDATE_NOT_FOUND",
            message=f"Candidato no encontrado: {candidate_id}",
        )

    data = snap.to_dict() or {}
    current_status = str(data.get("status") or "pending")
    if current_status != "pending":
        raise api_error(
            status_code=status.HTTP_409_CONFLICT,
            code="CANDIDATE_ALREADY_REVIEWED",
            message=f"El candidato ya fue revisado con estado: {current_status}",
        )

    now = _utc_now()
    reviewer_id = str(getattr(current_user, "id", "") or "")
    ref.set(
        {
            "status": "approved",
            "reviewed_at": now,
            "reviewed_by_user_id": reviewer_id,
            "review_comment": comment,
        },
        merge=True,
    )

    logger.info(
        "CATALOG_CANDIDATE_APPROVED id=%s name=%s type=%s project_id=%s reviewer=%s",
        candidate_id,
        data.get("name"),
        data.get("type"),
        data.get("project_id"),
        reviewer_id,
    )
    return {"ok": True, "id": candidate_id, "status": "approved"}


# ---------------------------------------------------------------------------
# POST /catalog/candidates/{candidate_id}/reject
# ---------------------------------------------------------------------------

@router.post("/candidates/{candidate_id}/reject", status_code=status.HTTP_200_OK)
def reject_catalog_candidate(
    candidate_id: str,
    comment: str | None = None,
    current_user: Any = Depends(get_current_user),
    db: Any = Depends(get_firestore_client),
):
    """Rechaza un candidato de catálogo (requiere catalog.edit)."""
    _require_catalog_edit(current_user, db)

    client = get_firestore_client()
    ref = client.collection("catalog_candidates").document(candidate_id)
    snap = ref.get()
    if not snap.exists:
        raise api_error(
            status_code=status.HTTP_404_NOT_FOUND,
            code="CANDIDATE_NOT_FOUND",
            message=f"Candidato no encontrado: {candidate_id}",
        )

    data = snap.to_dict() or {}
    current_status = str(data.get("status") or "pending")
    if current_status != "pending":
        raise api_error(
            status_code=status.HTTP_409_CONFLICT,
            code="CANDIDATE_ALREADY_REVIEWED",
            message=f"El candidato ya fue revisado con estado: {current_status}",
        )

    now = _utc_now()
    reviewer_id = str(getattr(current_user, "id", "") or "")
    ref.set(
        {
            "status": "rejected",
            "reviewed_at": now,
            "reviewed_by_user_id": reviewer_id,
            "review_comment": comment,
        },
        merge=True,
    )

    logger.info(
        "CATALOG_CANDIDATE_REJECTED id=%s name=%s type=%s project_id=%s reviewer=%s",
        candidate_id,
        data.get("name"),
        data.get("type"),
        data.get("project_id"),
        reviewer_id,
    )
    return {"ok": True, "id": candidate_id, "status": "rejected"}
