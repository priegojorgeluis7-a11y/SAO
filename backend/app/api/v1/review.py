import json
from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import require_any_role, user_has_any_role
from app.core.database import get_db
from app.models.activity import Activity, ExecutionState
from app.models.catalog import CATActivityType, CATEvidenceRule, EntityType
from app.models.audit_log import AuditLog
from app.models.evidence import Evidence
from app.models.front import Front
from app.models.observation import Observation
from app.models.reject_reason import RejectReason
from app.models.user import User
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
from app.services.audit_service import write_audit_log

router = APIRouter(prefix="/review", tags=["review"])


def _status_from_audit(latest_action: str | None, activity: Activity) -> str:
    if latest_action == "REVIEW_REJECT":
        return "RECHAZADO"
    if latest_action == "REVIEW_APPROVE":
        return "APROBADO"
    if latest_action == "REVIEW_APPROVE_EXCEPTION":
        return "APROBADO"
    if activity.execution_state == ExecutionState.REVISION_PENDIENTE.value:
        return "PENDIENTE_REVISION"
    return "PENDIENTE_REVISION"


def _severity_from_flags(gps_critical: bool, has_conflicts: bool, missing_evidence: bool) -> str:
    if gps_critical or has_conflicts:
        return "HIGH"
    if missing_evidence:
        return "MED"
    return "LOW"


def _has_valid_gps_coordinates(activity: Activity) -> bool:
    if not activity.latitude or not activity.longitude:
        return False

    try:
        lat = float(str(activity.latitude).strip())
        lon = float(str(activity.longitude).strip())
    except (TypeError, ValueError):
        return False

    return -90.0 <= lat <= 90.0 and -180.0 <= lon <= 180.0


def _requires_gps_for_activity(
    activity: Activity,
    db: Session,
    cache: dict[tuple[str, str], bool],
) -> bool:
    cache_key = (str(activity.catalog_version_id), activity.activity_type_code)
    if cache_key in cache:
        return cache[cache_key]

    activity_type = (
        db.query(CATActivityType)
        .filter(
            CATActivityType.version_id == activity.catalog_version_id,
            CATActivityType.code == activity.activity_type_code,
            CATActivityType.is_active.is_(True),
        )
        .first()
    )

    if activity_type is None:
        cache[cache_key] = False
        return False

    evidence_rule = (
        db.query(CATEvidenceRule)
        .filter(
            CATEvidenceRule.version_id == activity.catalog_version_id,
            CATEvidenceRule.entity_type == EntityType.ACTIVITY,
            CATEvidenceRule.type_id == activity_type.id,
        )
        .first()
    )

    requires_gps = bool(evidence_rule and evidence_rule.requires_gps)
    cache[cache_key] = requires_gps
    return requires_gps


def _pk_outside_front_range(activity: Activity, front: Front | None) -> bool:
    if front is None:
        return False
    if front.pk_start is None or front.pk_end is None:
        return False

    end_pk = activity.pk_end if activity.pk_end is not None else activity.pk_start
    return activity.pk_start < front.pk_start or end_pk > front.pk_end


def _compute_gps_critical(
    activity: Activity,
    front: Front | None,
    db: Session,
    gps_requirement_cache: dict[tuple[str, str], bool],
) -> bool:
    requires_gps = _requires_gps_for_activity(activity, db, gps_requirement_cache)
    gps_missing_or_invalid = not _has_valid_gps_coordinates(activity)
    pk_outside_front = _pk_outside_front_range(activity, front)

    if requires_gps and gps_missing_or_invalid:
        return True
    if pk_outside_front:
        return True
    return False


def _minimum_photos_required_for_activity(
    activity: Activity,
    db: Session,
    cache: dict[tuple[str, str], int],
) -> int:
    cache_key = (str(activity.catalog_version_id), activity.activity_type_code)
    if cache_key in cache:
        return cache[cache_key]

    activity_type = (
        db.query(CATActivityType)
        .filter(
            CATActivityType.version_id == activity.catalog_version_id,
            CATActivityType.code == activity.activity_type_code,
            CATActivityType.is_active.is_(True),
        )
        .first()
    )

    if activity_type is None:
        cache[cache_key] = 0
        return 0

    evidence_rule = (
        db.query(CATEvidenceRule)
        .filter(
            CATEvidenceRule.version_id == activity.catalog_version_id,
            CATEvidenceRule.entity_type == EntityType.ACTIVITY,
            CATEvidenceRule.type_id == activity_type.id,
        )
        .first()
    )

    min_photos = int(evidence_rule.min_photos) if evidence_rule and evidence_rule.min_photos else 0
    cache[cache_key] = min_photos
    return min_photos


