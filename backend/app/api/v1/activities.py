"""Activities API endpoints"""

import json
import logging
from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response, status
from fastapi import HTTPException
from app.core.api_errors import api_error
from app.core.config import settings

from app.core.firestore import get_firestore_client
from app.api.deps import (
    get_current_user,
    user_has_any_role,
    user_has_permission,
    verify_project_access,
)
from typing import Any
from app.schemas.activity import (
    ActivityCreate,
    ActivityDTO,
    ActivityFlagsUpdate,
    ActivityListResponse,
    ActivityTimelineItem,
    ActivityUpdate,
)
from app.services.audit_redaction import sanitize_audit_details
from app.services.audit_service import write_firestore_audit_log

router = APIRouter(prefix="/activities", tags=["activities"])
logger = logging.getLogger(__name__)


def _enforce_activity_permission(
    current_user: Any,
    permission_code: str,
    project_id: str,
) -> None:
    verify_project_access(current_user, project_id, None)
    if not user_has_permission(current_user, permission_code, None, project_id=project_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Missing permission: {permission_code} for project: {project_id}",
        )


def _dto_from_firestore_doc(doc: dict) -> ActivityDTO:
    payload = dict(doc)
    payload["id"] = payload.get("server_id")
    payload["flags"] = {
        "gps_mismatch": bool(payload.get("gps_mismatch", False)),
        "catalog_changed": bool(payload.get("catalog_changed", False)),
    }
    return ActivityDTO.model_validate(payload)


def _enforce_admin_delete_activity(current_user: Any, project_id: str) -> None:
    verify_project_access(current_user, project_id, None)
    if not user_has_any_role(current_user, ["ADMIN"], None):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only administrators can delete activities",
        )
    if not user_has_permission(current_user, "activity.delete", None, project_id=project_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Missing permission: activity.delete for project: {project_id}",
        )


def _list_activities_firestore(
    *,
    project_id: str | None,
    front_id: str | None,
    execution_state: str | None,
    assigned_to_user_id: str | None,
    created_by_user_id: str | None,
    updated_since_sync_version: int | None,
    include_deleted: bool,
    offset: int | None = None,
    page_size: int | None = None,
) -> tuple[list[ActivityDTO], int]:
    try:
        client = get_firestore_client()
        # Push the most selective filter (project_id) to Firestore server-side.
        # Remaining filters stay Python-side to avoid composite index requirements.
        query = client.collection("activities")
        if project_id:
            # Composite index (project_id ASC + updated_at DESC) allows server-side
            # sort, avoiding a full collection scan followed by Python sort.
            query = (
                query.where("project_id", "==", project_id)
                     .order_by("updated_at", direction="DESCENDING")
            )
        def _match(doc: dict) -> bool:
            if not include_deleted and doc.get("deleted_at") is not None:
                return False
            if project_id and doc.get("project_id") != project_id:
                return False
            if front_id and str(doc.get("front_id") or "") != str(front_id):
                return False
            if execution_state and doc.get("execution_state") != execution_state:
                return False
            if assigned_to_user_id and str(doc.get("assigned_to_user_id") or "").lower() != assigned_to_user_id.lower():
                return False
            if created_by_user_id and str(doc.get("created_by_user_id") or "").lower() != created_by_user_id.lower():
                return False
            if updated_since_sync_version is not None and int(doc.get("sync_version") or 0) <= updated_since_sync_version:
                return False
            return True

        # Keep a low-memory stream processing path when paging by project.
        # We still compute total to preserve API contract, but only parse DTOs for the requested page.
        stream_offset = offset or 0
        stream_page_size = page_size or 0
        matched_count = 0
        valid_items: list[ActivityDTO] = []
        for snap in query.stream():
            doc = snap.to_dict() or {}
            if not _match(doc):
                continue
            matched_count += 1
            if stream_page_size > 0:
                if matched_count <= stream_offset:
                    continue
                if len(valid_items) >= stream_page_size:
                    continue
            try:
                valid_items.append(_dto_from_firestore_doc(doc))
            except Exception:
                logger.warning(
                    "Skipping malformed Firestore activity document uuid=%s",
                    doc.get("uuid"),
                    exc_info=True,
                )

        return valid_items, matched_count
    except Exception:
        logger.exception("Firestore list read failed for activities")
        return [], 0


