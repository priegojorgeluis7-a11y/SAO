from collections import OrderedDict
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_any_role
from app.core.database import get_db
from app.core.security import get_password_hash
from app.models.role import Role
from app.models.user import User, UserStatus
from app.models.user_role_scope import UserRoleScope
from app.schemas.user import (
    AdminUserCreate,
    AdminUserCreateResponse,
    AdminUserListItem,
    AdminUserUpdate,
    UserAgendaListItem,
)
from app.services.audit_service import write_audit_log

router = APIRouter(prefix="/users", tags=["users"])


@router.get("", response_model=list[UserAgendaListItem])
def list_users(
    role: Optional[str] = Query(None, description="Role filter, e.g. OPERATIVO"),
    project_id: Optional[str] = Query(None, description="Project scope filter"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = (
        db.query(User, Role.name.label("role_name"), UserRoleScope.project_id.label("scope_project_id"))
        .join(UserRoleScope, UserRoleScope.user_id == User.id)
        .join(Role, Role.id == UserRoleScope.role_id)
        .filter(User.status == UserStatus.ACTIVE)
    )

    if role and role.strip():
        query = query.filter(Role.name == role.strip().upper())

    if project_id and project_id.strip():
        query = query.filter(
            or_(
                UserRoleScope.project_id == project_id.strip(),
                UserRoleScope.project_id.is_(None),
            )
        )

    rows = query.order_by(User.full_name.asc()).all()

    deduped = OrderedDict()
    for user, role_name, scope_project_id in rows:
        key = str(user.id)
        if key in deduped:
            continue
        deduped[key] = UserAgendaListItem(
            id=user.id,
            full_name=user.full_name,
            email=user.email,
            role_name=role_name,
            project_id=scope_project_id,
            is_active=user.status == UserStatus.ACTIVE,
        )

    return list(deduped.values())


@router.get("/admin", response_model=list[AdminUserListItem])
def list_admin_users(
    role: Optional[str] = Query(None),
    _current_user: User = Depends(require_any_role(["ADMIN", "SUPERVISOR"])),
    db: Session = Depends(get_db),
):
    query = (
        db.query(User, Role.name.label("role_name"), UserRoleScope.project_id.label("scope_project_id"))
        .join(UserRoleScope, UserRoleScope.user_id == User.id)
        .join(Role, Role.id == UserRoleScope.role_id)
    )

    if role and role.strip():
        query = query.filter(Role.name == role.strip().upper())

    rows = query.order_by(User.full_name.asc()).all()
    return [
        AdminUserListItem(
            id=user.id,
            email=user.email,
            full_name=user.full_name,
            status=user.status,
            role_name=role_name,
            project_id=scope_project_id,
        )
        for user, role_name, scope_project_id in rows
    ]


@router.post("/admin", response_model=AdminUserCreateResponse, status_code=status.HTTP_201_CREATED)
def create_admin_user(
    payload: AdminUserCreate,
    current_user: User = Depends(require_any_role(["ADMIN"])),
    db: Session = Depends(get_db),
):
    existing = db.query(User).filter(User.email == payload.email).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    role = db.query(Role).filter(Role.name == payload.role.strip().upper()).first()
    if role is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Role not configured")

    user = User(
        email=payload.email,
        full_name=payload.full_name.strip(),
        password_hash=get_password_hash(payload.password),
        status=UserStatus.ACTIVE,
    )
    db.add(user)
    db.flush()

    scope = UserRoleScope(
        user_id=user.id,
        role_id=role.id,
        project_id=payload.project_id.strip().upper() if payload.project_id else None,
        front_id=None,
        location_id=None,
        assigned_by_id=current_user.id,
    )
    db.add(scope)
    write_audit_log(
        db,
        action="USER_CREATED",
        entity="user",
        entity_id=str(user.id),
        actor=current_user,
        details={
            "email": user.email,
            "role": role.name,
            "project_id": scope.project_id,
        },
    )
    db.commit()
    return AdminUserCreateResponse(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        status=user.status,
        role_name=role.name,
        project_id=scope.project_id,
    )


@router.patch("/admin/{user_id}", response_model=AdminUserCreateResponse)
def update_admin_user(
    user_id: str,
    payload: AdminUserUpdate,
    current_user: User = Depends(require_any_role(["ADMIN"])),
    db: Session = Depends(get_db),
):
    try:
        user_uuid = UUID(user_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid user id")

    user = db.query(User).filter(User.id == user_uuid).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    scope = (
        db.query(UserRoleScope)
        .filter(UserRoleScope.user_id == user.id)
        .order_by(UserRoleScope.created_at.asc())
        .first()
    )
    if not scope:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="User has no assigned role")

    if payload.full_name is not None:
        user.full_name = payload.full_name.strip()
    if payload.status is not None:
        user.status = payload.status

    if payload.role is not None:
        role = db.query(Role).filter(Role.name == payload.role.strip().upper()).first()
        if role is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Role not configured")
        scope.role_id = role.id

    if payload.project_id is not None:
        scope.project_id = payload.project_id.strip().upper() if payload.project_id.strip() else None

    role_name = db.query(Role.name).filter(Role.id == scope.role_id).scalar()
    write_audit_log(
        db,
        action="USER_UPDATED",
        entity="user",
        entity_id=str(user.id),
        actor=current_user,
        details={
            "email": user.email,
            "status": user.status.value,
            "role": role_name,
            "project_id": scope.project_id,
        },
    )
    db.commit()
    return AdminUserCreateResponse(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        status=user.status,
        role_name=role_name,
        project_id=scope.project_id,
    )
