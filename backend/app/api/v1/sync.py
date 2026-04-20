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
from app.core.utils import parse_firestore_dt
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
    """Validate project-scoped permission for sync."""
    has_permission = user_has_permission(current_user, permission_code, db, project_id=project_id)

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


# parse_firestore_dt imported from app.core.utils — canonical datetime coercion
_coerce_firestore_datetime = parse_firestore_dt


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
    if not isinstance(normalized.get("wizard_payload"), dict):
        normalized["wizard_payload"] = None
    
    # Fallback: if assigned_to_user_id is missing or null, use created_by_user_id
    # This ensures every activity has a responsible user for mobile Home filtering
    if not normalized.get("assigned_to_user_id"):
        normalized["assigned_to_user_id"] = normalized.get("created_by_user_id")
    
    sync_version = _coerce_sync_version(normalized.get("sync_version"))
    if sync_version is None:
        raise ValueError("Invalid sync_version in firestore activity payload")
    normalized["sync_version"] = sync_version
    return ActivityDTO.model_validate(normalized)


def _firestore_pull(request: SyncPullRequest) -> SyncPullResponse:
    client = get_firestore_client()
    # Use indexed cursor-based query to avoid full project scans.
    # Required index already exists: (project_id ASC, sync_version ASC, uuid ASC).
    query = (
        client.collection("activities")
        .where("project_id", "==", request.project_id)
        .order_by("sync_version", direction="ASCENDING")
        .order_by("uuid", direction="ASCENDING")
    )
    if request.after_uuid is None:
        query = query.where("sync_version", ">", request.since_version)
    else:
        query = query.where("sync_version", ">=", request.since_version)
        query = query.start_after({"sync_version": request.since_version, "uuid": str(request.after_uuid)})
    if request.until_version is not None:
        query = query.where("sync_version", "<=", request.until_version)

    try:
        docs = list(query.limit(request.limit + 1).stream())
    except Exception:
        # Compatibility fallback for lightweight fake clients used in tests.
        # Mirrors pre-optimization behavior while keeping production path indexed.
        base_docs = [d.to_dict() or {} for d in client.collection("activities").where("project_id", "==", request.project_id).stream()]
        filtered: list[dict] = []
        after_uuid = str(request.after_uuid) if request.after_uuid else None
        for doc in base_docs:
            sync_version = _coerce_sync_version(doc.get("sync_version"))
            if sync_version is None:
                continue
            if request.until_version is not None and sync_version > request.until_version:
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
        filtered.sort(key=lambda d: (_coerce_sync_version(d.get("sync_version")) or 0, str(d.get("uuid") or "")))
        docs = filtered[: request.limit + 1]
    has_more = len(docs) > request.limit
    page_docs = docs[: request.limit]

    activity_dtos: list[ActivityDTO] = []
    for snap in page_docs:
        if hasattr(snap, "to_dict"):
            item = snap.to_dict() or {}
        else:
            item = dict(snap or {})
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
    supports_batch = hasattr(client, "batch")
    batch = client.batch() if supports_batch else None
    pending_result_indexes: list[int] = []
    pending_write_count = 0

    def _commit_pending_batch() -> None:
        nonlocal batch, pending_result_indexes, pending_write_count
        if not supports_batch:
            pending_result_indexes = []
            pending_write_count = 0
            return
        if pending_write_count == 0:
            return
        try:
            batch.commit()
        except Exception:
            logger.exception("SYNC_PUSH_BATCH_COMMIT_FAILED")
            for result_index in pending_result_indexes:
                failed = results[result_index]
                results[result_index] = _result_item(
                    item_uuid=failed.uuid,
                    result_status="INVALID",
                    server_id=failed.server_id,
                    sync_version=failed.sync_version,
                    error_code="SERVER_ERROR",
                    message="Failed to commit sync batch — check server logs",
                )
        finally:
            batch = client.batch()
            pending_result_indexes = []
            pending_write_count = 0

    # Cache catalog lookups per (project_id, catalog_version_id) for this request.
    # A batch of N items sharing the same catalog generates 1 lookup instead of N×5.
    catalog_cache: dict[tuple[str, str], set[str]] = {}

    for item in request.activities:
        try:
            result_index, write_count = _firestore_push_item(
                client,
                batch,
                now,
                request,
                item,
                results,
                catalog_cache,
            )
            if result_index is not None:
                pending_result_indexes.append(result_index)
            pending_write_count += write_count
            if pending_write_count >= 450:
                _commit_pending_batch()
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

    _commit_pending_batch()

    return SyncPushResponse(results=results)