def _pk_label(activity: Activity) -> str:
    if activity.pk_end and activity.pk_end > activity.pk_start:
        return f"PK {activity.pk_start}-{activity.pk_end}"
    return f"PK {activity.pk_start}"


def _validate_approval_checklist(activity: Activity, db: Session) -> list[str]:
    missing: list[str] = []

    activity_type = (
        db.query(CATActivityType)
        .filter(
            CATActivityType.version_id == activity.catalog_version_id,
            CATActivityType.code == activity.activity_type_code,
            CATActivityType.is_active.is_(True),
        )
        .first()
    )

    if activity_type is None:
        return missing

    evidence_rule = (
        db.query(CATEvidenceRule)
        .filter(
            CATEvidenceRule.version_id == activity.catalog_version_id,
            CATEvidenceRule.entity_type == EntityType.ACTIVITY,
            CATEvidenceRule.type_id == activity_type.id,
        )
        .first()
    )

    if evidence_rule is None:
        return missing

    evidence_count = db.query(Evidence).filter(Evidence.activity_id == activity.uuid).count()
    if evidence_count < evidence_rule.min_photos:
        missing.append(f"photo_min_{evidence_rule.min_photos}")

    if evidence_rule.requires_gps and (not activity.latitude or not activity.longitude):
        missing.append("gps_required")

    return missing



