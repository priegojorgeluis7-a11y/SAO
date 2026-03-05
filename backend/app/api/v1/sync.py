"""Sync API endpoints for activities."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Request, status
from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, verify_project_access
from app.core.database import get_db
from app.core.config import settings
from app.core.rate_limit import enforce_rate_limit
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
from app.services.activity_catalog_validator import (
    ActivityCatalogValidationError,
    validate_activity_catalog_binding,
)

router = APIRouter(prefix="/sync", tags=["sync"])


def _utc_now() -> datetime:
    """Return timezone-aware UTC datetime."""
    return datetime.now(timezone.utc)


def _resolve_snapshot_version(db: Session, request: SyncPullRequest) -> int:
    """Resolve stable upper bound version for a pull session."""
    if request.until_version is not None:
        return request.until_version

    max_version = db.query(func.max(Activity.sync_version)).filter(
        Activity.project_id == request.project_id
    ).scalar()
    if max_version is None:
        return request.since_version
    return max(max_version, request.since_version)


def _build_pull_query(db: Session, request: SyncPullRequest, snapshot_version: int):
    """Build sync pull query with stable pagination cursor."""
    query = db.query(Activity).filter(
        Activity.project_id == request.project_id,
        Activity.sync_version <= snapshot_version,
    )

    if request.after_uuid is None:
        query = query.filter(Activity.sync_version > request.since_version)
    else:
        query = query.filter(
            or_(
                Activity.sync_version > request.since_version,
                and_(
                    Activity.sync_version == request.since_version,
                    Activity.uuid > request.after_uuid,
                ),
            )
        )

    return query.order_by(Activity.sync_version.asc(), Activity.uuid.asc()).limit(request.limit)


def _compute_current_version(request: SyncPullRequest, activities: list[Activity]) -> int:
    """Return max sync_version in result set or since_version when no rows exist."""
    if not activities:
        return request.since_version
    return max(activity.sync_version for activity in activities)


def _has_more_activities(
    db: Session,
    request: SyncPullRequest,
    snapshot_version: int,
    activities: list[Activity],
) -> bool:
    """Check if more rows exist beyond current page for the same snapshot."""
    if not activities:
        return False

    last_item = activities[-1]
    next_row = (
        db.query(Activity.id)
        .filter(
            Activity.project_id == request.project_id,
            Activity.sync_version <= snapshot_version,
            or_(
                Activity.sync_version > last_item.sync_version,
                and_(
                    Activity.sync_version == last_item.sync_version,
                    Activity.uuid > last_item.uuid,
                ),
            ),
        )
        .first()
    )
    return next_row is not None


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
        or existing.catalog_version_id != incoming.catalog_version_id
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
    existing.catalog_version_id = incoming.catalog_version_id
    existing.activity_type_code = incoming.activity_type_code
    existing.latitude = incoming.latitude
    existing.longitude = incoming.longitude
    existing.title = incoming.title
    existing.description = incoming.description
    existing.updated_at = _utc_now()
    existing.increment_sync_version()


def _can_apply_update(existing: Activity, incoming: SyncPushActivityItem, force_override: bool) -> bool:
    """Return whether incoming state can be applied based on sync_version policy."""
    if force_override:
        return True

    if incoming.sync_version is None:
        return True

    return incoming.sync_version >= existing.sync_version


def _restore_deleted_with_override(existing: Activity, incoming: SyncPushActivityItem) -> None:
    """Restore a deleted record and apply incoming payload under force override."""
    existing.deleted_at = None
    existing.project_id = incoming.project_id
    existing.front_id = incoming.front_id
    existing.pk_start = incoming.pk_start
    existing.pk_end = incoming.pk_end
    existing.execution_state = incoming.execution_state
    existing.assigned_to_user_id = incoming.assigned_to_user_id
    existing.catalog_version_id = incoming.catalog_version_id
    existing.activity_type_code = incoming.activity_type_code
    existing.latitude = incoming.latitude
    existing.longitude = incoming.longitude
    existing.title = incoming.title
    existing.description = incoming.description
    existing.updated_at = _utc_now()
    existing.increment_sync_version()


def _result_item(
    item_uuid: str,
    result_status: str,
    server_id: int | None,
    sync_version: int,
    error_code: str | None = None,
    message: str | None = None,
) -> SyncPushResultItem:
    """Create normalized per-item response payload."""
    return SyncPushResultItem(
        uuid=item_uuid,
        status=result_status,
        server_id=server_id,
        sync_version=sync_version,
        error_code=error_code,
        message=message,
    )


@router.post("/pull", response_model=SyncPullResponse, status_code=status.HTTP_200_OK)
async def sync_pull(
    request: SyncPullRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Return activities updated since client's known sync_version for a project."""
    verify_project_access(current_user, request.project_id, db)

    snapshot_version = _resolve_snapshot_version(db, request)
    activities = _build_pull_query(db, request, snapshot_version).all()
    activity_dtos = [ActivityDTO.model_validate(activity) for activity in activities]
    current_version = _compute_current_version(request, activities)
    has_more = _has_more_activities(db, request, snapshot_version, activities)

    if has_more and activities:
        last_item = activities[-1]
        next_since_version = last_item.sync_version
        next_after_uuid = last_item.uuid
    else:
        next_since_version = current_version
        next_after_uuid = None

    return SyncPullResponse(
        current_version=current_version,
        has_more=has_more,
        next_since_version=next_since_version,
        next_after_uuid=next_after_uuid,
        activities=activity_dtos,
    )


