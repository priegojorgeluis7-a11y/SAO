"""Sync API endpoints for activities."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, verify_project_access
from app.core.database import get_db
from app.models.activity import Activity
from app.models.user import User
from app.schemas.activity import ActivityDTO
from app.schemas.sync import (
    SyncPullRequest,
    SyncPullResponse,
    SyncPushActivityItem,
    SyncPushRequest,
    SyncPushResponse,
    SyncPushResultItem,
)

router = APIRouter(prefix="/sync", tags=["sync"])


def _utc_now() -> datetime:
    """Return timezone-aware UTC datetime."""
    return datetime.now(timezone.utc)


def _build_pull_query(db: Session, request: SyncPullRequest):
    """Build sync pull query with optional upper bound."""
    query = db.query(Activity).filter(
        Activity.project_id == request.project_id,
        Activity.sync_version > request.since_version,
    )
    if request.until_version is not None:
        query = query.filter(Activity.sync_version <= request.until_version)
    return query.order_by(Activity.sync_version.asc()).limit(request.limit)


def _compute_current_version(request: SyncPullRequest, activities: list[Activity]) -> int:
    """Return max sync_version in result set or since_version when no rows exist."""
    if not activities:
        return request.since_version
    return max(activity.sync_version for activity in activities)


def _create_activity_from_sync_item(item: SyncPushActivityItem) -> Activity:
    """Build a new Activity ORM entity from a sync push payload item."""
    return Activity(
        uuid=item.uuid,
        project_id=item.project_id,
        front_id=item.front_id,
        pk_start=item.pk_start,
        pk_end=item.pk_end,
        execution_state=item.execution_state,
        assigned_to_user_id=item.assigned_to_user_id,
        created_by_user_id=item.created_by_user_id,
        catalog_version_id=item.catalog_version_id,
        activity_type_code=item.activity_type_code,
        latitude=item.latitude,
        longitude=item.longitude,
        title=item.title,
        description=item.description,
        created_at=_utc_now(),
        updated_at=_utc_now(),
        sync_version=1,
        deleted_at=item.deleted_at,
    )


def _has_mutable_changes(existing: Activity, incoming: SyncPushActivityItem) -> bool:
    """Check whether mutable fields differ between persisted and incoming states."""
    return (
        existing.project_id != incoming.project_id
        or existing.front_id != incoming.front_id
        or existing.pk_start != incoming.pk_start
        or existing.pk_end != incoming.pk_end
        or existing.execution_state != incoming.execution_state
        or existing.assigned_to_user_id != incoming.assigned_to_user_id
        or existing.activity_type_code != incoming.activity_type_code
        or existing.latitude != incoming.latitude
        or existing.longitude != incoming.longitude
        or existing.title != incoming.title
        or existing.description != incoming.description
    )


def _apply_mutable_updates(existing: Activity, incoming: SyncPushActivityItem) -> None:
    """Apply mutable updates and update sync metadata."""
    existing.project_id = incoming.project_id
    existing.front_id = incoming.front_id
    existing.pk_start = incoming.pk_start
    existing.pk_end = incoming.pk_end
    existing.execution_state = incoming.execution_state
    existing.assigned_to_user_id = incoming.assigned_to_user_id
    existing.activity_type_code = incoming.activity_type_code
    existing.latitude = incoming.latitude
    existing.longitude = incoming.longitude
    existing.title = incoming.title
    existing.description = incoming.description
    existing.updated_at = _utc_now()
    existing.increment_sync_version()


def _result_item(item_uuid: str, result_status: str, server_id: int, sync_version: int) -> SyncPushResultItem:
    """Create normalized per-item response payload."""
    return SyncPushResultItem(
        uuid=item_uuid,
        status=result_status,
        server_id=server_id,
        sync_version=sync_version,
    )


@router.post("/pull", response_model=SyncPullResponse, status_code=status.HTTP_200_OK)
async def sync_pull(
    request: SyncPullRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Return activities updated since client's known sync_version for a project."""
    verify_project_access(current_user, request.project_id, db)

    activities = _build_pull_query(db, request).all()
    activity_dtos = [ActivityDTO.model_validate(activity) for activity in activities]
    current_version = _compute_current_version(request, activities)

    return SyncPullResponse(current_version=current_version, activities=activity_dtos)


@router.post("/push", response_model=SyncPushResponse, status_code=status.HTTP_200_OK)
async def sync_push(
    request: SyncPushRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upsert client activities by UUID and return per-item sync results."""
    verify_project_access(current_user, request.project_id, db)
    results: list[SyncPushResultItem] = []

    for item in request.activities:
        existing = db.query(Activity).filter(Activity.uuid == item.uuid).first()

        if existing is None:
            new_activity = _create_activity_from_sync_item(item)
            db.add(new_activity)
            db.flush()
            results.append(
                _result_item(
                    item_uuid=item.uuid,
                    result_status="CREATED",
                    server_id=new_activity.id,
                    sync_version=new_activity.sync_version,
                )
            )
            continue

        if existing.deleted_at is not None:
            if item.deleted_at is not None:
                results.append(
                    _result_item(item.uuid, "UNCHANGED", existing.id, existing.sync_version)
                )
            else:
                results.append(
                    _result_item(item.uuid, "CONFLICT", existing.id, existing.sync_version)
                )
            continue

        if _has_mutable_changes(existing, item):
            _apply_mutable_updates(existing, item)
            results.append(
                _result_item(item.uuid, "UPDATED", existing.id, existing.sync_version)
            )
        else:
            results.append(
                _result_item(item.uuid, "UNCHANGED", existing.id, existing.sync_version)
            )

    db.commit()
    return SyncPushResponse(results=results)
