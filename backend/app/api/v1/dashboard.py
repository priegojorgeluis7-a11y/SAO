from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import and_
from sqlalchemy.orm import Session

from app.api.deps import require_any_role
from app.core.database import get_db
from app.models.activity import Activity, ExecutionState
from app.models.front import Front
from app.models.user import User

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@router.get("/kpis")
def get_dashboard_kpis(
    project_id: str | None = Query(None),
    _current_user: User = Depends(require_any_role(["ADMIN", "SUPERVISOR", "COORD"])),
    db: Session = Depends(get_db),
):
    now = datetime.now(timezone.utc)
    day_start = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)
    day_end = day_start + timedelta(days=1)

    base = db.query(Activity)
    if project_id:
        base = base.filter(Activity.project_id == project_id.strip().upper())

    total = base.count()
    pending_review = base.filter(Activity.execution_state == ExecutionState.REVISION_PENDIENTE.value).count()
    in_progress = base.filter(Activity.execution_state == ExecutionState.EN_CURSO.value).count()
    completed = base.filter(Activity.execution_state == ExecutionState.COMPLETADA.value).count()
    completed_today = base.filter(
        and_(
            Activity.execution_state == ExecutionState.COMPLETADA.value,
            Activity.updated_at >= day_start,
            Activity.updated_at < day_end,
        )
    ).count()

    recent_rows = (
        db.query(Activity, Front)
        .outerjoin(Front, Activity.front_id == Front.id)
        .filter(Activity.project_id == project_id.strip().upper())
        .order_by(Activity.updated_at.desc())
        .limit(5)
        .all()
        if project_id
        else (
            db.query(Activity, Front)
            .outerjoin(Front, Activity.front_id == Front.id)
            .order_by(Activity.updated_at.desc())
            .limit(5)
            .all()
        )
    )

    recent_items: list[dict] = []
    for activity, front_row in recent_rows:
        recent_items.append(
            {
                "id": str(activity.uuid),
                "activity_type": activity.activity_type_code,
                "pk": activity.pk_start,
                "front": (front_row.name if front_row else ""),
                "status": activity.execution_state,
                "created_at": activity.created_at.isoformat() if activity.created_at else "",
                "project_id": activity.project_id,
            }
        )

    return {
        "project_id": (project_id.strip().upper() if project_id else "ALL"),
        "generated_at": now.isoformat(),
        "kpis": {
            "total": total,
            "pending_review": pending_review,
            "in_progress": in_progress,
            "completed": completed,
            "completed_today": completed_today,
        },
        "recent_items": recent_items,
    }
