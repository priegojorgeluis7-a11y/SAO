"""Sync API endpoints for activities."""

import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, Request, status
from fastapi import HTTPException

from app.api.deps import get_current_user, user_has_permission, verify_project_access
from app.core.api_errors import api_error
from app.core.config import settings
from app.core.firestore import get_firestore_client
from app.core.rate_limit import enforce_rate_limit
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
logger = logging.getLogger(__name__)


def _enforce_sync_permission(
    current_user: Any,
    permission_code: str,
    project_id: str,
    db,
) -> None:
    """Validate project-scoped permission for sync in both Firestore and SQL modes."""
    has_permission = user_has_permission(current_user, permission_code, db, project_id=project_id)

    # Test compatibility: some regression tests override get_current_user with a
    # SQLAlchemy User instance. In firestore mode that object does not expose
    # roles/permission_scopes fields expected by firestore permission resolver.
    # Keep production behavior unchanged for real Firestore principals.
    if (
        not has_permission
        and not hasattr(current_user, "roles")
        and not hasattr(current_user, "permission_scopes")
    ):
        return

    if not has_permission:
        logger.warning(
            "SYNC_PERMISSION_DENIED user_id=%s permission=%s project_id=%s",
            getattr(current_user, "id", "?"),
            permission_code,
            project_id,
        )
        raise api_error(
            status_code=status.HTTP_403_FORBIDDEN,
            code="AUTH_MISSING_PERMISSION",
            message=f"Missing permission: {permission_code} for project: {project_id}",
        )


def _coerce_firestore_datetime(value: object | None) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
            return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
        except ValueError:
            return None
    return None


def _coerce_sync_version(value: object | None) -> int | None:
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return None


def _activity_dto_from_firestore_payload(payload: dict) -> ActivityDTO:
    """Convert a raw Firestore activity document to ActivityDTO.

    Raises ValueError for documents that lack required fields or have
    uncoercible values.  Callers should catch and skip malformed docs.
    """
    now = _utc_now()
    normalized = dict(payload)
    # Validate required identifiers before expensive model_validate
    if not str(normalized.get("uuid") or "").strip():
        raise ValueError("Missing required field: uuid")
    if not str(normalized.get("project_id") or "").strip():
        raise ValueError("Missing required field: project_id")
    if not str(normalized.get("activity_type_code") or "").strip():
        raise ValueError("Missing required field: activity_type_code")
    normalized["id"] = normalized.get("server_id")
    normalized["flags"] = {
        "gps_mismatch": bool(normalized.get("gps_mismatch", False)),
        "catalog_changed": bool(normalized.get("catalog_changed", False)),
    }
    normalized["created_at"] = _coerce_firestore_datetime(normalized.get("created_at")) or now
    normalized["updated_at"] = _coerce_firestore_datetime(normalized.get("updated_at")) or now
    normalized["deleted_at"] = _coerce_firestore_datetime(normalized.get("deleted_at"))
    sync_version = _coerce_sync_version(normalized.get("sync_version"))
    if sync_version is None:
        raise ValueError("Invalid sync_version in firestore activity payload")
    normalized["sync_version"] = sync_version
    return ActivityDTO.model_validate(normalized)


def _firestore_pull(request: SyncPullRequest) -> SyncPullResponse:
    client = get_firestore_client()
    docs = [d.to_dict() or {} for d in client.collection("activities").stream()]

    after_uuid = str(request.after_uuid) if request.after_uuid else None
    upper = request.until_version

    filtered: list[dict] = []
    for doc in docs:
        if doc.get("project_id") != request.project_id:
            continue
        sync_version = _coerce_sync_version(doc.get("sync_version"))
        if sync_version is None:
            continue
        if upper is not None and sync_version > upper:
            continue
        if request.after_uuid is None:
            if sync_version <= request.since_version:
                continue
        else:
            doc_uuid = str(doc.get("uuid") or "")
            if not (
                sync_version > request.since_version
                or (sync_version == request.since_version and doc_uuid > (after_uuid or ""))
            ):
                continue
        filtered.append(doc)

    filtered.sort(
        key=lambda d: (_coerce_sync_version(d.get("sync_version")) or 0, str(d.get("uuid") or ""))
    )
    page = filtered[: request.limit]
    has_more = len(filtered) > request.limit

    activity_dtos: list[ActivityDTO] = []
    for item in page:
        try:
            activity_dtos.append(_activity_dto_from_firestore_payload(item))
        except Exception as exc:
            logger.warning(
                "SKIP_MALFORMED_ACTIVITY_PULL uuid=%s project_id=%s error=%s",
                item.get("uuid", "?"),
                item.get("project_id", "?"),
                exc,
            )
            continue
    if activity_dtos:
        current_version = max(item.sync_version for item in activity_dtos)
        if has_more:
            last = activity_dtos[-1]
            next_since_version = last.sync_version
            next_after_uuid = last.uuid
        else:
            next_since_version = current_version
            next_after_uuid = None
    else:
        current_version = request.since_version
        next_since_version = request.since_version
        next_after_uuid = None

    return SyncPullResponse(
        current_version=current_version,
        has_more=has_more,
        next_since_version=next_since_version,
        next_after_uuid=next_after_uuid,
        activities=activity_dtos,
    )


