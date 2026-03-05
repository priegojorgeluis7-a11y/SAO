import json
from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import require_any_role
from app.core.database import get_db
from app.models.observation import Observation
from app.models.user import User
from app.schemas.observation import ObservationCreateIn, ObservationOut, ObservationResolveOut
from app.services.audit_service import write_audit_log

router = APIRouter(tags=["observations"])


@router.post("/observations", response_model=ObservationOut, status_code=status.HTTP_201_CREATED)
def create_observation(
    body: ObservationCreateIn,
    current_user: User = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
    db: Session = Depends(get_db),
):
    obs = Observation(
        project_id=body.project_id,
        activity_id=body.activity_id,
        assignee_user_id=body.assignee_user_id,
        tags_json=json.dumps(body.tags),
        message=body.message,
        severity=body.severity,
        due_date=body.due_date,
        status="OPEN",
    )
    db.add(obs)
    db.flush()
    write_audit_log(
        db,
        action="OBSERVATION_CREATED",
        entity="observation",
        entity_id=str(obs.id),
        actor=current_user,
        details={"project_id": body.project_id, "activity_id": str(body.activity_id), "severity": body.severity},
    )
    db.commit()
    db.refresh(obs)

    return ObservationOut(
        id=obs.id,
        project_id=obs.project_id,
        activity_id=obs.activity_id,
        assignee_user_id=obs.assignee_user_id,
        tags=body.tags,
        message=obs.message,
        severity=obs.severity,
        due_date=obs.due_date,
        status=obs.status,
        resolved_at=obs.resolved_at,
        created_at=obs.created_at,
    )


@router.get("/mobile/observations", response_model=list[ObservationOut])
def list_mobile_observations(
    project_id: str | None = Query(None),
    status_filter: str = Query("open", alias="status"),
    current_user: User = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO", "LECTOR"])),
    db: Session = Depends(get_db),
):
    query = db.query(Observation)
    if project_id:
        query = query.filter(Observation.project_id == project_id)

    normalized = status_filter.strip().upper()
    if normalized == "OPEN":
        query = query.filter(Observation.status == "OPEN")
    elif normalized == "RESOLVED":
        query = query.filter(Observation.status == "RESOLVED")

    if current_user:
        query = query.filter((Observation.assignee_user_id == current_user.id) | (Observation.assignee_user_id.is_(None)))

    rows = query.order_by(Observation.created_at.desc()).limit(200).all()
    output: list[ObservationOut] = []
    for row in rows:
        tags = []
        if row.tags_json:
            try:
                parsed = json.loads(row.tags_json)
                if isinstance(parsed, list):
                    tags = [str(item) for item in parsed]
            except Exception:
                tags = []

        output.append(
            ObservationOut(
                id=row.id,
                project_id=row.project_id,
                activity_id=row.activity_id,
                assignee_user_id=row.assignee_user_id,
                tags=tags,
                message=row.message,
                severity=row.severity,
                due_date=row.due_date,
                status=row.status,
                resolved_at=row.resolved_at,
                created_at=row.created_at,
            )
        )

    return output


@router.post("/mobile/observations/{observation_id}/resolve", response_model=ObservationResolveOut)
def resolve_mobile_observation(
    observation_id: str,
    current_user: User = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
    db: Session = Depends(get_db),
):
    try:
        obs_uuid = UUID(observation_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid observation id")

    row = db.query(Observation).filter(Observation.id == obs_uuid).first()
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Observation not found")

    row.status = "RESOLVED"
    row.resolved_at = datetime.now(timezone.utc)
    row.increment_sync_version()
    write_audit_log(
        db,
        action="OBSERVATION_RESOLVED",
        entity="observation",
        entity_id=str(row.id),
        actor=current_user,
        details={"status": "RESOLVED"},
    )
    db.commit()
    return ObservationResolveOut(ok=True)
