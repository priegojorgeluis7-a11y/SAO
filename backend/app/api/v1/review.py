import json
import logging
from datetime import datetime, timezone
from typing import Any
from uuid import UUID, NAMESPACE_URL, uuid4, uuid5

from fastapi import APIRouter, Depends, HTTPException, Query, status
from app.core.api_errors import api_error

from app.api.deps import require_any_role, user_has_any_role
from app.core.firestore import get_firestore_client
from app.schemas.review import (
    ReviewActivityOut,
    ReviewChangeFieldOut,
    ReviewDecisionIn,
    ReviewDecisionOut,
    ReviewEvidenceOut,
    ReviewEvidencePatchIn,
    ReviewEvidenceValidateIn,
    ReviewQueueCountersOut,
    ReviewQueueItemOut,
    ReviewQueueResponse,
    ReviewRejectPlaybookItemOut,
    ReviewRejectPlaybookResponse,
    ReviewRejectReasonCreateIn,
)
from app.schemas.activity import build_canonical_flow_projection, infer_sync_state
from app.services.push_notification_service import notify_review_decision
from app.services.audit_redaction import sanitize_audit_details
from app.services.audit_service import write_firestore_audit_log
from app.services.firestore_identity_service import get_firestore_user_by_id

router = APIRouter(prefix="/review", tags=["review"])
logger = logging.getLogger(__name__)

REVISION_PENDIENTE = "REVISION_PENDIENTE"
COMPLETADA = "COMPLETADA"


def _normalize_execution_state(value: Any) -> str:
    state = str(value or "").strip().upper()
    if state in {"EN_REVISION", "PENDIENTE_REVISION"}:
        return REVISION_PENDIENTE
    if state in {"COMPLETADO", "COMPLETED", "DONE"}:
        return COMPLETADA
    return state


def _normalize_review_decision(value: Any) -> str:
    decision = str(value or "").strip().upper()
    if decision in {"APPROVED", "OK"}:
        return "APPROVE"
    if decision in {"REJECTED", "NO"}:
        return "REJECT"
    if decision in {"NEEDS_FIX", "REQUIERE_CAMBIOS"}:
        return "CHANGES_REQUIRED"
    return decision


def _review_status_from_firestore(activity_payload: dict) -> str:
    """
    Derive review status from activity payload.
    Returns standardized English status values to maintain API contract consistency.
    """
    decision = _normalize_review_decision(activity_payload.get("review_decision"))
    execution_state = _normalize_execution_state(activity_payload.get("execution_state"))
    if decision == "REJECT":
        return "REJECTED"
    if decision in {"APPROVE", "APPROVE_EXCEPTION"}:
        return "APPROVED"
    if decision in {"CHANGES_REQUIRED", "REQUEST_CHANGES", "REQUIRES_CHANGES"}:
        return "CHANGES_REQUIRED"
    if execution_state == REVISION_PENDIENTE:
        return "PENDING_REVIEW"
    return "PENDING_REVIEW"


def _safe_dt(value: object, fallback: datetime) -> datetime:
    if isinstance(value, datetime):
        return value
    return fallback


def _should_include_in_review_queue(execution_state: str | None, review_status: str, evidence_count: int) -> bool:
    # Keep rejected activities visible in review queue/history views.
    if review_status == "REJECTED":
        return True
    if review_status == "CHANGES_REQUIRED":
        return True
    if review_status != "PENDING_REVIEW":
        return False
    normalized_state = _normalize_execution_state(execution_state)
    return normalized_state in {REVISION_PENDIENTE, COMPLETADA}


def _severity_from_flags(gps_critical: bool, has_conflicts: bool, missing_evidence: bool) -> str:
    if gps_critical or has_conflicts:
        return "HIGH"
    if missing_evidence:
        return "MED"
    return "LOW"


def _normalize_lookup_key(value: Any) -> str:
    return str(value or "").strip().lower()


def _load_front_names(client, front_ids: set[str]) -> dict[str, str]:
    result: dict[str, str] = {}
    normalized_ids = [front_id for front_id in front_ids if front_id]
    if not normalized_ids:
        return result
    refs = [client.collection("fronts").document(front_id) for front_id in normalized_ids]
    if hasattr(client, "get_all"):
        for snap in client.get_all(refs):
            if not snap.exists:
                continue
            result[snap.id] = str((snap.to_dict() or {}).get("name") or "")
        return result

    # Test fallback for fake clients without get_all.
    for ref in refs:
        snap = ref.get()
        if not snap.exists:
            continue
        result[snap.id] = str((snap.to_dict() or {}).get("name") or "")
    return result