def _get_activity_by_uuid_firestore(uuid: str) -> ActivityDTO | None:
    try:
        parsed_uuid = UUID(str(uuid))
    except ValueError:
        return None
    try:
        client = get_firestore_client()
        snap = client.collection("activities").document(str(parsed_uuid)).get()
        if not snap.exists:
            # Fallback: mobile uploads may store the doc with a different ID but keep uuid as a field
            docs = (
                client.collection("activities")
                .where("uuid", "==", str(parsed_uuid))
                .limit(1)
                .stream()
            )
            doc = next(iter(docs), None)
            if doc is None:
                return None
            snap = doc
        payload = snap.to_dict() or {}
        if payload.get("deleted_at") is not None:
            return None
        return _dto_from_firestore_doc(payload)
    except Exception:
        logger.exception("Firestore read failed for activity uuid=%s", uuid)
        return None


def _resolve_activity_doc_ref_and_snap(client, uuid_str: str):
    """Return (doc_ref, snap, payload) resolving by document ID first, then by uuid field.

    Returns (None, None, None) if not found.
    """
    doc_ref = client.collection("activities").document(uuid_str)
    snap = doc_ref.get()
    if snap.exists:
        return doc_ref, snap, snap.to_dict() or {}
    # Fallback: search by uuid field (mobile uploads may use a different doc ID)
    docs = (
        client.collection("activities")
        .where("uuid", "==", uuid_str)
        .limit(1)
        .stream()
    )
    doc = next(iter(docs), None)
    if doc is None:
        return None, None, None
    return doc.reference, doc, doc.to_dict() or {}


@router.post("", response_model=ActivityDTO)
async def create_activity(
    activity_data: ActivityCreate,
    response: Response,
    authenticated_user: Any = Depends(get_current_user),
):
    _enforce_activity_permission(authenticated_user, "activity.create", activity_data.project_id)
    client = get_firestore_client()
    doc_ref = client.collection("activities").document(str(activity_data.uuid))
    snap = doc_ref.get()
    if snap.exists:
        response.status_code = status.HTTP_200_OK
        return _dto_from_firestore_doc(snap.to_dict() or {})

    now = datetime.now(timezone.utc)
    payload = {
        "uuid": str(activity_data.uuid),
        "server_id": None,
        "project_id": activity_data.project_id,
        "front_id": str(activity_data.front_id) if activity_data.front_id else None,
        "pk_start": activity_data.pk_start,
        "pk_end": activity_data.pk_end,
        "execution_state": activity_data.execution_state,
        "assigned_to_user_id": str(activity_data.assigned_to_user_id) if activity_data.assigned_to_user_id else None,
        "created_by_user_id": str(getattr(authenticated_user, "id", activity_data.created_by_user_id)),
        "catalog_version_id": str(activity_data.catalog_version_id),
        "activity_type_code": activity_data.activity_type_code,
        "latitude": activity_data.latitude,
        "longitude": activity_data.longitude,
        "title": activity_data.title,
        "description": activity_data.description,
        "gps_mismatch": False,
        "catalog_changed": False,
        "created_at": activity_data.created_at or now,
        "updated_at": activity_data.updated_at or now,
        "deleted_at": None,
        "sync_version": 1,
    }
    doc_ref.set(payload)
    response.status_code = status.HTTP_201_CREATED
    return _dto_from_firestore_doc(payload)


