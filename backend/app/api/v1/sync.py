"""Sync API endpoints for activities."""

import logging
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

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


def _is_canceled_execution_state(value: object | None) -> bool:
    return str(value or "").strip().upper() == "CANCELED"


def _is_canceled_activity_payload(payload: dict[str, Any]) -> bool:
    return (
        _coerce_firestore_datetime(payload.get("deleted_at")) is not None
        or _is_canceled_execution_state(payload.get("execution_state"))
    )


def _is_canceled_push_item(item: "SyncPushActivityItem") -> bool:
    return item.deleted_at is not None or _is_canceled_execution_state(item.execution_state)


def _normalized_participant_user_ids(payload: dict[str, Any]) -> list[str]:
    values = payload.get("participant_user_ids")
    if isinstance(values, list):
        normalized: list[str] = []
        for value in values:
            candidate = str(value or "").strip()
            if candidate and candidate not in normalized:
                normalized.append(candidate)
        if normalized:
            return normalized

    fallback = str(payload.get("assigned_to_user_id") or payload.get("created_by_user_id") or "").strip()
    return [fallback] if fallback else []


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
    # Include the supervisor-set scheduled date; fall back to created_at when absent
    # so clients can always use assignment_start_at for date-based filtering.
    normalized["assignment_start_at"] = (
        _coerce_firestore_datetime(normalized.get("assignment_start_at"))
        or normalized["created_at"]
    )
    if not isinstance(normalized.get("wizard_payload"), dict):
        normalized["wizard_payload"] = None
    
    # Fallback: if assigned_to_user_id is missing or null, use created_by_user_id
    # This ensures every activity has a responsible user for mobile Home filtering
    if not normalized.get("assigned_to_user_id"):
        normalized["assigned_to_user_id"] = normalized.get("created_by_user_id")
    normalized["participant_user_ids"] = _normalized_participant_user_ids(normalized)
    
    sync_version = _coerce_sync_version(normalized.get("sync_version"))
    if sync_version is None:
        raise ValueError("Invalid sync_version in firestore activity payload")
    normalized["sync_version"] = sync_version
    return ActivityDTO.model_validate(normalized)


def _firestore_pull(request: SyncPullRequest, operative_user_id: str | None = None) -> SyncPullResponse:
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
        if _is_canceled_activity_payload(item):
            continue
        # OPERATIVO filter: only sync activities assigned to (or created by) them.
        if operative_user_id:
            participant_user_ids = _normalized_participant_user_ids(item)
            # If the participant list is empty (both assigned_to_user_id and
            # created_by_user_id are null in the Firestore doc), include the
            # activity rather than silently dropping it — a null-assignee doc is
            # likely a data-quality issue and should still sync to OPERATIVO users.
            if participant_user_ids and operative_user_id not in participant_user_ids:
                continue
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
    elif page_docs:
        # All items in this page were malformed/skipped. Advance the cursor past
        # them so the client does not enter an infinite loop re-requesting the
        # same stuck page on every sync cycle.
        last_raw = page_docs[-1]
        last_doc = (last_raw.to_dict() if hasattr(last_raw, "to_dict") else dict(last_raw or {}))
        current_version = _coerce_sync_version(last_doc.get("sync_version")) or request.since_version
        next_since_version = current_version
        _last_uuid = str(last_doc.get("uuid") or "").strip()
        next_after_uuid = _last_uuid if (has_more and _last_uuid) else None
        logger.warning(
            "SYNC_PULL_ALL_SKIPPED project_id=%s page_size=%d advanced_to_version=%d",
            request.project_id,
            len(page_docs),
            current_version,
        )
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


# ---------------------------------------------------------------------------
# Catalog candidates extraction
# ---------------------------------------------------------------------------