def _load_project_front_scope_map(client, project_ids: set[str]) -> dict[str, dict[str, str]]:
    result: dict[str, dict[str, str]] = {}
    normalized_ids = [str(project_id or "").strip() for project_id in project_ids if str(project_id or "").strip()]
    if not normalized_ids:
        return result

    refs = [client.collection("projects").document(project_id) for project_id in normalized_ids]
    snapshots = client.get_all(refs) if hasattr(client, "get_all") else [ref.get() for ref in refs]
    for snap in snapshots:
        if not snap.exists:
            continue
        payload = snap.to_dict() or {}
        raw_scope = payload.get("front_location_scope") or payload.get("front_location_scopes") or []
        if not isinstance(raw_scope, list):
            continue

        project_scope: dict[str, str] = {}
        for row in raw_scope:
            if not isinstance(row, dict):
                continue
            municipality = str(row.get("municipio") or row.get("municipality") or "").strip()
            front_name = str(row.get("front_name") or row.get("frontName") or row.get("name") or "").strip()
            if municipality and front_name:
                project_scope[_normalize_lookup_key(municipality)] = front_name

        if project_scope:
            result[str(snap.id)] = project_scope
    return result


def _extract_activity_municipality(activity_payload: dict[str, Any]) -> str | None:
    municipality = str(
        activity_payload.get("municipio")
        or activity_payload.get("municipality")
        or ""
    ).strip()
    if municipality:
        return municipality

    wizard_payload = activity_payload.get("wizard_payload")
    if isinstance(wizard_payload, dict):
        location_payload = wizard_payload.get("location")
        if isinstance(location_payload, dict):
            municipality = str(
                location_payload.get("municipio")
                or location_payload.get("municipality")
                or ""
            ).strip()
            if municipality:
                return municipality
    return None


def _resolve_activity_front_name(
    activity_payload: dict[str, Any],
    fronts_map: dict[str, str],
    project_front_scope_map: dict[str, dict[str, str]],
) -> str | None:
    explicit_front = str(activity_payload.get("front") or activity_payload.get("front_name") or "").strip()
    if explicit_front:
        return explicit_front

    front_id = str(activity_payload.get("front_id") or "").strip()
    if front_id:
        front_name = str(fronts_map.get(front_id) or "").strip()
        if front_name:
            return front_name

    municipality = _extract_activity_municipality(activity_payload)
    project_id = str(activity_payload.get("project_id") or "").strip()
    if project_id and municipality:
        inferred_front = project_front_scope_map.get(project_id, {}).get(_normalize_lookup_key(municipality), "")
        if inferred_front:
            return inferred_front
    return None


def _effective_assignee_user_id(activity_payload: dict[str, Any]) -> str:
    return str(
        activity_payload.get("assigned_to_user_id")
        or activity_payload.get("created_by_user_id")
        or ""
    ).strip()


def _load_user_names(client, user_ids: set[str]) -> dict[str, str]:
    result: dict[str, str] = {}
    normalized_ids = [user_id for user_id in user_ids if user_id]
    if not normalized_ids:
        return result
    refs = [client.collection("users").document(user_id) for user_id in normalized_ids]
    if hasattr(client, "get_all"):
        for snap in client.get_all(refs):
            if not snap.exists:
                continue
            payload = snap.to_dict() or {}
            name = str(
                payload.get("full_name")
                or payload.get("fullName")
                or payload.get("display_name")
                or payload.get("name")
                or payload.get("email")
                or ""
            ).strip()
            if name:
                result[snap.id] = name
        return result

    # Test fallback for fake clients without get_all.
    for ref in refs:
        snap = ref.get()
        if not snap.exists:
            continue
        payload = snap.to_dict() or {}
        name = str(
            payload.get("full_name")
            or payload.get("fullName")
            or payload.get("display_name")
            or payload.get("name")
            or payload.get("email")
            or ""
        ).strip()
        if name:
            result[snap.id] = name
    return result


def _count_evidences(client, activity_ids: set[str]) -> dict[str, int]:
    normalized_ids = [activity_id for activity_id in activity_ids if activity_id]
    counts: dict[str, int] = {activity_id: 0 for activity_id in normalized_ids}
    if not normalized_ids:
        return counts

    # Firestore IN queries support up to 30 values per query.
    chunk_size = 30
    for i in range(0, len(normalized_ids), chunk_size):
        chunk = normalized_ids[i : i + chunk_size]
        for snap in client.collection("evidences").where("activity_id", "in", chunk).stream():
            payload = snap.to_dict() or {}
            activity_id = str(payload.get("activity_id") or "").strip()
            if activity_id in counts:
                counts[activity_id] += 1
    return counts


