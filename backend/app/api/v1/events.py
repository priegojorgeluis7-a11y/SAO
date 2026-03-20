"""Events API endpoints â€" field incident reporting."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status

from app.api.deps import get_current_user, user_has_permission, verify_project_access
from app.core.firestore import get_firestore_client
from typing import Any
from app.schemas.event import (
    EventCreate,
    EventDTO,
    EventListResponse,
    EventUpdate,
)

router = APIRouter(prefix="/events", tags=["events"])


def _enforce_event_permission(
    current_user: Any,
    permission_code: str,
    project_id: str,
) -> None:
    """Validate project-scoped event permission in Firestore and SQL modes."""
    if not user_has_permission(current_user, permission_code, None, project_id=project_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Missing permission: {permission_code} for project: {project_id}",
        )


def _event_dto_from_firestore(payload: dict) -> EventDTO:
    data = dict(payload)
    data["id"] = data.get("server_id")
    return EventDTO.model_validate(data)


@router.post("", response_model=EventDTO)
async def create_event(
    event_data: EventCreate,
    response: Response,
    current_user: Any = Depends(get_current_user),
):
    """
    Create a new field incident event (idempotent by uuid).
    Returns 201 on creation, 200 if UUID already exists.
    """
    verify_project_access(current_user, event_data.project_id, None)
    _enforce_event_permission(current_user, "event.create", event_data.project_id)

    client = get_firestore_client()
    doc_ref = client.collection("events").document(str(event_data.uuid))
    existing = doc_ref.get()
    if existing.exists:
        response.status_code = status.HTTP_200_OK
        return _event_dto_from_firestore(existing.to_dict() or {})

    now = event_data.created_at or event_data.updated_at
    if now is None:
        from datetime import datetime, timezone

        now = datetime.now(timezone.utc)
    payload = {
        "uuid": str(event_data.uuid),
        "server_id": None,
        "project_id": event_data.project_id,
        "event_type_code": event_data.event_type_code,
        "title": event_data.title,
        "description": event_data.description,
        "severity": event_data.severity,
        "location_pk_meters": event_data.location_pk_meters,
        "latitude": event_data.latitude,
        "longitude": event_data.longitude,
        "occurred_at": event_data.occurred_at,
        "resolved_at": None,
        "reported_by_user_id": str(event_data.reported_by_user_id),
        "assigned_to_user_id": str(event_data.assigned_to_user_id) if event_data.assigned_to_user_id else None,
        "form_fields_json": event_data.form_fields_json,
        "created_at": now,
        "updated_at": now,
        "deleted_at": None,
        "sync_version": 1,
    }
    doc_ref.set(payload)
    response.status_code = status.HTTP_201_CREATED
    return _event_dto_from_firestore(payload)


@router.get("", response_model=EventListResponse)
async def list_events(
    project_id: str | None = Query(None, description="Filter by project ID"),
    event_type_code: str | None = Query(None, description="Filter by event type code"),
    severity: str | None = Query(None, description="Filter by severity: LOW|MEDIUM|HIGH|CRITICAL"),
    since_version: int | None = Query(None, ge=0, description="Return events with sync_version > this"),
    include_deleted: bool = Query(False, description="Include soft-deleted events"),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    current_user: Any = Depends(get_current_user),
):
    """List events with optional filters and pagination."""
    if project_id:
        verify_project_access(current_user, project_id, None)
        if not user_has_permission(current_user, "event.view", None, project_id=project_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Missing permission: event.view for project: {project_id}",
            )

    client = get_firestore_client()
    # Push project_id to Firestore server-side (single-field index, auto-created).
    # Remaining filters (deleted_at, severity, since_version) stay Python-side.
    query = client.collection("events")
    if project_id:
        query = query.where("project_id", "==", project_id)
    docs = [d.to_dict() or {} for d in query.stream()]

    def _match(doc: dict) -> bool:
        if not include_deleted and doc.get("deleted_at") is not None:
            return False
        if project_id and doc.get("project_id") != project_id:
            return False
        if event_type_code and doc.get("event_type_code") != event_type_code:
            return False
        if severity and doc.get("severity") != severity:
            return False
        if since_version is not None and int(doc.get("sync_version") or 0) <= since_version:
            return False
        return True

    filtered = [d for d in docs if _match(d)]
    filtered.sort(key=lambda d: int(d.get("sync_version") or 0))
    total = len(filtered)
    start = (page - 1) * page_size
    page_docs = filtered[start : start + page_size]
    items = [_event_dto_from_firestore(doc) for doc in page_docs]
    return EventListResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        has_next=(page * page_size) < total,
    )


@router.get("/{uuid}", response_model=EventDTO)
async def get_event(
    uuid: UUID,
    current_user: Any = Depends(get_current_user),
):
    """Get a single event by UUID."""
    client = get_firestore_client()
    snap = client.collection("events").document(str(uuid)).get()
    if not snap.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Event {uuid} not found")
    dto = _event_dto_from_firestore(snap.to_dict() or {})
    verify_project_access(current_user, dto.project_id, None)
    if not user_has_permission(current_user, "event.view", None, project_id=dto.project_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Missing permission: event.view for project: {dto.project_id}",
        )
    return dto


@router.put("/{uuid}", response_model=EventDTO)
async def update_event(
    uuid: UUID,
    event_data: EventUpdate,
    current_user: Any = Depends(get_current_user),
):
    """Update a field incident event."""
    client = get_firestore_client()
    doc_ref = client.collection("events").document(str(uuid))
    snap = doc_ref.get()
    if not snap.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Event {uuid} not found")
    existing = snap.to_dict() or {}
    project_id = str(existing.get("project_id") or "")
    verify_project_access(current_user, project_id, None)
    if not user_has_permission(current_user, "event.edit", None, project_id=project_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Missing permission: event.edit for project: {project_id}",
        )
    updates = event_data.model_dump(exclude_unset=True)
    if "assigned_to_user_id" in updates and updates["assigned_to_user_id"] is not None:
        updates["assigned_to_user_id"] = str(updates["assigned_to_user_id"])
    from datetime import datetime, timezone

    updates["updated_at"] = datetime.now(timezone.utc)
    updates["sync_version"] = int(existing.get("sync_version") or 0) + 1
    doc_ref.set(updates, merge=True)
    return _event_dto_from_firestore(doc_ref.get().to_dict() or {})


@router.delete("/{uuid}", response_model=EventDTO)
async def delete_event(
    uuid: UUID,
    current_user: Any = Depends(get_current_user),
):
    """Soft-delete a field incident event."""
    client = get_firestore_client()
    doc_ref = client.collection("events").document(str(uuid))
    snap = doc_ref.get()
    if not snap.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Event {uuid} not found")
    existing = snap.to_dict() or {}
    project_id = str(existing.get("project_id") or "")
    verify_project_access(current_user, project_id, None)
    if not user_has_permission(current_user, "event.edit", None, project_id=project_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Missing permission: event.edit for project: {project_id}",
        )
    from datetime import datetime, timezone

    now = datetime.now(timezone.utc)
    doc_ref.set(
        {
            "deleted_at": now,
            "updated_at": now,
            "sync_version": int(existing.get("sync_version") or 0) + 1,
        },
        merge=True,
    )
    return _event_dto_from_firestore(doc_ref.get().to_dict() or {})


