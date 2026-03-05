from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import require_any_role
from app.core.database import get_db
from app.models.activity import Activity
from app.models.front import Front
from app.models.user import User

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/activities")
def list_report_activities(
    project_id: str | None = Query(None),
    front: str | None = Query(None),
    date_from: datetime | None = Query(None),
    date_to: datetime | None = Query(None),
    status: str | None = Query(None),
    _current_user: User = Depends(require_any_role(["ADMIN", "SUPERVISOR", "COORD"])),
    db: Session = Depends(get_db),
):
    query = db.query(Activity, Front).outerjoin(Front, Activity.front_id == Front.id)

    if project_id:
        query = query.filter(Activity.project_id == project_id.strip().upper())
    if front:
        query = query.filter(Front.name.ilike(f"%{front.strip()}%"))
    if date_from:
        query = query.filter(Activity.created_at >= date_from)
    if date_to:
        query = query.filter(Activity.created_at <= date_to)
    if status:
        query = query.filter(Activity.execution_state == status.strip().upper())

    rows = query.order_by(Activity.created_at.desc()).limit(1000).all()

    items: list[dict] = []
    for activity, front_row in rows:
        items.append(
            {
                "id": str(activity.uuid),
                "project_id": activity.project_id,
                "activity_type": activity.activity_type_code,
                "pk": activity.pk_start,
                "front": (front_row.name if front_row else ""),
                "status": activity.execution_state,
                "created_at": activity.created_at.isoformat() if activity.created_at else "",
                "assigned_name": "",
            }
        )

    return {
        "meta": {
                "generated_at": datetime.now(timezone.utc).isoformat(),
            "generated_by": str(_current_user.id),
            "filters": {
                "project_id": project_id,
                "front": front,
                "date_from": date_from.isoformat() if date_from else None,
                "date_to": date_to.isoformat() if date_to else None,
                "status": status,
            },
        },
        "items": items,
    }