@router.get("", response_model=ActivityListResponse)
async def list_activities(
    project_id: str | None = Query(None, description="Filter by project_id"),
    front_id: str | None = Query(None, description="Filter by front_id"),
    execution_state: str | None = Query(None, description="Filter by execution_state"),
    assigned_to_user_id: str | None = Query(None, description="Filter by assigned_to_user_id"),
    created_by_user_id: str | None = Query(None, description="Filter by created_by_user_id"),
    updated_since_sync_version: int | None = Query(None, description="Get activities updated after this sync_version"),
    include_deleted: bool = Query(False, description="Include soft-deleted activities"),
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(50, ge=1, le=100, description="Items per page"),
    current_user: Any = Depends(get_current_user),
):
    """
    List activities with filters and pagination
    Supports incremental sync via updated_since_sync_version parameter
    """
    permission_cache: dict[str, bool] = {}

    def _can_view_project(doc_project_id: str | None) -> bool:
        normalized_project_id = str(doc_project_id or "").strip().upper()
        if not normalized_project_id:
            return False
        if _is_legacy_sql_test_principal(current_user):
            return True
        cached = permission_cache.get(normalized_project_id)
        if cached is not None:
            return cached
        try:
            verify_project_access(current_user, normalized_project_id, None)
        except HTTPException:
            permission_cache[normalized_project_id] = False
            return False
        allowed = user_has_permission(current_user, "activity.view", None, project_id=normalized_project_id)
        permission_cache[normalized_project_id] = allowed
        return allowed

    if project_id:
        _enforce_activity_permission(current_user, "activity.view", project_id)

    offset = (page - 1) * page_size
    if project_id:
        paged_items, total = _list_activities_firestore(
            project_id=project_id,
            front_id=front_id,
            execution_state=execution_state,
            assigned_to_user_id=assigned_to_user_id,
            created_by_user_id=created_by_user_id,
            updated_since_sync_version=updated_since_sync_version,
            include_deleted=include_deleted,
            offset=offset,
            page_size=page_size,
        )
        visible_items_total = total
    else:
        dto_items, total = _list_activities_firestore(
            project_id=project_id,
            front_id=front_id,
            execution_state=execution_state,
            assigned_to_user_id=assigned_to_user_id,
            created_by_user_id=created_by_user_id,
            updated_since_sync_version=updated_since_sync_version,
            include_deleted=include_deleted,
        )
        visible_items = [item for item in dto_items if _can_view_project(item.project_id)]
        paged_items = visible_items[offset : offset + page_size]
        visible_items_total = len(visible_items)

    return ActivityListResponse(
        items=paged_items,
        total=visible_items_total,
        page=page,
        page_size=page_size,
        has_next=offset + len(paged_items) < visible_items_total,
    )


@router.get("/{uuid}", response_model=ActivityDTO)
async def get_activity(
    uuid: str,
    current_user: Any = Depends(get_current_user),
):
    """Get activity by uuid"""
    dto = _get_activity_by_uuid_firestore(uuid)
    if dto is None:
        raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="ACTIVITY_NOT_FOUND", message=f"Activity {uuid} not found")
    _enforce_activity_permission(current_user, "activity.view", dto.project_id)
    return dto


def _firestore_activity_dto(doc_ref, uuid: str) -> ActivityDTO:
    """Read a Firestore activity doc and return ActivityDTO, raising 404 if missing."""
    snap = doc_ref.get()
    if not snap.exists:
        raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="ACTIVITY_NOT_FOUND", message=f"Activity {uuid} not found")
    return _dto_from_firestore_doc(snap.to_dict() or {})


