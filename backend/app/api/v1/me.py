"""Current-user scoped endpoints."""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.project import Project
from app.models.role import Role
from app.models.user import User
from app.models.user_role_scope import UserRoleScope
from app.schemas.user import MyProjectItem

router = APIRouter(prefix="/me", tags=["me"])


@router.get("/projects", response_model=list[MyProjectItem])
async def list_my_projects(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return projects the user can access, including assigned role names."""
    scopes = (
        db.query(UserRoleScope, Role)
        .join(Role, Role.id == UserRoleScope.role_id)
        .filter(UserRoleScope.user_id == current_user.id)
        .all()
    )

    if not scopes:
        return []

    has_global_scope = any(scope.project_id is None for scope, _role in scopes)
    role_names = sorted({role.name for _scope, role in scopes})

    if has_global_scope:
        projects = db.query(Project).order_by(Project.id.asc()).all()
        return [
            MyProjectItem(
                project_id=project.id,
                project_name=project.name,
                role_names=role_names,
            )
            for project in projects
        ]

    per_project_roles: dict[str, set[str]] = {}
    for scope, role in scopes:
        if scope.project_id is None:
            continue
        if scope.project_id not in per_project_roles:
            per_project_roles[scope.project_id] = set()
        per_project_roles[scope.project_id].add(role.name)

    if not per_project_roles:
        return []

    project_rows = (
        db.query(Project)
        .filter(Project.id.in_(list(per_project_roles.keys())))
        .order_by(Project.id.asc())
        .all()
    )

    return [
        MyProjectItem(
            project_id=project.id,
            project_name=project.name,
            role_names=sorted(per_project_roles.get(project.id, set())),
        )
        for project in project_rows
    ]
