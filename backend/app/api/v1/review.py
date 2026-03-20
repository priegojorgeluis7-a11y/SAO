import json
import logging
from datetime import datetime, timezone
from typing import Any
from uuid import UUID, uuid4

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
from app.services.audit_redaction import sanitize_audit_details

router = APIRouter(prefix="/review", tags=["review"])
logger = logging.getLogger(__name__)

REVISION_PENDIENTE = "REVISION_PENDIENTE"
COMPLETADA = "COMPLETADA"


def _review_status_from_firestore(activity_payload: dict) -> str:
    decision = str(activity_payload.get("review_decision") or "").upper()
    if decision == "REJECT":
        return "RECHAZADO"
    if decision in {"APPROVE", "APPROVE_EXCEPTION"}:
        return "APROBADO"
    if str(activity_payload.get("execution_state") or "") == REVISION_PENDIENTE:
        return "PENDIENTE_REVISION"
    return "PENDIENTE_REVISION"


def _safe_dt(value: object, fallback: datetime) -> datetime:
    if isinstance(value, datetime):
        return value
    return fallback


def _should_include_in_review_queue(execution_state: str | None, review_status: str, evidence_count: int) -> bool:
    # Keep rejected activities visible in review queue/history views.
    if review_status == "RECHAZADO":
        return True
    if review_status != "PENDIENTE_REVISION":
        return False
    return execution_state in {REVISION_PENDIENTE, COMPLETADA}