@router.get("/{uuid}/readiness")
async def get_activity_readiness(
    uuid: str,
    current_user: Any = Depends(get_current_user),
):
    """Return a lightweight readiness summary used by clients before approval/submission."""
    dto = _get_activity_by_uuid_firestore(uuid)
    if dto is None:
        raise api_error(
            status_code=status.HTTP_404_NOT_FOUND,
            code="ACTIVITY_NOT_FOUND",
            message=f"Activity {uuid} not found",
        )

    _enforce_activity_permission(current_user, "activity.view", dto.project_id)

    client = get_firestore_client()
    evidence_count = 0
    try:
        activity_snapshot = client.collection("activities").document(str(dto.uuid)).get()
        activity_payload = activity_snapshot.to_dict() or {}
        evidence_aliases = {str(dto.uuid)}
        legacy_id = str(activity_payload.get("server_id") or "").strip()
        if legacy_id:
            evidence_aliases.add(legacy_id)

        for evidence_activity_id in evidence_aliases:
            evidence_count = max(
                evidence_count,
                sum(
                    1
                    for _ in client.collection("evidences")
                    .where("activity_id", "==", evidence_activity_id)
                    .limit(1)
                    .stream()
                ),
            )

        if evidence_count == 0:
            wizard_payload = activity_payload.get("wizard_payload")
            if isinstance(wizard_payload, dict):
                wizard_evidences = wizard_payload.get("evidences")
                if isinstance(wizard_evidences, list):
                    evidence_count = len([row for row in wizard_evidences if isinstance(row, dict)])

    except Exception:
        logger.exception("Firestore evidence readiness read failed for activity uuid=%s", uuid)

    has_gps = dto.latitude is not None and dto.longitude is not None
    has_required_fields = bool(dto.activity_type_code)
    has_evidence = evidence_count > 0

    missing: list[dict[str, Any]] = []
    if not has_required_fields:
        missing.append(
            {
                "category": "checklist",
                "code": "required",
                "message": "Falta completar la clasificación obligatoria antes de enviar.",
                "step": "clasificacion",
                "detail": {"field": "contexto.clasificacion", "reason": "required"},
            }
        )
    if not has_evidence:
        missing.append(
            {
                "category": "evidencias",
                "code": "at_least_1",
                "message": "Se requiere al menos una evidencia antes de validar y enviar.",
                "step": "evidencias",
                "detail": {"field": "evidencias", "reason": "at_least_1"},
            }
        )
    # GPS is currently non-blocking for readiness/approval.

    checklist_total = 2
    checklist_completed = int(has_required_fields) + int(has_evidence)
    ready = len(missing) == 0

    return {
        "activity_id": str(dto.uuid),
        "ready": ready,
        "is_ready": ready,
        "evidence_count": evidence_count,
        "has_gps": has_gps,
        "wizard_filled": has_required_fields,
        "missing": missing,
        "checklist_summary": {
            "total": checklist_total,
            "completed": checklist_completed,
        },
        "checks": {
            "has_required_fields": has_required_fields,
            "has_evidence": has_evidence,
            "has_gps": has_gps,
            "gps_blocking": False,
        },
    }


@router.put("/{uuid}", response_model=ActivityDTO)
async def update_activity(
    uuid: str,
    update_data: ActivityUpdate,
    current_user: Any = Depends(get_current_user),
):
    """Update activity by uuid. Increments sync_version on update."""
    client = get_firestore_client()
    doc_ref, snap, existing = _resolve_activity_doc_ref_and_snap(client, str(uuid))
    if doc_ref is None:
        raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="ACTIVITY_NOT_FOUND", message=f"Activity {uuid} not found")
    project_id = str(existing.get("project_id") or "").strip().upper()
    _enforce_activity_permission(current_user, "activity.edit", project_id)
    now = datetime.now(timezone.utc)
    next_sync = int(existing.get("sync_version") or 0) + 1
    updates: dict = {"updated_at": now, "sync_version": next_sync}
    for field in ("execution_state", "title", "description", "pk_start", "pk_end",
                  "latitude", "longitude", "activity_type_code"):
        val = getattr(update_data, field, None)
        if val is not None:
            updates[field] = val
    if getattr(update_data, "front_id", None) is not None:
        updates["front_id"] = str(update_data.front_id)
    if getattr(update_data, "assigned_to_user_id", None) is not None:
        updates["assigned_to_user_id"] = str(update_data.assigned_to_user_id)
        # When reassigning, stamp assignment_start_at so the mobile agenda can
        # locate the activity in the current week. Only set it if the activity
        # does not already have an explicit assignment window from the dispatcher.
        has_window = bool(
            existing.get("assignment_start_at") or existing.get("start_at")
        )
        if not has_window:
            updates["assignment_start_at"] = now.isoformat()
            updates["assignment_end_at"] = (now + timedelta(hours=8)).isoformat()
    doc_ref.update(updates)
    return _firestore_activity_dto(doc_ref, uuid)