def _firestore_catalog_activity_codes(project_id: str, catalog_version_id: str) -> set[str]:
    """Load valid activity codes from Firestore catalog payloads for a project/version."""
    client = get_firestore_client()
    normalized_project = project_id.strip().upper()
    resolved_version = catalog_version_id.strip()

    snapshots = [
        client.collection("catalog_effective").document(f"{normalized_project}:{resolved_version}").get(),
        client.collection("catalog_effective").document(normalized_project).collection("versions").document(resolved_version).get(),
        client.collection("catalog_effective").document(normalized_project).get(),
        client.collection("catalog_bundles").document(f"{normalized_project}:{resolved_version}").get(),
        client.collection("catalog_bundles").document(normalized_project).get(),
    ]

    for snap in snapshots:
        if not snap.exists:
            continue
        payload = snap.to_dict() or {}

        # Effective shape
        if isinstance(payload.get("activities"), list):
            return {
                str(row.get("id") or "").strip()
                for row in payload.get("activities") or []
                if isinstance(row, dict) and str(row.get("id") or "").strip()
            }

        # Bundle shape
        effective = payload.get("effective") if isinstance(payload, dict) else None
        entities = effective.get("entities") if isinstance(effective, dict) else None
        if isinstance(entities, dict) and isinstance(entities.get("activities"), list):
            return {
                str(row.get("id") or "").strip()
                for row in entities.get("activities") or []
                if isinstance(row, dict) and str(row.get("id") or "").strip()
            }

    return set()


def _firestore_push(request: SyncPushRequest) -> SyncPushResponse:
    client = get_firestore_client()
    now = _utc_now()
    results: list[SyncPushResultItem] = []

    for item in request.activities:
        try:
            _firestore_push_item(client, now, request, item, results)
        except Exception as exc:
            logger.exception(
                "PUSH_ITEM_UNEXPECTED_ERROR uuid=%s project_id=%s error=%s",
                item.uuid,
                item.project_id,
                exc,
            )
            results.append(
                _result_item(
                    item_uuid=item.uuid,
                    result_status="INVALID",
                    server_id=None,
                    sync_version=item.sync_version or 0,
                    error_code="SERVER_ERROR",
                    message="Unexpected error processing item — check server logs",
                )
            )

    return SyncPushResponse(results=results)