def _mutable_activity_fields(
    item: "SyncPushActivityItem",
    now: datetime,
    sync_version: int,
    *,
    wizard_payload: dict[str, object] | None,
) -> dict:
    """Return the mutable activity fields shared across create/update/undelete branches."""
    return {
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
        "wizard_payload": wizard_payload,
        "updated_at": now,
        "sync_version": sync_version,
    }


def _should_reset_review_metadata(existing: dict, item: "SyncPushActivityItem") -> bool:
    """Clear stale coordinator rejection metadata when the operativo re-submits corrections."""
    existing_decision = str(existing.get("review_decision") or "").strip().upper()
    if existing_decision not in {"CHANGES_REQUIRED", "REQUEST_CHANGES", "REQUIRES_CHANGES", "REJECT"}:
        return False

    incoming_state = str(item.execution_state or "").strip().upper()
    return incoming_state in {"REVISION_PENDIENTE", "COMPLETADA"}


def _wizard_payload_has_custom_ids(wizard_payload: dict[str, object] | None) -> bool:
    """Return True if the wizard payload contains any CUSTOM_* catalog IDs."""
    if not wizard_payload:
        return False
    for key in ("activity", "subcategory", "purpose", "result"):
        entry = wizard_payload.get(key)
        if isinstance(entry, dict) and str(entry.get("id") or "").startswith("CUSTOM_"):
            return True
    for key in ("topics", "attendees"):
        entries = wizard_payload.get(key)
        if isinstance(entries, list):
            for entry in entries:
                if isinstance(entry, dict) and str(entry.get("id") or "").startswith("CUSTOM_"):
                    return True
    return False