@router.post("/push", response_model=SyncPushResponse, status_code=status.HTTP_200_OK)
async def sync_push(
    request: SyncPushRequest,
    http_request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upsert client activities by UUID and return per-item sync results."""
    enforce_rate_limit(
        http_request,
        scope="sync.push",
        limit=settings.RATE_LIMIT_SYNC_PUSH_PER_MINUTE,
        window_seconds=settings.RATE_LIMIT_WINDOW_SECONDS,
    )

    verify_project_access(current_user, request.project_id, db)
    results: list[SyncPushResultItem] = []

    for item in request.activities:
        if item.project_id != request.project_id:
            results.append(
                _result_item(
                    item_uuid=item.uuid,
                    result_status="INVALID",
                    server_id=None,
                    sync_version=item.sync_version or 0,
                    error_code="PROJECT_ID_MISMATCH",
                    message=(
                        f"Item project_id {item.project_id} does not match "
                        f"request.project_id {request.project_id}"
                    ),
                )
            )
            continue

        try:
            validate_activity_catalog_binding(
                db,
                project_id=item.project_id,
                catalog_version_id=item.catalog_version_id,
                activity_type_code=item.activity_type_code,
            )
        except ActivityCatalogValidationError as exc:
            results.append(
                _result_item(
                    item_uuid=item.uuid,
                    result_status="INVALID",
                    server_id=None,
                    sync_version=item.sync_version or 0,
                    error_code=exc.code,
                    message=exc.message,
                )
            )
            continue

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
            elif request.force_override:
                _restore_deleted_with_override(existing, item)
                results.append(
                    _result_item(item.uuid, "UPDATED", existing.id, existing.sync_version)
                )
            else:
                results.append(
                    _result_item(item.uuid, "CONFLICT", existing.id, existing.sync_version)
                )
            continue

        if _has_mutable_changes(existing, item):
            if _can_apply_update(existing, item, request.force_override):
                _apply_mutable_updates(existing, item)
                results.append(
                    _result_item(item.uuid, "UPDATED", existing.id, existing.sync_version)
                )
            else:
                results.append(
                    _result_item(item.uuid, "CONFLICT", existing.id, existing.sync_version)
                )
        else:
            results.append(
                _result_item(item.uuid, "UNCHANGED", existing.id, existing.sync_version)
            )

    db.commit()
    return SyncPushResponse(results=results)