@router.get("/queue", response_model=ReviewQueueResponse)
def review_queue(
    project_id: str | None = Query(None),
    front_id: str | None = Query(None),
    status_filter: str | None = Query(None, alias="status"),
    only_conflicts: bool = Query(False),
    q: str | None = Query(None),
    from_dt: datetime | None = Query(None, alias="from"),
    to_dt: datetime | None = Query(None, alias="to"),
    _current_user: User = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO", "LECTOR"])),
    db: Session = Depends(get_db),
):
    query = db.query(Activity)
    if project_id:
        query = query.filter(Activity.project_id == project_id)
    if front_id:
        query = query.filter(Activity.front_id == front_id)
    if from_dt:
        query = query.filter(Activity.created_at >= from_dt)
    if to_dt:
        query = query.filter(Activity.created_at <= to_dt)

    activities = query.order_by(Activity.updated_at.desc()).limit(400).all()

    items: list[ReviewQueueItemOut] = []
    counters = {"pending": 0, "changed": 0, "gps_critical": 0, "rejected": 0}
    gps_requirement_cache: dict[tuple[str, str], bool] = {}
    min_photos_cache: dict[tuple[str, str], int] = {}

    for activity in activities:
        front = db.query(Front).filter(Front.id == activity.front_id).first() if activity.front_id else None
        front_name = front.name if front else None
        evidence_count = db.query(Evidence).filter(Evidence.activity_id == activity.uuid).count()
        latest_action = (
            db.query(AuditLog.action)
            .filter(AuditLog.entity == "activity", AuditLog.entity_id == str(activity.uuid))
            .order_by(AuditLog.created_at.desc())
            .scalar()
        )

        min_required_photos = _minimum_photos_required_for_activity(activity, db, min_photos_cache)
        missing_evidence = evidence_count < min_required_photos if min_required_photos > 0 else evidence_count == 0
        catalog_change_pending = bool(activity.description and "catalog" in activity.description.lower())
        gps_critical = _compute_gps_critical(activity, front, db, gps_requirement_cache)
        checklist_incomplete = missing_evidence or gps_critical
        has_conflicts = catalog_change_pending or checklist_incomplete
        severity = _severity_from_flags(gps_critical, has_conflicts, missing_evidence)
        status_value = _status_from_audit(latest_action, activity)

        item = ReviewQueueItemOut(
            id=activity.uuid,
            pk=_pk_label(activity),
            front=front_name,
            municipality=None,
            activity_type=activity.activity_type_code,
            risk="alto" if severity == "HIGH" else "medio" if severity == "MED" else "bajo",
            created_at=activity.created_at,
            updated_at=activity.updated_at,
            status=status_value,
            gps_critical=gps_critical,
            missing_evidence=missing_evidence,
            catalog_change_pending=catalog_change_pending,
            checklist_incomplete=checklist_incomplete,
            has_conflicts=has_conflicts,
            severity=severity,
            evidence_count=evidence_count,
            conflict_count=1 if has_conflicts else 0,
        )

        searchable = f"{item.pk} {item.front or ''} {item.activity_type} {activity.title or ''}".lower()
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

    return ReviewQueueResponse(
        items=items,
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
    _current_user: User = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO", "LECTOR"])),
    db: Session = Depends(get_db),
):
    try:
        activity_uuid = UUID(activity_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid activity id")

    activity = db.query(Activity).filter(Activity.uuid == activity_uuid).first()
    if not activity:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Activity not found")

    front = db.query(Front).filter(Front.id == activity.front_id).first() if activity.front_id else None
    front_name = front.name if front else None
    latest_action = (
        db.query(AuditLog.action)
        .filter(AuditLog.entity == "activity", AuditLog.entity_id == str(activity.uuid))
        .order_by(AuditLog.created_at.desc())
        .scalar()
    )
    current_status = _status_from_audit(latest_action, activity)

    gps_critical = _compute_gps_critical(activity, front, db, gps_requirement_cache={})

    quality_flags = {
        "evidence_ok": db.query(Evidence).filter(Evidence.activity_id == activity.uuid).count() > 0,
        "gps_ok": not gps_critical,
        "catalog_ok": not bool(activity.description and "catalog" in activity.description.lower()),
        "required_fields_ok": bool(activity.title and activity.description),
    }

    changeset: list[ReviewChangeFieldOut] = []
    if activity.description and "catalog" in activity.description.lower():
        changeset.append(
            ReviewChangeFieldOut(
                field_key="description",
                original="Descripción original",
                proposed=activity.description,
                conflict_type="catalog_change",
                suggested_options=["ACCEPT", "RESTORE", "CHOOSE_CATALOG"],
            )
        )

    history_rows = (
        db.query(AuditLog)
        .filter(AuditLog.entity == "activity", AuditLog.entity_id == str(activity.uuid))
        .order_by(AuditLog.created_at.desc())
        .limit(20)
        .all()
    )
    history = [
        {
            "at": row.created_at.isoformat(),
            "actor": row.actor_email,
            "action": row.action,
            "details": row.details_json,
        }
        for row in history_rows
    ]

    return ReviewActivityOut(
        id=activity.uuid,
        project_id=activity.project_id,
        front=front_name,
        municipality=None,
        activity_type=activity.activity_type_code,
        title=activity.title,
        description=activity.description,
        status=current_status,
        quality_flags=quality_flags,
        changeset=changeset,
        history=history,
    )


@router.get("/activity/{activity_id}/evidences", response_model=list[ReviewEvidenceOut])
def review_activity_evidences(
    activity_id: str,
    _current_user: User = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO", "LECTOR"])),
    db: Session = Depends(get_db),
):
    try:
        activity_uuid = UUID(activity_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid activity id")

    evidences = (
        db.query(Evidence)
        .filter(Evidence.activity_id == activity_uuid)
        .order_by(Evidence.created_at.asc())
        .all()
    )

    return [
        ReviewEvidenceOut(
            id=evidence.id,
            takenAt=evidence.created_at,
            lat=None,
            lng=None,
            accuracy=None,
            device=None,
            description=evidence.caption,
            gcsKey=evidence.object_path,
            status="UPLOADED" if evidence.object_path else "PENDING",
        )
        for evidence in evidences
    ]


@router.post("/evidence/{evidence_id}/validate", status_code=status.HTTP_200_OK)
def review_validate_evidence(
    evidence_id: str,
    body: ReviewEvidenceValidateIn,
    current_user: User = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR"])),
    db: Session = Depends(get_db),
):
    try:
        evidence_uuid = UUID(evidence_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid evidence id")

    evidence = db.query(Evidence).filter(Evidence.id == evidence_uuid).first()
    if not evidence:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Evidence not found")

    write_audit_log(
        db,
        action="REVIEW_EVIDENCE_VALIDATE",
        entity="evidence",
        entity_id=str(evidence.id),
        actor=current_user,
        details={"status": body.status, "reason_code": body.reason_code, "comment": body.comment},
    )
    db.commit()
    return {"ok": True}


@router.patch("/evidence/{evidence_id}", status_code=status.HTTP_200_OK)
def review_patch_evidence(
    evidence_id: str,
    body: ReviewEvidencePatchIn,
    current_user: User = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
    db: Session = Depends(get_db),
):
    try:
        evidence_uuid = UUID(evidence_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid evidence id")

    evidence = db.query(Evidence).filter(Evidence.id == evidence_uuid).first()
    if not evidence:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Evidence not found")

    evidence.caption = body.description
    write_audit_log(
        db,
        action="REVIEW_EVIDENCE_PATCH",
        entity="evidence",
        entity_id=str(evidence.id),
        actor=current_user,
        details={"description": body.description},
    )
    db.commit()
    return {"ok": True}


@router.post("/activity/{activity_id}/decision", response_model=ReviewDecisionOut)
def review_decision(
    activity_id: str,
    body: ReviewDecisionIn,
    current_user: User = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR"])),
    db: Session = Depends(get_db),
):
    try:
        activity_uuid = UUID(activity_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid activity id")

    activity = db.query(Activity).filter(Activity.uuid == activity_uuid).first()
    if not activity:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Activity not found")

    decision = body.decision.upper().strip()
    if decision not in {"APPROVE", "REJECT", "APPROVE_EXCEPTION"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid decision")

    if decision == "APPROVE_EXCEPTION" and not (body.comment and body.comment.strip()):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Exception approval requires comment")

    if decision == "APPROVE_EXCEPTION" and not user_has_any_role(current_user, ["ADMIN"], db):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="APPROVE_EXCEPTION requires ADMIN role")

    if decision == "REJECT":
        if not body.reject_reason_code:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="reject_reason_code is required when decision is REJECT",
            )
        reject_reason = (
            db.query(RejectReason)
            .filter(
                RejectReason.reason_code == body.reject_reason_code.strip().upper(),
                RejectReason.is_active.is_(True),
            )
            .first()
        )
        if not reject_reason:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=f"reject_reason_code '{body.reject_reason_code}' not found or inactive",
            )
        if reject_reason.requires_comment and not (body.comment and body.comment.strip()):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"reject_reason_code '{reject_reason.reason_code}' requires comment"
                ),
            )

    if decision == "APPROVE":
        missing_items = _validate_approval_checklist(activity, db)
        if missing_items:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail={
                    "error": "CHECKLIST_INCOMPLETE",
                    "activity_id": str(activity.uuid),
                    "activity_type": activity.activity_type_code,
                    "missing_items": missing_items,
                },
            )

    if decision in {"APPROVE", "APPROVE_EXCEPTION"}:
        activity.execution_state = ExecutionState.COMPLETADA.value
        action = "REVIEW_APPROVE_EXCEPTION" if decision == "APPROVE_EXCEPTION" else "REVIEW_APPROVE"
    else:
        activity.execution_state = ExecutionState.REVISION_PENDIENTE.value
        action = "REVIEW_REJECT"
    activity.increment_sync_version()

    write_audit_log(
        db,
        action=action,
        entity="activity",
        entity_id=str(activity.uuid),
        actor=current_user,
        details={
            "decision": decision,
            "reject_reason_code": body.reject_reason_code,
            "comment": body.comment,
            "field_resolutions": [resolution.model_dump() for resolution in body.field_resolutions],
            "apply_to_similar": body.apply_to_similar,
        },
    )
    db.commit()

    if decision == "REJECT" and body.comment:
        obs = Observation(
            project_id=activity.project_id,
            activity_id=activity.uuid,
            assignee_user_id=activity.assigned_to_user_id,
            tags_json=json.dumps(["review", "correction"]),
            message=body.comment,
            severity="HIGH",
            status="OPEN",
        )
        db.add(obs)
        db.flush()
        db.commit()

    return ReviewDecisionOut(ok=True, status="RECHAZADO" if decision == "REJECT" else "APROBADO")