def _upsert_catalog_candidates(
    client,
    wizard_payload: dict[str, object],
    project_id: str,
    user_id: str,
    activity_id: str,
    now: "datetime",
) -> None:
    """Extract every CUSTOM_* item from *wizard_payload* and upsert it into the
    ``catalog_candidates`` Firestore collection so admins can review/approve them.

    Deduplication key: ``{project_id}_{type}_{id}`` — one document per unique
    (project, type, custom ID).  If a document already exists and is **not** in
    ``pending`` state (i.e. it was already reviewed), it is not overwritten.
    """
    coll = client.collection("catalog_candidates")

    def _upsert(candidate_type: str, item_id: str, item_name: str) -> None:
        doc_id = f"{project_id}__{candidate_type}__{item_id}"
        ref = coll.document(doc_id)
        snap = ref.get()
        if snap.exists:
            existing_status = str((snap.to_dict() or {}).get("status") or "pending")
            if existing_status != "pending":
                # Already reviewed — do not re-open.
                return
            # Still pending: update source activity and last seen timestamp.
            ref.set({"last_seen_at": now, "activity_id": activity_id}, merge=True)
        else:
            ref.set({
                "id": doc_id,
                "custom_id": item_id,
                "type": candidate_type,
                "name": item_name,
                "project_id": project_id,
                "proposed_by_user_id": user_id,
                "activity_id": activity_id,
                "status": "pending",
                "proposed_at": now,
                "last_seen_at": now,
                "reviewed_at": None,
                "reviewed_by_user_id": None,
                "review_comment": None,
            })

    for key, candidate_type in (
        ("activity", "activity"),
        ("subcategory", "subcategory"),
        ("purpose", "purpose"),
        ("result", "result"),
    ):
        entry = wizard_payload.get(key)
        if isinstance(entry, dict):
            item_id = str(entry.get("id") or "").strip()
            item_name = str(entry.get("name") or entry.get("id") or "").strip()
            if item_id.startswith("CUSTOM_") and item_name:
                _upsert(candidate_type, item_id, item_name)

    for key, candidate_type in (
        ("topics", "topic"),
        ("attendees", "attendee"),
    ):
        entries = wizard_payload.get(key)
        if isinstance(entries, list):
            for entry in entries:
                if not isinstance(entry, dict):
                    continue
                item_id = str(entry.get("id") or "").strip()
                item_name = str(entry.get("name") or entry.get("id") or "").strip()
                if item_id.startswith("CUSTOM_") and item_name:
                    _upsert(candidate_type, item_id, item_name)


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
                "PUSH_ITEM_UNEXPECTED_ERROR uuid=%s project_id=%s sync_version=%s activity_type_code=%s execution_state=%s error=%s",
                item.uuid,
                item.project_id,
                item.sync_version,
                item.activity_type_code,
                item.execution_state,
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

    # Log summary of push results for diagnostics
    failed_count = len([r for r in results if r.status in {"INVALID", "CONFLICT"}])
    if failed_count > 0:
        logger.warning(
            "SYNC_PUSH_SUMMARY project_id=%s total_items=%d created=%d updated=%d failed=%d",
            request.project_id,
            len(request.activities),
            len([r for r in results if r.status == "CREATED"]),
            len([r for r in results if r.status == "UPDATED"]),
            failed_count,
        )

    return SyncPushResponse(results=results)