def _firestore_push_item(
    client,
    batch,
    now: datetime,
    request: SyncPushRequest,
    item: SyncPushActivityItem,
    results: list[SyncPushResultItem],
    catalog_cache: dict[tuple[str, str], set[str]],
) -> tuple[int | None, int]:
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
        return None, 0

    cache_key = (item.project_id, str(item.catalog_version_id))
    if cache_key not in catalog_cache:
        catalog_cache[cache_key] = _firestore_catalog_activity_codes(
            project_id=item.project_id,
            catalog_version_id=str(item.catalog_version_id),
        )
    valid_codes = catalog_cache[cache_key]
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
        return None, 0
    if item.activity_type_code not in valid_codes:
        # Allow CUSTOM_* codes from field-created catalog entries; mark for admin review.
        if str(item.activity_type_code or "").startswith("CUSTOM_"):
            is_custom_activity = True
        else:
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
            return None, 0
    else:
        is_custom_activity = False

    doc_ref = client.collection("activities").document(str(item.uuid))
    snap = doc_ref.get()

    if not snap.exists:
        has_custom_values = is_custom_activity or _wizard_payload_has_custom_ids(item.wizard_payload)
        payload = {
            "uuid": str(item.uuid),
            "server_id": None,
            "created_by_user_id": str(item.created_by_user_id),
            "gps_mismatch": False,
            "catalog_changed": has_custom_values,
            "created_at": now,
            "deleted_at": item.deleted_at,
            **_mutable_activity_fields(item, now, 1, wizard_payload=item.wizard_payload),
        }
        if batch is None:
            doc_ref.set(payload, merge=True)
        else:
            batch.set(doc_ref, payload, merge=True)
        results.append(_result_item(item.uuid, "CREATED", None, 1))
        return len(results) - 1, 1

    existing = snap.to_dict() or {}
    existing_sync_version = int(existing.get("sync_version") or 0)
    existing_deleted_at = _coerce_firestore_datetime(existing.get("deleted_at"))

    if existing_deleted_at is not None:
        if item.deleted_at is not None:
            results.append(_result_item(item.uuid, "UNCHANGED", existing.get("server_id"), existing_sync_version))
            return None, 0
        elif request.force_override:
            next_sync = existing_sync_version + 1
            payload = {
                **_mutable_activity_fields(
                    item,
                    now,
                    next_sync,
                    wizard_payload=item.wizard_payload,
                ),
                "deleted_at": None,
            }
            if batch is None:
                doc_ref.set(payload, merge=True)
            else:
                batch.set(doc_ref, payload, merge=True)
            results.append(_result_item(item.uuid, "UPDATED", existing.get("server_id"), next_sync))
            return len(results) - 1, 1
        else:
            results.append(_result_item(item.uuid, "CONFLICT", existing.get("server_id"), existing_sync_version))
            return None, 0

    incoming_sync = item.sync_version
    can_apply = request.force_override or incoming_sync is None or incoming_sync >= existing_sync_version

    effective_wizard_payload = (
        item.wizard_payload
        if item.wizard_payload is not None
        else existing.get("wizard_payload")
    )

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
        or existing.get("wizard_payload") != effective_wizard_payload
    )

    if not mutable_changed:
        results.append(_result_item(item.uuid, "UNCHANGED", existing.get("server_id"), existing_sync_version))
        return None, 0

    if not can_apply:
        results.append(_result_item(item.uuid, "CONFLICT", existing.get("server_id"), existing_sync_version))
        return None, 0

    next_sync = existing_sync_version + 1
    payload = _mutable_activity_fields(
        item,
        now,
        next_sync,
        wizard_payload=effective_wizard_payload,
    )
    if _should_reset_review_metadata(existing, item):
        payload.update(
            {
                "review_decision": None,
                "review_comment": None,
                "review_reject_reason_code": None,
            }
        )
    if batch is None:
        doc_ref.set(payload, merge=True)
    else:
        batch.set(doc_ref, payload, merge=True)
    results.append(_result_item(item.uuid, "UPDATED", existing.get("server_id"), next_sync))
    return len(results) - 1, 1


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
    retryable, suggested_action = _sync_error_guidance(
        result_status=result_status,
        error_code=error_code,
    )
    return SyncPushResultItem(
        uuid=item_uuid,
        status=result_status,
        server_id=server_id,
        sync_version=sync_version,
        error_code=error_code,
        message=message,
        retryable=retryable,
        suggested_action=suggested_action,
    )


def _sync_error_guidance(
    *,
    result_status: str,
    error_code: str | None,
) -> tuple[bool | None, str | None]:
    status_normalized = str(result_status or "").strip().upper()
    code_normalized = str(error_code or "").strip().upper()

    if status_normalized in {"CREATED", "UPDATED", "UNCHANGED"}:
        return None, None

    if status_normalized == "CONFLICT":
        return False, "PULL_AND_RESOLVE_CONFLICT"

    if code_normalized == "SERVER_ERROR":
        return True, "RETRY_AUTOMATIC"

    if code_normalized == "PROJECT_ID_MISMATCH":
        return False, "FIX_PROJECT_CONTEXT"

    if code_normalized in {"CATALOG_VERSION_NOT_FOUND", "ACTIVITY_TYPE_NOT_IN_CATALOG_VERSION"}:
        return False, "REFRESH_CATALOG_AND_RETRY"

    if status_normalized == "INVALID":
        return False, "REVIEW_PAYLOAD"

    return None, None


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