def _wizard_payload_evidence_rows(activity_payload: dict[str, Any]) -> list[dict[str, Any]]:
    wizard_payload = activity_payload.get("wizard_payload")
    if not isinstance(wizard_payload, dict):
        return []
    raw = wizard_payload.get("evidences")
    if not isinstance(raw, list):
        return []
    return [row for row in raw if isinstance(row, dict)]


def _wizard_payload_evidence_count(activity_payload: dict[str, Any]) -> int:
    return len(_wizard_payload_evidence_rows(activity_payload))


def _required_fields_ok(activity_payload: dict[str, Any]) -> bool:
    title_ok = bool(str(activity_payload.get("title") or "").strip())
    description_ok = bool(str(activity_payload.get("description") or "").strip())
    if title_ok and description_ok:
        return True

    wizard_payload = activity_payload.get("wizard_payload")
    if not isinstance(wizard_payload, dict):
        return False

    context_payload = wizard_payload.get("context")
    if not isinstance(context_payload, dict):
        return False

    required_context_keys = (
        "activity_type",
        "subcategory",
        "topic",
        "purpose",
    )
    present = 0
    for key in required_context_keys:
        if str(context_payload.get(key) or "").strip():
            present += 1

    # Consider fields complete if at least key context fields are already captured.
    return present >= 2


def _sync_state_from_activity(activity_payload: dict) -> str:
    return infer_sync_state(
        str(activity_payload.get("sync_state") or ""),
        has_local_changes=bool(
            activity_payload.get("pending_sync")
            or activity_payload.get("outbox_pending")
            or activity_payload.get("ready_to_sync")
            or activity_payload.get("local_only")
        ),
        has_sync_error=bool(
            activity_payload.get("sync_error")
            or activity_payload.get("last_sync_error")
            or activity_payload.get("sync_failed")
        ),
        sync_in_progress=bool(
            activity_payload.get("sync_in_progress")
            or activity_payload.get("syncing")
        ),
    )


def _pk_label(pk_start: Any, pk_end: Any) -> str | None:
    def _fmt(val: Any) -> str | None:
        try:
            n = int(val)
            return f"{n // 1000}+{n % 1000:03d}"
        except (TypeError, ValueError):
            return str(val) if val else None

    start = _fmt(pk_start)
    end   = _fmt(pk_end)
    if start is None:
        return None
    if end is not None and pk_end != pk_start:
        return f"PK {start}-{end}"
    return f"PK {start}"