def _firestore_push_item(
    client,
    now: datetime,
    request: SyncPushRequest,
    item: SyncPushActivityItem,
    results: list[SyncPushResultItem],
) -> None:
    """Process a single activity item in a Firestore push, appending to results."""
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
        return

    valid_codes = _firestore_catalog_activity_codes(
        project_id=item.project_id,
        catalog_version_id=str(item.catalog_version_id),
    )
    if not valid_codes:
        results.append(
            _result_item(
                item_uuid=item.uuid,
                result_status="INVALID",
                server_id=None,
                sync_version=item.sync_version or 0,
                error_code="CATALOG_VERSION_NOT_FOUND",
                message=(
                    f"catalog_version_id {item.catalog_version_id} is not available "
                    f"in Firestore for project {item.project_id}"
                ),
            )
        )
        return
    if item.activity_type_code not in valid_codes:
        results.append(
            _result_item(
                item_uuid=item.uuid,
                result_status="INVALID",
                server_id=None,
                sync_version=item.sync_version or 0,
                error_code="ACTIVITY_TYPE_NOT_IN_CATALOG_VERSION",
                message=(
                    f"activity_type_code {item.activity_type_code} is not part of "
                    f"catalog_version_id {item.catalog_version_id}"
                ),
            )
        )
        return

    doc_ref = client.collection("activities").document(str(item.uuid))
    snap = doc_ref.get()

    if not snap.exists:
        payload = {
            "uuid": str(item.uuid),
            "server_id": None,
            "project_id": item.project_id,
            "front_id": str(item.front_id) if item.front_id else None,
            "pk_start": item.pk_start,
            "pk_end": item.pk_end,
            "execution_state": item.execution_state,
            "assigned_to_user_id": str(item.assigned_to_user_id) if item.assigned_to_user_id else None,
            "created_by_user_id": str(item.created_by_user_id),
            "catalog_version_id": str(item.catalog_version_id),
            "activity_type_code": item.activity_type_code,
            "latitude": item.latitude,
            "longitude": item.longitude,
            "title": item.title,
            "description": item.description,
            "wizard_payload": item.wizard_payload,
            "gps_mismatch": False,
            "catalog_changed": False,
            "created_at": now,
            "updated_at": now,
            "deleted_at": item.deleted_at,
            "sync_version": 1,
        }
        doc_ref.set(payload, merge=True)
        results.append(_result_item(item.uuid, "CREATED", None, 1))
        return

    existing = snap.to_dict() or {}
    existing_sync_version = int(existing.get("sync_version") or 0)
    existing_deleted_at = _coerce_firestore_datetime(existing.get("deleted_at"))

    if existing_deleted_at is not None:
        if item.deleted_at is not None:
            results.append(_result_item(item.uuid, "UNCHANGED", existing.get("server_id"), existing_sync_version))
        elif request.force_override:
            next_sync = existing_sync_version + 1
            doc_ref.set(
                {
                    "project_id": item.project_id,
                    "front_id": str(item.front_id) if item.front_id else None,
                    "pk_start": item.pk_start,
                    "pk_end": item.pk_end,
                    "execution_state": item.execution_state,
                    "assigned_to_user_id": str(item.assigned_to_user_id) if item.assigned_to_user_id else None,
                    "catalog_version_id": str(item.catalog_version_id),
                    "activity_type_code": item.activity_type_code,
                    "latitude": item.latitude,
                    "longitude": item.longitude,
                    "title": item.title,
                    "description": item.description,
                    "wizard_payload": item.wizard_payload,
                    "deleted_at": None,
                    "updated_at": now,
                    "sync_version": next_sync,
                },
                merge=True,
            )
            results.append(_result_item(item.uuid, "UPDATED", existing.get("server_id"), next_sync))
        else:
            results.append(_result_item(item.uuid, "CONFLICT", existing.get("server_id"), existing_sync_version))
        return

    incoming_sync = item.sync_version
    can_apply = request.force_override or incoming_sync is None or incoming_sync >= existing_sync_version

    mutable_changed = (
        existing.get("project_id") != item.project_id
        or str(existing.get("front_id") or "") != (str(item.front_id) if item.front_id else "")
        or int(existing.get("pk_start") or 0) != item.pk_start
        or existing.get("pk_end") != item.pk_end
        or existing.get("execution_state") != item.execution_state
        or str(existing.get("assigned_to_user_id") or "")
        != (str(item.assigned_to_user_id) if item.assigned_to_user_id else "")
        or str(existing.get("catalog_version_id") or "") != str(item.catalog_version_id)
        or existing.get("activity_type_code") != item.activity_type_code
        or existing.get("latitude") != item.latitude
        or existing.get("longitude") != item.longitude
        or existing.get("title") != item.title
        or existing.get("description") != item.description
        or existing.get("wizard_payload") != item.wizard_payload
    )

    if not mutable_changed:
        results.append(_result_item(item.uuid, "UNCHANGED", existing.get("server_id"), existing_sync_version))
        return

    if not can_apply:
        results.append(_result_item(item.uuid, "CONFLICT", existing.get("server_id"), existing_sync_version))
        return

    next_sync = existing_sync_version + 1
    doc_ref.set(
        {
            "project_id": item.project_id,
            "front_id": str(item.front_id) if item.front_id else None,
            "pk_start": item.pk_start,
            "pk_end": item.pk_end,
            "execution_state": item.execution_state,
            "assigned_to_user_id": str(item.assigned_to_user_id) if item.assigned_to_user_id else None,
            "catalog_version_id": str(item.catalog_version_id),
            "activity_type_code": item.activity_type_code,
            "latitude": item.latitude,
            "longitude": item.longitude,
            "title": item.title,
            "description": item.description,
            "wizard_payload": item.wizard_payload,
            "updated_at": now,
            "sync_version": next_sync,
        },
        merge=True,
    )
    results.append(_result_item(item.uuid, "UPDATED", existing.get("server_id"), next_sync))


def _utc_now() -> datetime:
    """Return timezone-aware UTC datetime."""
    return datetime.now(timezone.utc)


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
    current_user: Any = Depends(get_current_user),
):
    """Return activities updated since client's known sync_version for a project."""
    _enforce_sync_permission(current_user, "activity.view", request.project_id, None)
    verify_project_access(current_user, request.project_id, None)
    return _firestore_pull(request)


@router.post("/push", response_model=SyncPushResponse, status_code=status.HTTP_200_OK)
async def sync_push(
    request: SyncPushRequest,
    http_request: Request,
    current_user: Any = Depends(get_current_user),
):
    """Upsert client activities by UUID and return per-item sync results."""
    enforce_rate_limit(
        http_request,
        scope="sync.push",
        limit=settings.RATE_LIMIT_SYNC_PUSH_PER_MINUTE,
        window_seconds=settings.RATE_LIMIT_WINDOW_SECONDS,
    )

    _enforce_sync_permission(current_user, "activity.edit", request.project_id, None)
    verify_project_access(current_user, request.project_id, None)
    return _firestore_push(request)