@router.get("/reject-playbook", response_model=ReviewRejectPlaybookResponse)
def review_reject_playbook(
    project_id: str | None = Query(None),
    _current_user: User = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO", "LECTOR"])),
    db: Session = Depends(get_db),
):
    _ = project_id
    rows = (
        db.query(RejectReason)
        .filter(RejectReason.is_active.is_(True))
        .order_by(RejectReason.reason_code.asc())
        .all()
    )
    items = [
        ReviewRejectPlaybookItemOut(
            reason_code=row.reason_code,
            label=row.label,
            severity=row.severity,
            requires_comment=row.requires_comment,
        )
        for row in rows
    ]
    return ReviewRejectPlaybookResponse(items=items)


@router.post("/reject-reasons", response_model=ReviewRejectPlaybookItemOut)
def create_reject_reason(
    body: ReviewRejectReasonCreateIn,
    current_user: User = Depends(require_any_role(["ADMIN"])),
    db: Session = Depends(get_db),
):
    reason_code = body.reason_code.strip().upper()
    if not reason_code:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="reason_code is required")

    existing = db.query(RejectReason).filter(RejectReason.reason_code == reason_code).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Reason {reason_code} already exists")

    reason = RejectReason(
        reason_code=reason_code,
        label=body.label.strip(),
        severity=body.severity.strip().upper() if body.severity else "MED",
        requires_comment=body.requires_comment,
        is_active=True,
        created_by_id=current_user.id,
    )
    db.add(reason)
    db.commit()
    db.refresh(reason)

    return ReviewRejectPlaybookItemOut(
        reason_code=reason.reason_code,
        label=reason.label,
        severity=reason.severity,
        requires_comment=reason.requires_comment,
    )