@router.get("/queue", response_model=ReviewQueueResponse)
def review_queue(
    project_id: str | None = Query(None),
    front_id: str | None = Query(None),
    status_filter: str | None = Query(None, alias="status"),
    only_conflicts: bool = Query(False),
    q: str | None = Query(None),
    from_dt: datetime | None = Query(None, alias="from"),
    to_dt: datetime | None = Query(None, alias="to"),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    _current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO", "LECTOR"])),
):
    client = get_firestore_client()
    now = datetime.now(timezone.utc)
    # Apply project_id filter server-side to avoid a full collection scan.
    acts_query = client.collection("activities")
    if project_id:
        acts_query = acts_query.where("project_id", "==", project_id)
    activities_docs = [d.to_dict() or {} for d in acts_query.stream()]
    scoped_activities: list[dict[str, Any]] = []
    front_ids: set[str] = set()
    user_ids: set[str] = set()
    activity_ids: set[str] = set()
    project_ids: set[str] = set()
    for activity in activities_docs:
        # Exclude soft-deleted activities from the review queue.
        if activity.get("deleted_at") is not None:
            continue

        if front_id and str(activity.get("front_id") or "") != front_id:
            continue

        created_at = _safe_dt(activity.get("created_at"), now)
        if from_dt and created_at < from_dt:
            continue
        if to_dt and created_at > to_dt:
            continue

        scoped_activities.append(activity)
        front_ids.add(str(activity.get("front_id") or "").strip())
        user_ids.add(_effective_assignee_user_id(activity))
        activity_ids.add(str(activity.get("uuid") or "").strip())
        project_ids.add(str(activity.get("project_id") or "").strip())

    fronts_map = _load_front_names(client, front_ids)
    project_front_scope_map = _load_project_front_scope_map(client, project_ids)
    users_map = _load_user_names(client, user_ids)
    evidence_count_by_activity = _count_evidences(client, activity_ids)

    items: list[ReviewQueueItemOut] = []
    counters = {"pending": 0, "changed": 0, "gps_critical": 0, "rejected": 0}

    for activity in scoped_activities:
        created_at = _safe_dt(activity.get("created_at"), now)
        updated_at = _safe_dt(activity.get("updated_at"), now)

        lat = activity.get("latitude")
        lon = activity.get("longitude")
        gps_critical = bool(activity.get("gps_mismatch", False)) or not (lat and lon)
        activity_uuid_str = str(activity.get("uuid") or "").strip()
        evidence_count = evidence_count_by_activity.get(activity_uuid_str, 0)
        if evidence_count == 0:
            legacy_activity_id = str(activity.get("server_id") or "").strip()
            if legacy_activity_id:
                evidence_count = sum(
                    1
                    for _ in client.collection("evidences")
                    .where("activity_id", "==", legacy_activity_id)
                    .stream()
                )
        if evidence_count == 0:
            evidence_count = _wizard_payload_evidence_count(activity)
        execution_state = _normalize_execution_state(activity.get("execution_state"))
        review_decision = _normalize_review_decision(activity.get("review_decision"))
        status_value = _review_status_from_firestore(activity)
        if not _should_include_in_review_queue(execution_state, status_value, evidence_count):
            continue
        missing_evidence = evidence_count == 0
        catalog_change_pending = bool(activity.get("catalog_changed", False)) or bool(
            activity.get("description") and "catalog" in str(activity.get("description")).lower()
        )
        # GPS remains informational for now; it must not block approval flow.
        checklist_incomplete = missing_evidence
        has_conflicts = catalog_change_pending or checklist_incomplete
        severity = _severity_from_flags(gps_critical, has_conflicts, missing_evidence)
        pk_label = _pk_label(activity.get("pk_start"), activity.get("pk_end")) or "PK 0+000"

        assigned_uid = _effective_assignee_user_id(activity)
        municipality_value = _extract_activity_municipality(activity)
        front_name = _resolve_activity_front_name(activity, fronts_map, project_front_scope_map)
        projection = build_canonical_flow_projection(
            execution_state=execution_state,
            review_decision=review_decision,
            sync_state=_sync_state_from_activity(activity),
        )
        try:
            item = ReviewQueueItemOut(
                id=UUID(str(activity.get("uuid"))),
                pk=pk_label,
                front=front_name or None,
                municipality=municipality_value,
                activity_type=str(activity.get("activity_type_code") or ""),
                title=str(activity.get("title") or "") or None,
                project_id=str(activity.get("project_id") or "") or None,
                assigned_to_user_name=users_map.get(assigned_uid) if assigned_uid else None,
                risk="alto" if severity == "HIGH" else "medio" if severity == "MED" else "bajo",
                created_at=created_at,
                updated_at=updated_at,
                status=status_value,
                gps_critical=gps_critical,
                missing_evidence=missing_evidence,
                catalog_change_pending=catalog_change_pending,
                checklist_incomplete=checklist_incomplete,
                has_conflicts=has_conflicts,
                severity=severity,
                evidence_count=evidence_count,
                conflict_count=1 if has_conflicts else 0,
                lat=float(lat) if lat not in (None, "") else None,
                lon=float(lon) if lon not in (None, "") else None,
                operational_state=projection["operational_state"],
                sync_state=projection["sync_state"],
                review_state=projection["review_state"],
                next_action=projection["next_action"],
            )
        except Exception as exc:
            logger.warning(
                "SKIP_MALFORMED_REVIEW_ITEM uuid=%s project_id=%s error=%s",
                activity.get("uuid", "?"),
                activity.get("project_id", "?"),
                exc,
            )
            continue

        searchable = f"{item.pk} {item.front or ''} {item.activity_type} {activity.get('title') or ''}".lower()
        if q and q.strip() and q.strip().lower() not in searchable:
            continue
        if only_conflicts and not item.has_conflicts:
            continue
        if status_filter and item.status != status_filter:
            continue

        if item.status == "PENDING_REVIEW":
            counters["pending"] += 1
        if item.catalog_change_pending or item.has_conflicts:
            counters["changed"] += 1
        if item.gps_critical:
            counters["gps_critical"] += 1
        if item.status == "REJECTED":
            counters["rejected"] += 1

        items.append(item)

    items.sort(key=lambda x: x.updated_at, reverse=True)
    start = (page - 1) * page_size
    paged_items = items[start : start + page_size]
    return ReviewQueueResponse(
        items=paged_items,
        counters=ReviewQueueCountersOut(
            pending=counters["pending"],
            changed=counters["changed"],
            gps_critical=counters["gps_critical"],
            rejected=counters["rejected"],
        ),
    )