def _severity_from_flags(gps_critical: bool, has_conflicts: bool, missing_evidence: bool) -> str:
    if gps_critical or has_conflicts:
        return "HIGH"
    if missing_evidence:
        return "MED"
    return "LOW"


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
    _current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO", "LECTOR"])),
):
    client = get_firestore_client()
    now = datetime.now(timezone.utc)
    activities_docs = [d.to_dict() or {} for d in client.collection("activities").stream()]
    fronts_map = {
        str(doc.id): str((doc.to_dict() or {}).get("name") or "")
        for doc in client.collection("fronts").stream()
    }
    users_map: dict[str, str] = {}
    for doc in client.collection("users").stream():
        u = doc.to_dict() or {}
        name = str(u.get("display_name") or u.get("name") or u.get("email") or "").strip()
        if name:
            users_map[str(doc.id)] = name
    evidences_docs = [d.to_dict() or {} for d in client.collection("evidences").stream()]
    evidence_count_by_activity: dict[str, int] = {}
    for ev in evidences_docs:
        aid = str(ev.get("activity_id") or "")
        if not aid:
            continue
        evidence_count_by_activity[aid] = evidence_count_by_activity.get(aid, 0) + 1

    items: list[ReviewQueueItemOut] = []
    counters = {"pending": 0, "changed": 0, "gps_critical": 0, "rejected": 0}

    for activity in activities_docs:
        if project_id and str(activity.get("project_id") or "") != project_id:
            continue
        if front_id and str(activity.get("front_id") or "") != front_id:
            continue

        created_at = _safe_dt(activity.get("created_at"), now)
        updated_at = _safe_dt(activity.get("updated_at"), now)
        if from_dt and created_at < from_dt:
            continue
        if to_dt and created_at > to_dt:
            continue

        lat = activity.get("latitude")
        lon = activity.get("longitude")
        gps_critical = bool(activity.get("gps_mismatch", False)) or not (lat and lon)
        evidence_count = evidence_count_by_activity.get(str(activity.get("uuid") or ""), 0)
        execution_state = str(activity.get("execution_state") or "")
        status_value = _review_status_from_firestore(activity)
        if not _should_include_in_review_queue(execution_state, status_value, evidence_count):
            continue
        missing_evidence = evidence_count == 0
        catalog_change_pending = bool(activity.get("catalog_changed", False)) or bool(
            activity.get("description") and "catalog" in str(activity.get("description")).lower()
        )
        checklist_incomplete = missing_evidence or gps_critical
        has_conflicts = catalog_change_pending or checklist_incomplete
        severity = _severity_from_flags(gps_critical, has_conflicts, missing_evidence)
        pk_label = _pk_label(activity.get("pk_start"), activity.get("pk_end")) or "PK 0+000"

        assigned_uid = str(activity.get("assigned_to_user_id") or "").strip()
        try:
            item = ReviewQueueItemOut(
                id=UUID(str(activity.get("uuid"))),
                pk=pk_label,
                front=fronts_map.get(str(activity.get("front_id") or "")) or None,
                municipality=None,
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

        if item.status == "PENDIENTE_REVISION":
            counters["pending"] += 1
        if item.catalog_change_pending or item.has_conflicts:
            counters["changed"] += 1
        if item.gps_critical:
            counters["gps_critical"] += 1
        if item.status == "RECHAZADO":
            counters["rejected"] += 1

        items.append(item)

    items.sort(key=lambda x: x.updated_at, reverse=True)
    return ReviewQueueResponse(
        items=items[:400],
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
    location_payload = wizard_payload.get("location") if isinstance(wizard_payload, dict) else None
    municipality_from_payload = (
        str((location_payload or {}).get("municipio") or "").strip()
        if isinstance(location_payload, dict)
        else ""
    )
    municipality_value = municipality_from_payload or None
    front_name = None
    front_id = activity.get("front_id")
    if front_id:
        front_snap = client.collection("fronts").document(str(front_id)).get()
        if front_snap.exists:
            front_name = str((front_snap.to_dict() or {}).get("name") or "") or None
    status_value = _review_status_from_firestore(activity)
    gps_critical = bool(activity.get("gps_mismatch", False)) or not (activity.get("latitude") and activity.get("longitude"))
    evidences = [
        d.to_dict() or {}
        for d in client.collection("evidences").stream()
        if str((d.to_dict() or {}).get("activity_id") or "") == str(activity_uuid)
    ]
    quality_flags = {
        "evidence_ok": len(evidences) > 0,
        "gps_ok": not gps_critical,
        "catalog_ok": not bool(activity.get("catalog_changed", False)),
        "required_fields_ok": bool(activity.get("title") and activity.get("description")),
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
    history_rows = [
        d.to_dict() or {}
        for d in client.collection("audit_logs").stream()
        if (d.to_dict() or {}).get("entity") == "activity"
        and str((d.to_dict() or {}).get("entity_id") or "") == str(activity_uuid)
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
    evidences_docs = [
        d.to_dict() or {}
        for d in client.collection("evidences").stream()
        if str((d.to_dict() or {}).get("activity_id") or "") == str(activity_uuid)
    ]
    evidences_docs.sort(key=lambda row: _safe_dt(row.get("created_at"), datetime.now(timezone.utc)))
    return [
        ReviewEvidenceOut(
            id=UUID(str(row.get("id"))),
            takenAt=_safe_dt(row.get("created_at"), datetime.now(timezone.utc)),
            lat=None,
            lng=None,
            accuracy=None,
            device=None,
            description=row.get("caption"),
            gcsKey=row.get("object_path"),
            status="UPLOADED" if row.get("object_path") else "PENDING",
        )
        for row in evidences_docs
        if row.get("id")
    ]


@router.post("/evidence/{evidence_id}/validate", status_code=status.HTTP_200_OK)
def review_validate_evidence(
    evidence_id: str,
    body: ReviewEvidenceValidateIn,
    _current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR"])),
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
    client.collection("audit_logs").document(str(uuid4())).set(
        {
            "id": str(uuid4()),
            "created_at": now,
            "actor_id": str(getattr(current_user, "id", "")),
            "actor_email": getattr(current_user, "email", ""),
            "action": "REVIEW_EVIDENCE_VALIDATE",
            "entity": "evidence",
            "entity_id": str(evidence_uuid),
            "details_json": json.dumps({"status": body.status, "reason_code": body.reason_code, "comment": body.comment}),
        }
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
    next_sync_version = int(activity_payload.get("sync_version") or 0) + 1
    action = "REVIEW_APPROVE_EXCEPTION" if decision == "APPROVE_EXCEPTION" else ("REVIEW_APPROVE" if decision == "APPROVE" else "REVIEW_REJECT")

    activity_ref.set(
        {
            "execution_state": next_state,
            "sync_version": next_sync_version,
            "updated_at": now,
            "review_decision": decision,
            "review_reject_reason_code": body.reject_reason_code,
            "review_comment": body.comment,
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
            "status": "RECHAZADO" if decision == "REJECT" else "APROBADO",
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

    if decision == "REJECT" and body.comment:
        client.collection("observations").document(str(uuid4())).set(
            {
                "project_id": activity_payload.get("project_id"),
                "activity_id": str(activity_uuid),
                "assignee_user_id": activity_payload.get("assigned_to_user_id"),
                "tags_json": json.dumps(["review", "correction"]),
                "message": body.comment,
                "severity": "HIGH",
                "status": "OPEN",
                "created_at": now,
            }
        )

    return ReviewDecisionOut(ok=True, status="RECHAZADO" if decision == "REJECT" else "APROBADO")


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

