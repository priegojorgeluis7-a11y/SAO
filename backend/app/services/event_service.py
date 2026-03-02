"""Event service — CRUD + soft delete for field incidents."""

from datetime import datetime, timezone
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.event import Event
from app.schemas.event import EventCreate, EventDTO, EventUpdate


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class EventService:
    """
    Business logic for Event CRUD operations.
    Follows the same patterns as ActivityService.
    """

    def __init__(self, db: Session):
        self.db = db

    # ── Create ────────────────────────────────────────────────

    def create_event(self, data: EventCreate) -> Event:
        """
        Create a new event. Idempotent: if UUID already exists returns existing.
        """
        existing = self.db.query(Event).filter(Event.uuid == data.uuid).first()
        if existing:
            return existing

        event = Event(
            uuid=data.uuid,
            project_id=data.project_id,
            event_type_code=data.event_type_code,
            title=data.title,
            description=data.description,
            severity=data.severity,
            location_pk_meters=data.location_pk_meters,
            latitude=data.latitude,
            longitude=data.longitude,
            occurred_at=data.occurred_at,
            reported_by_user_id=data.reported_by_user_id,
            assigned_to_user_id=data.assigned_to_user_id,
            form_fields_json=data.form_fields_json,
            created_at=_utc_now(),
            updated_at=_utc_now(),
            sync_version=1,
        )
        self.db.add(event)
        self.db.flush()
        return event

    # ── Read ─────────────────────────────────────────────────

    def get_event_by_uuid(self, uuid: UUID, include_deleted: bool = False) -> Event | None:
        query = self.db.query(Event).filter(Event.uuid == uuid)
        if not include_deleted:
            query = query.filter(Event.deleted_at.is_(None))
        return query.first()

    def get_event_or_404(self, uuid: UUID) -> Event:
        event = self.get_event_by_uuid(uuid)
        if not event:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Event {uuid} not found",
            )
        return event

    def list_events(
        self,
        project_id: str | None = None,
        event_type_code: str | None = None,
        severity: str | None = None,
        since_version: int | None = None,
        include_deleted: bool = False,
        page: int = 1,
        page_size: int = 50,
    ) -> tuple[list[Event], int]:
        """Return (items, total) with optional filters and pagination."""
        query = self.db.query(Event)

        if not include_deleted:
            query = query.filter(Event.deleted_at.is_(None))
        if project_id:
            query = query.filter(Event.project_id == project_id)
        if event_type_code:
            query = query.filter(Event.event_type_code == event_type_code)
        if severity:
            query = query.filter(Event.severity == severity)
        if since_version is not None:
            query = query.filter(Event.sync_version > since_version)

        total = query.count()
        items = (
            query.order_by(Event.sync_version.asc())
            .offset((page - 1) * page_size)
            .limit(page_size)
            .all()
        )
        return items, total

    # ── Update ────────────────────────────────────────────────

    def update_event(self, uuid: UUID, data: EventUpdate) -> Event:
        event = self.get_event_or_404(uuid)

        for field, value in data.model_dump(exclude_unset=True).items():
            setattr(event, field, value)

        event.updated_at = _utc_now()
        event.increment_sync_version()
        self.db.flush()
        return event

    # ── Delete ────────────────────────────────────────────────

    def soft_delete_event(self, uuid: UUID) -> Event:
        event = self.get_event_or_404(uuid)
        event.soft_delete()
        self.db.flush()
        return event

    # ── Sync helper ───────────────────────────────────────────

    def get_latest_sync_version(self, project_id: str) -> int:
        """Return the current max sync_version for a project."""
        from sqlalchemy import func
        row = (
            self.db.query(func.max(Event.sync_version))
            .filter(Event.project_id == project_id)
            .scalar()
        )
        return row or 0

    def to_dto(self, event: Event) -> EventDTO:
        return EventDTO.model_validate(event)

    def to_dto_list(self, events: list[Event]) -> list[EventDTO]:
        return [self.to_dto(e) for e in events]