@router.get("/activity/{activity_id}", response_model=ReviewActivityOut)
def review_activity_detail(
    activity_id: str,
    _current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO", "LECTOR"])),
):
    try:
        activity_uuid = UUID(activity_id)
    except ValueError:
        raise api_error(status_code=status.HTTP_400_BAD_REQUEST, code="REVIEW_INVALID_ACTIVITY_ID", message="Invalid activity id")

    client = get_firestore_client()
    activity_snap = client.collection("activities").document(str(activity_uuid)).get()
    if not activity_snap.exists:
        raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="REVIEW_ACTIVITY_NOT_FOUND", message="Activity not found")
    activity = activity_snap.to_dict() or {}
    wizard_payload_raw = activity.get("wizard_payload")
    wizard_payload = wizard_payload_raw if isinstance(wizard_payload_raw, dict) else None
    municipality_value = _extract_activity_municipality(activity)
    project_front_scope_map = _load_project_front_scope_map(
        client,
        {str(activity.get("project_id") or "").strip()},
    )
    front_lookup: dict[str, str] = {}
    front_id = activity.get("front_id")
    if front_id:
        front_snap = client.collection("fronts").document(str(front_id)).get()
        if front_snap.exists:
            front_name = str((front_snap.to_dict() or {}).get("name") or "").strip()
            if front_name:
                front_lookup[str(front_id)] = front_name
    front_name = _resolve_activity_front_name(activity, front_lookup, project_front_scope_map)
    status_value = _review_status_from_firestore(activity)
    gps_critical = bool(activity.get("gps_mismatch", False)) or not (activity.get("latitude") and activity.get("longitude"))
    # Use a targeted query instead of streaming all evidences (avoids full collection scan).
    evidences = [
        d.to_dict() or {}
        for d in client.collection("evidences")
            .where("activity_id", "==", str(activity_uuid))
            .stream()
    ]
    wizard_payload_evidence_rows = _wizard_payload_evidence_rows(activity)
    total_evidence_count = max(len(evidences), len(wizard_payload_evidence_rows))
    quality_flags = {
        "evidence_ok": total_evidence_count > 0,
        "gps_ok": not gps_critical,
        "catalog_ok": not bool(activity.get("catalog_changed", False)),
        # Keep required_fields tied to business fields only (not GPS).
        "required_fields_ok": _required_fields_ok(activity),
    }
    changeset: list[ReviewChangeFieldOut] = []
    if bool(activity.get("catalog_changed", False)):
        changeset.append(
            ReviewChangeFieldOut(
                field_key="description",
                original="DescripciÃ³n original",
                proposed=str(activity.get("description") or ""),
                conflict_type="catalog_change",
                suggested_options=["ACCEPT", "RESTORE", "CHOOSE_CATALOG"],
            )
        )
    # Use compound index (entity ASC, entity_id ASC, created_at DESC) — already in
    # firestore.indexes.json. Replaces a full audit_logs scan with a targeted query.
    history_rows = [
        d.to_dict() or {}
        for d in client.collection("audit_logs")
            .where("entity", "==", "activity")
            .where("entity_id", "==", str(activity_uuid))
            .order_by("created_at", direction="DESCENDING")
            .limit(20)
            .stream()
    ]
    history_rows.sort(key=lambda row: _safe_dt(row.get("created_at"), datetime.now(timezone.utc)), reverse=True)
    history = [
        {
            "at": _safe_dt(row.get("created_at"), datetime.now(timezone.utc)).isoformat(),
            "actor": row.get("actor_email"),
            "action": row.get("action"),
            "details": sanitize_audit_details(row.get("details_json")),
        }
        for row in history_rows[:20]
    ]
    return ReviewActivityOut(
        id=activity_uuid,
        project_id=str(activity.get("project_id") or ""),
        front=front_name,
        activity_type=str(activity.get("activity_type_code") or ""),
        title=activity.get("title"),
        description=activity.get("description"),
        wizard_payload=wizard_payload,
        municipality=municipality_value,
        pk=_pk_label(activity.get("pk_start"), activity.get("pk_end")),
        status=status_value,
        quality_flags=quality_flags,
        changeset=changeset,
        history=history,
    )