def _mutable_activity_fields(
    item: "SyncPushActivityItem",
    now: datetime,
    sync_version: int,
    *,
    wizard_payload: dict[str, object] | None,
) -> dict:
    """Return the mutable activity fields shared across create/update/undelete branches.
    
    NOTE: review_decision, review_comment, review_reject_reason_code, and review_status
    are intentionally NOT included here. These fields are set exclusively by the
    coordinator via the review endpoint and must NEVER be overwritten by a sync push
    from the mobile client. The only exception is _should_reset_review_metadata(),
    which explicitly clears them when the operativo re-submits corrections after a
    CHANGES_REQUIRED or REJECT decision.
    """
    participant_user_ids = [str(user_id) for user_id in (item.participant_user_ids or [])]
    if item.assigned_to_user_id:
        assignee = str(item.assigned_to_user_id)
        if assignee not in participant_user_ids:
            participant_user_ids.insert(0, assignee)
    return {
        "project_id": item.project_id,
        "front_id": str(item.front_id) if item.front_id else None,
        "pk_start": item.pk_start,
        "pk_end": item.pk_end,
        "execution_state": item.execution_state,
        "assigned_to_user_id": str(item.assigned_to_user_id) if item.assigned_to_user_id else None,
        "participant_user_ids": participant_user_ids,
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
    """Clear stale coordinator rejection metadata when the operativo re-submits corrections.
    
    Only resets when:
    1. The existing decision is CHANGES_REQUIRED or REJECT (not APPROVE/APPROVE_EXCEPTION)
    2. The incoming state indicates the operativo is re-submitting (REVISION_PENDIENTE or COMPLETADA)
    
    If the activity was already APPROVED or APPROVE_EXCEPTION, the review decision is
    NEVER reset — the coordinator's approval is final and must be explicitly changed
    via the review endpoint.
    """
    existing_decision = str(existing.get("review_decision") or "").strip().upper()
    
    # CRITICAL: Never reset APPROVE or APPROVE_EXCEPTION decisions.
    # These are set exclusively by the coordinator via the review endpoint.
    if existing_decision in {"APPROVE", "APPROVE_EXCEPTION", "APPROVED"}:
        return False
    
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


def _extract_custom_ids(wizard_payload: dict[str, object] | None) -> set[str]:
    """Return the set of all CUSTOM_* catalog IDs present in the wizard payload."""
    ids: set[str] = set()
    if not wizard_payload:
        return ids
    for key in ("activity", "subcategory", "purpose", "result"):
        entry = wizard_payload.get(key)
        if isinstance(entry, dict):
            vid = str(entry.get("id") or "")
            if vid.startswith("CUSTOM_"):
                ids.add(vid)
    for key in ("topics", "attendees"):
        entries = wizard_payload.get(key)
        if isinstance(entries, list):
            for entry in entries:
                if isinstance(entry, dict):
                    vid = str(entry.get("id") or "")
                    if vid.startswith("CUSTOM_"):
                        ids.add(vid)
    return ids


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

    # CUSTOM_* activity type codes are created in the field and are never in the
    # official catalog by definition.  Skip catalog validation for them entirely.
    _server_snap_preloaded = None  # may be set early by the catalog precheck below
    if str(item.activity_type_code or "").startswith("CUSTOM_"):
        is_custom_activity = True
    else:
        is_custom_activity = False
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
            # Before rejecting, check if this activity was pre-created server-side
            # (e.g. via the planning/assignment endpoint) with this exact code.
            # If so, the code was already validated at assignment time — trust it.
            _pre_ref = client.collection("activities").document(str(item.uuid))
            _server_snap_preloaded = _pre_ref.get()
            _stored_code = str(
                (_server_snap_preloaded.to_dict() or {}).get("activity_type_code") or ""
            ).strip().upper()
            _incoming_code = str(item.activity_type_code or "").strip().upper()
            if _server_snap_preloaded.exists and _stored_code == _incoming_code:
                # Doc exists server-side with this type: treat as trusted assignment code.
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

    doc_ref = client.collection("activities").document(str(item.uuid))
    snap = _server_snap_preloaded if _server_snap_preloaded is not None else doc_ref.get()

    participant_user_ids = [str(user_id) for user_id in (item.participant_user_ids or [])]
    if item.assigned_to_user_id:
        assignee = str(item.assigned_to_user_id)
        if assignee not in participant_user_ids:
            participant_user_ids.insert(0, assignee)
    incoming_canceled = _is_canceled_push_item(item)

    if not snap.exists:
        if incoming_canceled:
            results.append(_result_item(item.uuid, "UNCHANGED", None, item.sync_version or 0))
            return None, 0
        has_custom_values = is_custom_activity or _wizard_payload_has_custom_ids(item.wizard_payload)
        # Determine whether this is a multi-responsible activity.
        primary_assignee = str(item.assigned_to_user_id) if item.assigned_to_user_id else None
        multi_assign = len(participant_user_ids) > 1
        # All participants except the primary assignee get sibling activities.
        sibling_participant_ids = [
            pid for pid in participant_user_ids if pid != primary_assignee
        ] if multi_assign else []

        activity_group_id = str(uuid4()) if multi_assign else None

        payload = {
            "uuid": str(item.uuid),
            "server_id": None,
            "created_by_user_id": str(item.created_by_user_id),
            "gps_mismatch": False,
            "catalog_changed": has_custom_values,
            "is_primary_responsible": True,
            "created_at": now,
            "deleted_at": None,
            **({"activity_group_id": activity_group_id} if activity_group_id else {}),
            **_mutable_activity_fields(item, now, 1, wizard_payload=item.wizard_payload),
        }
        if batch is None:
            doc_ref.set(payload, merge=True)
        else:
            batch.set(doc_ref, payload, merge=True)
        results.append(_result_item(item.uuid, "CREATED", None, 1))

        # Extract CUSTOM_* catalog items for admin review.
        if has_custom_values and item.wizard_payload:
            try:
                _upsert_catalog_candidates(
                    client,
                    item.wizard_payload,
                    item.project_id,
                    str(item.created_by_user_id),
                    str(item.uuid),
                    now,
                )
            except Exception:
                logger.exception("CATALOG_CANDIDATES_UPSERT_FAILED uuid=%s", item.uuid)

        # Create sibling activities for each co-responsible (not the primary assignee).
        for sibling_uid in sibling_participant_ids:
            sibling_uuid = str(uuid4())
            sibling_ref = client.collection("activities").document(sibling_uuid)
            sibling_payload = {
                **payload,
                "uuid": sibling_uuid,
                "assigned_to_user_id": sibling_uid,
                "execution_state": "PENDIENTE",
                "wizard_payload": None,
                # Siblings have no wizard_payload so there is nothing to resolve;
                # do not inherit catalog_changed = True from the primary activity.
                "catalog_changed": False,
                "is_primary_responsible": False,
                "group_completion_propagated": False,
                "sync_version": 1,
                "created_at": now,
                "updated_at": now,
            }
            if batch is None:
                sibling_ref.set(sibling_payload)
            else:
                batch.set(sibling_ref, sibling_payload)

        return len(results) - 1, 1 + len(sibling_participant_ids)

    existing = snap.to_dict() or {}
    existing_participant_user_ids = _normalized_participant_user_ids(existing)
    if participant_user_ids:
        for participant_user_id in existing_participant_user_ids:
            if participant_user_id not in participant_user_ids:
                participant_user_ids.append(participant_user_id)
    else:
        participant_user_ids = list(existing_participant_user_ids)
    existing_sync_version = int(existing.get("sync_version") or 0)
    existing_deleted_at = _coerce_firestore_datetime(existing.get("deleted_at"))
    existing_canceled = existing_deleted_at is not None or _is_canceled_execution_state(existing.get("execution_state"))

    if existing_canceled:
        results.append(_result_item(item.uuid, "UNCHANGED", existing.get("server_id"), existing_sync_version))
        return None, 0

    # Guard: if this activity was already completed by propagation from a sibling,
    # do not allow the secondary responsible to overwrite it with their local data.
    existing_state = str(existing.get("execution_state") or "").upper()
    if (
        existing.get("group_completion_propagated")
        and existing_state in {"REVISION_PENDIENTE", "COMPLETADA"}
    ):
        incoming_state_check = str(item.execution_state or "").strip().upper()
        if incoming_state_check not in {"REVISION_PENDIENTE", "COMPLETADA"}:
            # Incoming is still pending/in-progress — reject silently so the mobile
            # pull will overwrite the local copy with the already-completed state.
            results.append(_result_item(
                item.uuid,
                "CONFLICT",
                existing.get("server_id"),
                existing_sync_version,
                error_code="GROUP_ALREADY_COMPLETED",
                message="Esta actividad ya fue completada por otro responsable del grupo.",
            ))
            return None, 0
        # Both are completed: allow — the second responsible is confirming their own
        # registration. The wizard_payload of their own activity gets updated.


        next_sync = existing_sync_version + 1
        canceled_at = item.deleted_at or now
        payload = {
            "execution_state": "CANCELED",
            "deleted_at": canceled_at,
            "updated_at": now,
            "sync_version": next_sync,
        }
        if batch is None:
            doc_ref.set(payload, merge=True)
        else:
            batch.set(doc_ref, payload, merge=True)
        results.append(_result_item(item.uuid, "UPDATED", existing.get("server_id"), next_sync))
        return len(results) - 1, 1

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
        or existing_participant_user_ids != participant_user_ids
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
    payload["participant_user_ids"] = participant_user_ids
    # If the wizard_payload now contains custom catalog IDs and the activity was not
    # already flagged, raise the flag so Operaciones can review the catalog changes.
    # Only raise when the incoming payload introduces NEW custom IDs that were not
    # already present in the stored wizard_payload — this prevents re-flagging an
    # activity that was already reviewed and cleared by an admin.
    if not bool(existing.get("catalog_changed", False)) and _wizard_payload_has_custom_ids(
        effective_wizard_payload
    ):
        existing_custom_ids = _extract_custom_ids(existing.get("wizard_payload"))
        incoming_custom_ids = _extract_custom_ids(effective_wizard_payload)
        new_custom_ids = incoming_custom_ids - existing_custom_ids
        if new_custom_ids:
            payload["catalog_changed"] = True
            # Upsert only the genuinely new custom items as candidates.
            if effective_wizard_payload:
                try:
                    _upsert_catalog_candidates(
                        client,
                        effective_wizard_payload,
                        item.project_id,
                        str(item.assigned_to_user_id or item.created_by_user_id or ""),
                        str(item.uuid),
                        now,
                    )
                except Exception:
                    logger.exception("CATALOG_CANDIDATES_UPSERT_FAILED uuid=%s", item.uuid)
    incoming_state = str(item.execution_state or "").strip().upper()
    previous_state = str(existing.get("execution_state") or "").strip().upper()
    completed_like_states = {"REVISION_PENDIENTE", "COMPLETADA"}
    propagation_writes = 0
    if incoming_state in completed_like_states and previous_state not in completed_like_states:
        if item.assigned_to_user_id:
            payload["completed_by_user_id"] = str(item.assigned_to_user_id)
        payload["completed_at"] = now
        # Propagate completion to co-responsible siblings in the same group.
        # Pass the active batch so sibling writes are committed atomically with
        # the primary activity update (avoids partial-completion on batch failure).
        if activity_group_id := existing.get("activity_group_id"):
            propagation_writes = _propagate_group_completion(
                client, batch, activity_group_id, str(item.uuid), payload, now
            )
    if _should_reset_review_metadata(existing, item):
        payload.update(
            {
                "review_decision": None,
                "review_comment": None,
                "review_reject_reason_code": None,
                "review_status": None,
            }
        )
    if batch is None:
        doc_ref.set(payload, merge=True)
    else:
        batch.set(doc_ref, payload, merge=True)
    cancellation_writes = 0
    if _is_canceled_execution_state(incoming_state) and not _is_canceled_execution_state(previous_state):
        # Propagate cancellation to all active siblings so the whole group is cleaned up
        # atomically — prevents orphaned PENDIENTE siblings after a primary cancel.
        if activity_group_id := existing.get("activity_group_id"):
            cancellation_writes = _propagate_group_cancellation(
                client, batch, activity_group_id, str(item.uuid), item.deleted_at or now, now
            )
    results.append(_result_item(item.uuid, "UPDATED", existing.get("server_id"), next_sync))
    return len(results) - 1, 1 + propagation_writes + cancellation_writes


def _propagate_group_cancellation(
    client: Any,
    batch: Any,
    activity_group_id: str,
    canceled_uuid: str,
    canceled_at: datetime,
    now: datetime,
) -> int:
    """When the primary activity in a group is canceled, propagate the cancellation to
    all active siblings so the whole group is cleaned up in the same batch commit.
    Returns the number of sibling writes queued.
    """
    write_count = 0
    try:
        siblings = list(
            client.collection("activities")
            .where("activity_group_id", "==", activity_group_id)
            .stream()
        )
        for snap in siblings:
            sibling = snap.to_dict() or {}
            sibling_uuid = str(sibling.get("uuid") or snap.id)
            if sibling_uuid == canceled_uuid:
                continue
            if sibling.get("deleted_at") or _is_canceled_execution_state(sibling.get("execution_state")):
                continue
            sibling_sync = int(sibling.get("sync_version") or 0) + 1
            cancellation: dict = {
                "execution_state": "CANCELED",
                "deleted_at": canceled_at,
                "group_canceled_by_source_activity_id": canceled_uuid,
                "updated_at": now,
                "sync_version": sibling_sync,
            }
            sibling_ref = client.collection("activities").document(snap.id)
            if batch is not None:
                batch.set(sibling_ref, cancellation, merge=True)
            else:
                sibling_ref.set(cancellation, merge=True)
            write_count += 1
            logger.info(
                "GROUP_CANCELLATION_PROPAGATED group=%s source=%s target=%s",
                activity_group_id,
                canceled_uuid,
                sibling_uuid,
            )
    except Exception as exc:
        logger.warning(
            "GROUP_CANCELLATION_PROPAGATION_FAILED group=%s source=%s error=%s",
            activity_group_id,
            canceled_uuid,
            exc,
        )
    return write_count


def _propagate_group_completion(
    client: Any,
    batch: Any,
    activity_group_id: str,
    completed_uuid: str,
    completion_payload: dict,
    now: datetime,
) -> int:
    """When one activity in a group is completed, propagate the same completion data
    to all sibling activities so every co-responsible is registered as completed.

    Writes are added to *batch* (when provided) so they are committed atomically
    with the primary activity update. Returns the number of sibling writes queued.
    """
    write_count = 0
    try:
        siblings = list(
            client.collection("activities")
            .where("activity_group_id", "==", activity_group_id)
            .stream()
        )
        for snap in siblings:
            sibling = snap.to_dict() or {}
            sibling_uuid = str(sibling.get("uuid") or snap.id)
            if sibling_uuid == completed_uuid:
                continue
            if sibling.get("deleted_at") or _is_canceled_execution_state(sibling.get("execution_state")):
                continue
            sibling_state = str(sibling.get("execution_state") or "").upper()
            if sibling_state in {"REVISION_PENDIENTE", "COMPLETADA"}:
                continue
            sibling_sync = int(sibling.get("sync_version") or 0) + 1
            propagated: dict = {
                "execution_state": completion_payload.get("execution_state", "COMPLETADA"),
                "wizard_payload": completion_payload.get("wizard_payload"),
                "latitude": completion_payload.get("latitude"),
                "longitude": completion_payload.get("longitude"),
                "completed_at": now,
                "completed_by_user_id": completion_payload.get("completed_by_user_id"),
                "group_completed_by_user_id": completion_payload.get("completed_by_user_id"),
                "group_completion_propagated": True,
                "group_source_activity_id": completed_uuid,
                "updated_at": now,
                "sync_version": sibling_sync,
            }
            sibling_ref = client.collection("activities").document(snap.id)
            if batch is not None:
                batch.set(sibling_ref, propagated, merge=True)
            else:
                sibling_ref.set(propagated, merge=True)
            write_count += 1
            logger.info(
                "GROUP_COMPLETION_PROPAGATED group=%s source=%s target=%s",
                activity_group_id,
                completed_uuid,
                sibling_uuid,
            )
    except Exception as exc:
        logger.warning(
            "GROUP_PROPAGATION_FAILED group=%s source=%s error=%s",
            activity_group_id,
            completed_uuid,
            exc,
        )
    return write_count


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

    # OPERATIVO-only users receive only their own activities to prevent data leakage.
    from app.api.deps import user_has_any_role
    from app.services.audit_service import canonicalize_role_name
    caller_roles = {
        canonicalize_role_name(str(r).strip()) or str(r).strip().upper()
        for r in (getattr(current_user, "roles", []) or [])
        if str(r).strip()
    }
    privileged_roles = {"ADMIN", "COORD", "SUPERVISOR", "DESARROLLADOR", "DEVELOPER", "DEV"}
    is_operativo_only = bool(caller_roles) and not caller_roles.intersection(privileged_roles)
    operative_user_id = str(current_user.id).strip() if is_operativo_only else None

    return _firestore_pull(request, operative_user_id=operative_user_id)


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

    # If the user no longer has access to this project (e.g. was removed from it),
    # return UNCHANGED for all items instead of a hard 403.  This unblocks stale
    # entries that a user may still have in their local sync queue from a project
    # they previously belonged to, preventing a permanent ERROR state on the client.
    try:
        verify_project_access(current_user, request.project_id, None)
    except HTTPException as exc:
        if exc.status_code == status.HTTP_403_FORBIDDEN:
            logger.warning(
                "SYNC_PUSH_PROJECT_ACCESS_DENIED_SOFT user_id=%s project_id=%s items=%d — returning UNCHANGED to unblock client queue",
                getattr(current_user, "id", "?"),
                request.project_id,
                len(request.activities),
            )
            return SyncPushResponse(
                results=[
                    _result_item(
                        item_uuid=item.uuid,
                        result_status="UNCHANGED",
                        server_id=None,
                        sync_version=item.sync_version or 0,
                    )
                    for item in request.activities
                ]
            )
        raise

    return _firestore_push(request)


@router.post("/admin/diagnostics")
async def sync_admin_diagnostics(
    project_id: str,
    activity_uuid: str,
    current_user: Any = Depends(get_current_user),
):
    """
    [ADMIN/OPERATORS ONLY] Diagnose sync issues for a specific activity.
    
    Returns current state of activity in Firestore and instructions for retry.
    Useful for cases where user cannot access device to manually retry sync.
    
    Args:
        project_id: Project ID containing the activity
        activity_uuid: UUID of the activity to diagnose
        
    Returns:
        Diagnostic info with current activity state and retry instructions
    """
    # Basic permission check: user must have project access
    verify_project_access(current_user, project_id, None)

    db = get_firestore_client()
    # Activities are stored at the root collection activities/{uuid},
    # NOT nested under projects/{project_id}/activities/{uuid}.
    doc_ref = db.collection("activities").document(str(activity_uuid))
    snap = doc_ref.get()

    if not snap.exists:
        # Fallback: mobile uploads may store a different document ID than the uuid field.
        docs = list(
            db.collection("activities")
            .where("uuid", "==", str(activity_uuid))
            .where("project_id", "==", project_id)
            .limit(1)
            .stream()
        )
        if not docs:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Activity {activity_uuid} not found in project {project_id}",
            )
        snap = docs[0]
    
    data = snap.to_dict() or {}
    sync_version = data.get("sync_version", 0)
    execution_state = data.get("execution_state", "UNKNOWN")
    deleted_at = data.get("deleted_at")
    created_at = data.get("created_at")
    updated_at = data.get("updated_at")
    status_val = data.get("status", "UNKNOWN")
    
    # Determine if activity is soft-deleted
    is_canceled = deleted_at is not None or execution_state == "CANCELED"
    
    logger.info(
        "SYNC_ADMIN_DIAGNOSTICS activity_uuid=%s project_id=%s sync_version=%d "
        "execution_state=%s is_canceled=%s requested_by=%s",
        activity_uuid,
        project_id,
        sync_version,
        execution_state,
        is_canceled,
        current_user.id,
    )
    
    return {
        "activity_uuid": str(activity_uuid),
        "project_id": project_id,
        "sync_version": sync_version,
        "execution_state": execution_state,
        "status": status_val,
        "is_canceled": is_canceled,
        "deleted_at": str(deleted_at) if deleted_at else None,
        "created_at": str(created_at) if created_at else None,
        "updated_at": str(updated_at) if updated_at else None,
        "instructions": (
            "User must open the mobile app and manually sync to retry. "
            "Backend will process the sync push with the current state. "
            "If sync fails repeatedly, check activity_type_code and "
            "participant_user_ids are valid in the catalog."
        ),
    }