@router.delete("/{uuid}", response_model=ActivityDTO)
async def delete_activity(
    uuid: str,
    current_user: Any = Depends(get_current_user),
):
    """Soft-delete activity by uuid. Sets deleted_at and increments sync_version."""
    client = get_firestore_client()
    doc_ref, snap, existing = _resolve_activity_doc_ref_and_snap(client, str(uuid))
    if doc_ref is None:
        raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="ACTIVITY_NOT_FOUND", message=f"Activity {uuid} not found")
    project_id = str(existing.get("project_id") or "").strip().upper()
    _enforce_admin_delete_activity(current_user, project_id)
    now = datetime.now(timezone.utc)
    next_sync = int(existing.get("sync_version") or 0) + 1
    doc_ref.update({"deleted_at": now, "updated_at": now, "sync_version": next_sync})
    write_firestore_audit_log(
        action="ACTIVITY_DELETE",
        entity="activity",
        entity_id=str(uuid),
        actor=current_user,
        details=sanitize_audit_details({
            "project_id": project_id,
            "title": existing.get("title"),
            "activity_type_code": existing.get("activity_type_code"),
            "execution_state": existing.get("execution_state"),
            "soft_delete": True,
            "deleted_at": now.isoformat(),
        }),
    )
    return _firestore_activity_dto(doc_ref, uuid)


@router.patch("/{uuid}/flags", response_model=ActivityDTO)
async def patch_activity_flags(
    uuid: str,
    flags: ActivityFlagsUpdate,
    current_user: Any = Depends(get_current_user),
):
    """Patch review flags (gps_mismatch, catalog_changed). Increments sync_version."""
    client = get_firestore_client()
    doc_ref, snap, existing = _resolve_activity_doc_ref_and_snap(client, str(uuid))
    if doc_ref is None:
        raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="ACTIVITY_NOT_FOUND", message=f"Activity {uuid} not found")
    project_id = str(existing.get("project_id") or "").strip().upper()
    _enforce_activity_permission(current_user, "activity.edit", project_id)
    now = datetime.now(timezone.utc)
    next_sync = int(existing.get("sync_version") or 0) + 1
    updates: dict = {"updated_at": now, "sync_version": next_sync}
    if flags.gps_mismatch is not None:
        updates["gps_mismatch"] = flags.gps_mismatch
    if flags.catalog_changed is not None:
        updates["catalog_changed"] = flags.catalog_changed
    doc_ref.update(updates)
    return _firestore_activity_dto(doc_ref, uuid)


@router.patch("/{uuid}/resolve-catalog")
async def resolve_catalog_values(
    uuid: str,
    payload: dict[str, Any],
    current_user: Any = Depends(get_current_user),
):
    """Replace CUSTOM_* catalog IDs in wizard_payload with official catalog values.

    Payload format:
    {
        "replacements": {
            "activity": {"id": "CAM", "name": "Caminamiento"},       // optional
            "subcategory": {"id": "CAM_DDV", "name": "Verif DDV"},   // optional
            "purpose": {"id": "AFEC_VER", "name": "Verificación"},   // optional
            "topics": [{"old_id": "CUSTOM_TOP_xxx", "id": "TOP_GAL", "name": "Gálibos"}],
            "attendees": [{"old_id": "CUSTOM_ATT_xxx", "id": "AST_ARTF", "name": "ARTF"}],
            "result": {"id": "RES_OK", "name": "Ejecución exitosa"}, // optional
        },
        "clear_catalog_flag": true  // optional, clears catalog_changed flag
    }
    """
    client = get_firestore_client()
    doc_ref, snap, existing = _resolve_activity_doc_ref_and_snap(client, str(uuid))
    if doc_ref is None:
        raise api_error(
            status_code=status.HTTP_404_NOT_FOUND,
            code="ACTIVITY_NOT_FOUND",
            message=f"Activity {uuid} not found",
        )
    project_id = str(existing.get("project_id") or "").strip().upper()
    _enforce_activity_permission(current_user, "activity.edit", project_id)

    wizard_payload = dict(existing.get("wizard_payload") or {})
    replacements = payload.get("replacements") or {}
    now = datetime.now(timezone.utc)
    next_sync = int(existing.get("sync_version") or 0) + 1

    # Replace simple fields (activity, subcategory, purpose, result)
    for field in ("activity", "subcategory", "purpose", "result"):
        replacement = replacements.get(field)
        if replacement and isinstance(replacement, dict):
            current_entry = wizard_payload.get(field)
            if isinstance(current_entry, dict):
                wizard_payload[field] = {**current_entry, **replacement}
            else:
                wizard_payload[field] = replacement

    # Replace list fields (topics, attendees) by matching old_id
    for field in ("topics", "attendees"):
        field_replacements = replacements.get(field)
        if not field_replacements or not isinstance(field_replacements, list):
            continue
        current_list = wizard_payload.get(field)
        if not isinstance(current_list, list):
            continue
        replacement_map = {
            str(r.get("old_id") or ""): r
            for r in field_replacements
            if isinstance(r, dict) and r.get("old_id")
        }
        updated_list = []
        for entry in current_list:
            if not isinstance(entry, dict):
                updated_list.append(entry)
                continue
            entry_id = str(entry.get("id") or "")
            if entry_id in replacement_map:
                repl = replacement_map[entry_id]
                updated_entry = {**entry, "id": repl["id"], "name": repl.get("name", entry.get("name"))}
                updated_list.append(updated_entry)
            else:
                updated_list.append(entry)
        wizard_payload[field] = updated_list

    # Update activity_type_code if activity was replaced
    updates: dict[str, Any] = {
        "wizard_payload": wizard_payload,
        "updated_at": now,
        "sync_version": next_sync,
    }
    activity_replacement = replacements.get("activity")
    if activity_replacement and isinstance(activity_replacement, dict) and activity_replacement.get("id"):
        updates["activity_type_code"] = activity_replacement["id"]

    if payload.get("clear_catalog_flag"):
        updates["catalog_changed"] = False

    doc_ref.update(updates)

    write_firestore_audit_log(
        action="CATALOG_VALUES_RESOLVED",
        entity="activity",
        entity_id=str(uuid),
        actor=current_user,
        details=sanitize_audit_details({
            "replacements": replacements,
            "clear_catalog_flag": payload.get("clear_catalog_flag"),
        }),
    )

    return {"ok": True, "uuid": uuid, "updated_at": now.isoformat()}