@router.get("/activity/{activity_id}/evidences", response_model=list[ReviewEvidenceOut])
def review_activity_evidences(
    activity_id: str,
    _current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO", "LECTOR"])),
):
    try:
        activity_uuid = UUID(activity_id)
    except ValueError:
        raise api_error(status_code=status.HTTP_400_BAD_REQUEST, code="REVIEW_INVALID_ACTIVITY_ID", message="Invalid activity id")

    client = get_firestore_client()
    # Query evidences for this activity from Firestore.
    evidences_docs = [
        d.to_dict() or {}
        for d in client.collection("evidences")
            .where("activity_id", "==", str(activity_uuid))
            .stream()
    ]
    # Only return evidences that have actually been uploaded (have valid object_path).
    # Do NOT create fallback evidences from wizard_payload; if no evidences exist in Firestore,
    # the activity either has no evidence or evidence was not yet uploaded properly.
    evidences_docs.sort(key=lambda row: _safe_dt(row.get("created_at"), datetime.now(timezone.utc)))
    return [
        ReviewEvidenceOut(
            id=UUID(str(row.get("id"))),
            takenAt=_safe_dt(row.get("created_at"), datetime.now(timezone.utc)),
            lat=None,
            lng=None,
            accuracy=None,
            device=None,
            description=row.get("caption") or row.get("description") or row.get("descripcion"),
            gcsKey=row.get("object_path"),
            status="UPLOADED" if row.get("object_path") else "PENDING",
        )
        for row in evidences_docs
        if row.get("id") and row.get("object_path")
    ]


@router.post("/evidence/{evidence_id}/validate", status_code=status.HTTP_200_OK)
def review_validate_evidence(
    evidence_id: str,
    body: ReviewEvidenceValidateIn,
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR"])),
):
    try:
        evidence_uuid = UUID(evidence_id)
    except ValueError:
        raise api_error(status_code=status.HTTP_400_BAD_REQUEST, code="REVIEW_INVALID_EVIDENCE_ID", message="Invalid evidence id")

    client = get_firestore_client()
    evidence_ref = client.collection("evidences").document(str(evidence_uuid))
    if not evidence_ref.get().exists:
        raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="REVIEW_EVIDENCE_NOT_FOUND", message="Evidence not found")
    now = datetime.now(timezone.utc)
    client.collection("review_evidence_actions").document(str(uuid4())).set(
        {
            "evidence_id": str(evidence_uuid),
            "action": "REVIEW_EVIDENCE_VALIDATE",
            "status": body.status,
            "reason_code": body.reason_code,
            "comment": body.comment,
            "actor_id": str(getattr(current_user, "id", "")),
            "actor_email": getattr(current_user, "email", ""),
            "created_at": now,
        }
    )
    write_firestore_audit_log(
        action="REVIEW_EVIDENCE_VALIDATE",
        entity="evidence",
        entity_id=str(evidence_uuid),
        actor=current_user,
        details={
            "status": body.status,
            "reason_code": body.reason_code,
            "comment": body.comment,
        },
    )
    return {"ok": True}


@router.patch("/evidence/{evidence_id}", status_code=status.HTTP_200_OK)
def review_patch_evidence(
    evidence_id: str,
    body: ReviewEvidencePatchIn,
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
):
    try:
        evidence_uuid = UUID(evidence_id)
    except ValueError:
        raise api_error(status_code=status.HTTP_400_BAD_REQUEST, code="REVIEW_INVALID_EVIDENCE_ID", message="Invalid evidence id")

    client = get_firestore_client()
    evidence_ref = client.collection("evidences").document(str(evidence_uuid))
    if not evidence_ref.get().exists:
        raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="REVIEW_EVIDENCE_NOT_FOUND", message="Evidence not found")
    now = datetime.now(timezone.utc)
    evidence_ref.set({"caption": body.description, "updated_at": now}, merge=True)
    client.collection("review_evidence_actions").document(str(uuid4())).set(
        {
            "evidence_id": str(evidence_uuid),
            "action": "REVIEW_EVIDENCE_PATCH",
            "description": body.description,
            "actor_id": str(getattr(current_user, "id", "")),
            "actor_email": getattr(current_user, "email", ""),
            "created_at": now,
        }
    )
    write_firestore_audit_log(
        action="REVIEW_EVIDENCE_PATCH",
        entity="evidence",
        entity_id=str(evidence_uuid),
        actor=current_user,
        details={"description": body.description},
    )
    return {"ok": True}


