from datetime import datetime, timedelta
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_any_role
from app.core.database import get_db
from app.models.activity import Activity
from app.models.catalog import CatalogStatus, CatalogVersion
from app.models.front import Front
from app.models.project import Project
from app.models.role import Role
from app.models.user import User, UserStatus
from app.models.user_role_scope import UserRoleScope
from app.schemas.assignment import AssignmentAssigneeOption, AssignmentCreate, AssignmentListItem

router = APIRouter(prefix="/assignments", tags=["assignments"])


@router.get("", response_model=list[AssignmentListItem])
def list_assignments(
    project_id: str = Query(..., description="Project filter"),
    from_dt: datetime = Query(..., alias="from", description="Range start (ISO-8601)"),
    to_dt: datetime = Query(..., alias="to", description="Range end (ISO-8601)"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    range_start = from_dt
    range_end = to_dt
    if range_end <= range_start:
        range_end = range_start + timedelta(days=1)

    rows = (
        db.query(Activity)
        .filter(Activity.project_id == project_id)
        .filter(Activity.assigned_to_user_id.isnot(None))
        .filter(Activity.created_at < range_end)
        .filter(Activity.updated_at >= range_start)
        .order_by(Activity.created_at.asc())
        .all()
    )

    items: list[AssignmentListItem] = []
    for row in rows:
        start_at = row.created_at
        end_at = row.updated_at if row.updated_at and row.updated_at > row.created_at else row.created_at

        items.append(
            AssignmentListItem(
                id=str(row.uuid),
                project_id=row.project_id,
                assignee_user_id=row.assigned_to_user_id,
                activity_id=row.activity_type_code,
                title=row.title or row.activity_type_code,
                frente="",
                municipio="",
                estado="",
                pk=row.pk_start,
                start_at=start_at,
                end_at=end_at,
                risk="bajo",
                status=("PROGRAMADA" if row.execution_state == "PENDIENTE" else row.execution_state),
            )
        )

    return items


@router.get("/assignees", response_model=list[AssignmentAssigneeOption])
def list_assignees(
    project_id: str = Query(..., description="Project filter"),
    _current_user: User = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR"])) ,
    db: Session = Depends(get_db),
):
    rows = (
        db.query(User, Role)
        .join(UserRoleScope, UserRoleScope.user_id == User.id)
        .join(Role, Role.id == UserRoleScope.role_id)
        .filter(User.status == UserStatus.ACTIVE)
        .filter((UserRoleScope.project_id == project_id) | (UserRoleScope.project_id.is_(None)))
        .filter(Role.name.in_(["OPERATIVO", "SUPERVISOR", "COORD", "ADMIN"]))
        .all()
    )

    options: list[AssignmentAssigneeOption] = []
    seen: set[str] = set()
    for user, role in rows:
        user_key = str(user.id)
        if user_key in seen:
            continue
        seen.add(user_key)
        options.append(
            AssignmentAssigneeOption(
                user_id=user.id,
                full_name=user.full_name,
                email=user.email,
                role_name=role.name,
            )
        )

    options.sort(key=lambda item: (item.full_name.lower(), item.email.lower()))
    return options


@router.post("", response_model=AssignmentListItem, status_code=status.HTTP_201_CREATED)
def create_assignment(
    payload: AssignmentCreate,
    current_user: User = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR"])),
    db: Session = Depends(get_db),
):
    project_id = payload.project_id.strip().upper()
    if payload.end_at <= payload.start_at:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="end_at must be greater than start_at")

    project = db.query(Project).filter(Project.id == project_id).first()
    if project is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")

    assignee = db.query(User).filter(User.id == payload.assignee_user_id).first()
    if assignee is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignee not found")

    if payload.front_id is not None:
        front = db.query(Front).filter(Front.id == payload.front_id, Front.project_id == project_id).first()
        if front is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Front not found for project")

    catalog_version = (
        db.query(CatalogVersion)
        .filter(CatalogVersion.project_id == project_id, CatalogVersion.status == CatalogStatus.PUBLISHED)
        .order_by(CatalogVersion.published_at.desc(), CatalogVersion.created_at.desc())
        .first()
    )
    if catalog_version is None:
        catalog_version = (
            db.query(CatalogVersion)
            .filter(CatalogVersion.project_id == project_id)
            .order_by(CatalogVersion.created_at.desc())
            .first()
        )
    if catalog_version is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Project has no catalog version")

    activity = Activity(
        uuid=uuid4(),
        project_id=project_id,
        front_id=payload.front_id,
        pk_start=payload.pk,
        pk_end=None,
        execution_state="PENDIENTE",
        assigned_to_user_id=payload.assignee_user_id,
        created_by_user_id=current_user.id,
        catalog_version_id=catalog_version.id,
        activity_type_code=payload.activity_type_code.strip().upper(),
        title=(payload.title.strip() if payload.title and payload.title.strip() else payload.activity_type_code.strip().upper()),
        description=f"planned:{payload.risk.strip().lower()}",
        created_at=payload.start_at,
        updated_at=payload.end_at,
    )
    db.add(activity)
    db.commit()
    db.refresh(activity)

    return AssignmentListItem(
        id=str(activity.uuid),
        project_id=activity.project_id,
        assignee_user_id=activity.assigned_to_user_id,
        activity_id=activity.activity_type_code,
        title=activity.title or activity.activity_type_code,
        frente="",
        municipio="",
        estado="",
        pk=activity.pk_start,
        start_at=activity.created_at,
        end_at=activity.updated_at,
        risk=payload.risk,
        status="PROGRAMADA",
    )