@router.get("/{uuid}/timeline", response_model=list[ActivityTimelineItem])
async def get_activity_timeline(
    uuid: str,
    current_user: Any = Depends(get_current_user),
):
    """Return last audit events for a single activity (max 50, newest first)."""
    try:
        activity_uuid = UUID(uuid)
    except ValueError:
        raise api_error(status_code=status.HTTP_400_BAD_REQUEST, code="ACTIVITY_INVALID_UUID", message=f"Invalid activity uuid: {uuid}")

    client = get_firestore_client()
    # Verify activity exists in Firestore
    activity_snapshot = client.collection("activities").document(str(activity_uuid)).get()
    if not activity_snapshot.exists:
        raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="ACTIVITY_NOT_FOUND", message=f"Activity {uuid} not found")
    activity_payload = activity_snapshot.to_dict() or {}
    project_id = str(activity_payload.get("project_id") or "").strip().upper()
    _enforce_activity_permission(current_user, "activity.view", project_id)
    # Composite index (entity_id ASC + created_at DESC) lets Firestore sort and cap
    # server-side, so we never pull more than 50 audit docs for a single activity.
    # Python-side check on entity=="activity" handles the rare cross-entity collision.
    _fetched = [d.to_dict() or {} for d in
                client.collection("audit_logs")
                      .where("entity_id", "==", str(activity_uuid))
                      .order_by("created_at", direction="DESCENDING")
                      .limit(50)
                      .stream()]
    raw_logs = [
        d
        for d in _fetched
        if str(d.get("entity") or "").strip().lower() in {"activity", "assignment"}
    ]
    timeline: list[ActivityTimelineItem] = []
    for log in raw_logs:
        details: dict | None = None
        raw_details = log.get("details_json")
        if raw_details:
            try:
                parsed = json.loads(raw_details) if isinstance(raw_details, str) else raw_details
                details = sanitize_audit_details(parsed)
            except Exception:
                details = {"value": "[REDACTED]"}

        actor_name = str(log.get("actor_name") or "").strip()
        actor_email = str(log.get("actor_email") or "").strip()
        actor_role = str(log.get("actor_role") or "").strip().upper()
        actor_label = actor_email or None
        if actor_name:
            actor_label = actor_name
            if actor_role:
                actor_label = f"{actor_name} · {actor_role}"

        timeline.append(ActivityTimelineItem(
            at=log.get("created_at") or datetime.now(timezone.utc),
            actor=actor_label,
            action=str(log.get("action") or ""),
            details=details,
        ))
    return timeline