@router.post("/activity/{activity_id}/decision", response_model=ReviewDecisionOut)
def review_decision(
    activity_id: str,
    body: ReviewDecisionIn,
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR"])),
):
    try:
        activity_uuid = UUID(activity_id)
    except ValueError:
        raise api_error(status_code=status.HTTP_400_BAD_REQUEST, code="REVIEW_INVALID_ACTIVITY_ID", message="Invalid activity id")

    decision = body.decision.upper().strip()
    if decision not in {"APPROVE", "REJECT", "APPROVE_EXCEPTION"}:
        raise api_error(status_code=status.HTTP_400_BAD_REQUEST, code="REVIEW_INVALID_DECISION", message="Invalid decision")

    if decision == "APPROVE_EXCEPTION" and not (body.comment and body.comment.strip()):
        raise api_error(status_code=status.HTTP_400_BAD_REQUEST, code="REVIEW_EXCEPTION_REQUIRES_COMMENT", message="Exception approval requires comment")

    if decision == "APPROVE_EXCEPTION" and not user_has_any_role(current_user, ["ADMIN"], None):
        raise api_error(status_code=status.HTTP_403_FORBIDDEN, code="REVIEW_EXCEPTION_REQUIRES_ADMIN", message="APPROVE_EXCEPTION requires ADMIN role")

    client = get_firestore_client()
    now = datetime.now(timezone.utc)

    activity_ref = client.collection("activities").document(str(activity_uuid))
    activity_snap = activity_ref.get()
    if not activity_snap.exists:
        docs = (
            client.collection("activities")
            .where("uuid", "==", str(activity_uuid))
            .limit(1)
            .stream()
        )
        activity_doc = next(iter(docs), None)
        if activity_doc is None:
            raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="REVIEW_ACTIVITY_NOT_FOUND", message="Activity not found")
        activity_ref = activity_doc.reference
        activity_payload = activity_doc.to_dict() or {}
    else:
        activity_payload = activity_snap.to_dict() or {}

    if decision == "REJECT":
        if not body.reject_reason_code:
            raise api_error(status_code=status.HTTP_400_BAD_REQUEST, code="REVIEW_REJECT_REASON_REQUIRED", message="reject_reason_code is required when decision is REJECT")

    next_state = COMPLETADA if decision in {"APPROVE", "APPROVE_EXCEPTION"} else REVISION_PENDIENTE
    persisted_review_decision = "CHANGES_REQUIRED" if decision == "REJECT" else decision
    next_sync_version = int(activity_payload.get("sync_version") or 0) + 1
    action = "REVIEW_APPROVE_EXCEPTION" if decision == "APPROVE_EXCEPTION" else ("REVIEW_APPROVE" if decision == "APPROVE" else "REVIEW_REJECT")

    activity_ref.set(
        {
            "execution_state": next_state,
            "sync_version": next_sync_version,
            "updated_at": now,
            "review_decision": persisted_review_decision,
            "review_reject_reason_code": body.reject_reason_code,
            "review_comment": body.comment,
            "deleted_at": None,
            "last_reviewed_by": str(getattr(current_user, "id", "")),
            "last_reviewed_at": now,
        },
        merge=True,
    )

    client.collection("review_decisions").document(str(uuid4())).set(
        {
            "activity_id": str(activity_uuid),
            "project_id": activity_payload.get("project_id"),
            "decision": decision,
            "status": "REJECTED" if decision == "REJECT" else "APPROVED",
            "action": action,
            "reject_reason_code": body.reject_reason_code,
            "comment": body.comment,
            "field_resolutions": [resolution.model_dump() for resolution in body.field_resolutions],
            "apply_to_similar": body.apply_to_similar,
            "actor_id": str(getattr(current_user, "id", "")),
            "actor_email": getattr(current_user, "email", ""),
            "created_at": now,
            "activity_sync_version": next_sync_version,
        }
    )

    effective_assignee_user_id = (
        str(
            activity_payload.get("assigned_to_user_id")
            or activity_payload.get("created_by_user_id")
            or ""
        ).strip()
        or None
    )

    if decision == "REJECT" and body.comment:
        client.collection("observations").document(str(uuid4())).set(
            {
                "project_id": activity_payload.get("project_id"),
                "activity_id": str(activity_uuid),
                "assignee_user_id": effective_assignee_user_id,
                "tags_json": json.dumps(["review", "correction"]),
                "message": body.comment,
                "severity": "HIGH",
                "status": "OPEN",
                "created_at": now,
            }
        )
    try:
        notify_review_decision(
            project_id=str(activity_payload.get("project_id") or ""),
            activity_id=str(activity_uuid),
            decision=persisted_review_decision,
            assigned_user_id=effective_assignee_user_id,
            comment=body.comment,
        )
    except Exception:
        logger.exception("REVIEW_NOTIFY_FAILED activity_id=%s", activity_uuid)

    assignee_principal = (
        get_firestore_user_by_id(effective_assignee_user_id)
        if effective_assignee_user_id
        else None
    )
    write_firestore_audit_log(
        action=action,
        entity="activity",
        entity_id=str(activity_uuid),
        actor=current_user,
        details={
            "project_id": str(activity_payload.get("project_id") or "").strip().upper() or None,
            "decision": decision,
            "status": "REJECTED" if decision == "REJECT" else "APPROVED",
            "next_state": next_state,
            "reject_reason_code": body.reject_reason_code,
            "comment": body.comment,
            "assigned_to_user_id": effective_assignee_user_id,
            "assigned_to_name": assignee_principal.full_name if assignee_principal else None,
            "assigned_to_role": (assignee_principal.roles[0] if assignee_principal and assignee_principal.roles else None),
        },
    )

    return ReviewDecisionOut(
        ok=True,
        status="CHANGES_REQUIRED" if decision == "REJECT" else "APPROVED",
    )


