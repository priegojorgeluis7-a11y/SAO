"""Events API endpoints — field incident reporting."""

from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, verify_project_access
from app.core.database import get_db
from app.models.user import User
from app.schemas.event import (
    EventCreate,
    EventDTO,
    EventListResponse,
    EventUpdate,
)
from app.services.event_service import EventService

router = APIRouter(prefix="/events", tags=["events"])


@router.post("", response_model=EventDTO)
async def create_event(
    event_data: EventCreate,
    response: Response,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Create a new field incident event (idempotent by uuid).
    Returns 201 on creation, 200 if UUID already exists.
    """
    verify_project_access(current_user, event_data.project_id, db)
    service = EventService(db)
    existing = service.get_event_by_uuid(event_data.uuid, include_deleted=True)
    event = service.create_event(event_data)
    db.commit()
    db.refresh(event)

    if existing is None:
        response.status_code = status.HTTP_201_CREATED
    return service.to_dto(event)


@router.get("", response_model=EventListResponse)
async def list_events(
    project_id: str | None = Query(None, description="Filter by project ID"),
    event_type_code: str | None = Query(None, description="Filter by event type code"),
    severity: str | None = Query(None, description="Filter by severity: LOW|MEDIUM|HIGH|CRITICAL"),
    since_version: int | None = Query(None, ge=0, description="Return events with sync_version > this"),
    include_deleted: bool = Query(False, description="Include soft-deleted events"),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List events with optional filters and pagination."""
    if project_id:
        verify_project_access(current_user, project_id, db)

    service = EventService(db)
    items, total = service.list_events(
        project_id=project_id,
        event_type_code=event_type_code,
        severity=severity,
        since_version=since_version,
        include_deleted=include_deleted,
        page=page,
        page_size=page_size,
    )
    return EventListResponse(
        items=service.to_dto_list(items),
        total=total,
        page=page,
        page_size=page_size,
        has_next=(page * page_size) < total,
    )


@router.get("/{uuid}", response_model=EventDTO)
async def get_event(
    uuid: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get a single event by UUID."""
    service = EventService(db)
    event = service.get_event_or_404(uuid)
    verify_project_access(current_user, event.project_id, db)
    return service.to_dto(event)


@router.put("/{uuid}", response_model=EventDTO)
async def update_event(
    uuid: UUID,
    event_data: EventUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update a field incident event."""
    service = EventService(db)
    event = service.get_event_or_404(uuid)
    verify_project_access(current_user, event.project_id, db)
    updated = service.update_event(uuid, event_data)
    db.commit()
    db.refresh(updated)
    return service.to_dto(updated)


@router.delete("/{uuid}", response_model=EventDTO)
async def delete_event(
    uuid: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Soft-delete a field incident event."""
    service = EventService(db)
    event = service.get_event_or_404(uuid)
    verify_project_access(current_user, event.project_id, db)
    deleted = service.soft_delete_event(uuid)
    db.commit()
    db.refresh(deleted)
    return service.to_dto(deleted)