@router.get("/reject-playbook", response_model=ReviewRejectPlaybookResponse)
def review_reject_playbook(
    project_id: str | None = Query(None),
    _current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO", "LECTOR"])),
):
    _ = project_id
    client = get_firestore_client()
    rows = [d.to_dict() or {} for d in client.collection("reject_reasons").stream()]
    rows = [row for row in rows if bool(row.get("is_active", True))]
    rows.sort(key=lambda row: str(row.get("reason_code") or ""))
    if not rows:
        rows = [
            {"reason_code": "PHOTO_BLUR", "label": "Foto borrosa o ilegible", "severity": "MED", "requires_comment": False},
            {"reason_code": "GPS_MISMATCH", "label": "GPS no coincide con PK declarados", "severity": "HIGH", "requires_comment": False},
            {"reason_code": "MISSING_INFO", "label": "Informacion obligatoria ausente", "severity": "MED", "requires_comment": True},
        ]
    return ReviewRejectPlaybookResponse(
        items=[
            ReviewRejectPlaybookItemOut(
                reason_code=str(row.get("reason_code") or ""),
                label=str(row.get("label") or ""),
                severity=str(row.get("severity") or "MED"),
                requires_comment=bool(row.get("requires_comment", False)),
            )
            for row in rows
            if row.get("reason_code") and row.get("label")
        ]
    )


@router.post("/reject-reasons", response_model=ReviewRejectPlaybookItemOut)
def create_reject_reason(
    body: ReviewRejectReasonCreateIn,
    current_user: Any = Depends(require_any_role(["ADMIN"])),
):
    reason_code = body.reason_code.strip().upper()
    if not reason_code:
        raise api_error(status_code=status.HTTP_400_BAD_REQUEST, code="REVIEW_REJECT_REASON_CODE_REQUIRED", message="reason_code is required")

    client = get_firestore_client()
    existing = [
        d.to_dict() or {}
        for d in client.collection("reject_reasons").stream()
        if str((d.to_dict() or {}).get("reason_code") or "") == reason_code
    ]
    if existing:
        raise api_error(status_code=status.HTTP_409_CONFLICT, code="REVIEW_REJECT_REASON_DUPLICATE", message=f"Reason {reason_code} already exists")

    payload = {
        "reason_code": reason_code,
        "label": body.label.strip(),
        "severity": body.severity.strip().upper() if body.severity else "MED",
        "requires_comment": body.requires_comment,
        "is_active": True,
        "created_by_id": str(getattr(current_user, "id", "")),
        "created_at": datetime.now(timezone.utc),
    }
    client.collection("reject_reasons").document(reason_code).set(payload)
    return ReviewRejectPlaybookItemOut(
        reason_code=payload["reason_code"],
        label=payload["label"],
        severity=payload["severity"],
        requires_comment=payload["requires_comment"],
    )

