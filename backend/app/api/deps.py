"""Authentication and authorization dependencies for API endpoints."""

import logging
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import verify_token
from app.models.permission import Permission
from app.models.role import Role, role_permissions
from app.models.user import User, UserStatus
from app.models.user_role_scope import UserRoleScope

logger = logging.getLogger(__name__)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
) -> User:
    """Dependency para obtener usuario actual desde JWT"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = verify_token(token, expected_type="access")
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except ValueError:
        raise credentials_exception

    try:
        user = db.query(User).filter(User.id == UUID(user_id)).first()
    except Exception:
        logger.exception(
            "DB error resolving user_id=%s — possible schema inconsistency "
            "(enum case mismatch / pending migrations). "
            "Run: python scripts/fix_prod_migrations.py --mode upgrade",
            user_id,
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error — check server logs",
        )

    if user is None:
        raise credentials_exception

    if user.status != UserStatus.ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive or locked"
        )

    return user


def verify_project_access(user: User, project_id: str, db: Session) -> None:
    """
    Verify that user has access to the specified project.
    
    Raises HTTPException if user does not have access.
    Access is granted if:
    - User has a UserRoleScope with project_id=NULL (access to all projects), OR
    - User has a UserRoleScope with project_id matching the requested project
    """
    # Check if user has any role scope for this project or for all projects (NULL)
    has_access = db.query(UserRoleScope).filter(
        UserRoleScope.user_id == user.id,
        (UserRoleScope.project_id == project_id) | (UserRoleScope.project_id.is_(None)),
    ).first() is not None
    
    if not has_access:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"User does not have access to project {project_id}"
        )


def user_has_permission(user: User, permission_code: str, db: Session) -> bool:
    """Return True if user has the requested permission through any assigned role."""
    permission = (
        db.query(Permission.id)
        .join(role_permissions, Permission.id == role_permissions.c.permission_id)
        .join(Role, Role.id == role_permissions.c.role_id)
        .join(UserRoleScope, UserRoleScope.role_id == Role.id)
        .filter(
            UserRoleScope.user_id == user.id,
            Permission.code == permission_code,
        )
        .first()
    )
    return permission is not None


def require_permission(permission_code: str):
    """FastAPI dependency factory to enforce RBAC permissions."""

    def _permission_dependency(
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
    ) -> User:
        if not user_has_permission(current_user, permission_code, db):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Missing permission: {permission_code}",
            )
        return current_user

    return _permission_dependency


def user_has_any_role(user: User, role_names: list[str], db: Session) -> bool:
    normalized = [name.strip().upper() for name in role_names if name and name.strip()]
    if not normalized:
        return False

    role_row = (
        db.query(Role.id)
        .join(UserRoleScope, UserRoleScope.role_id == Role.id)
        .filter(
            UserRoleScope.user_id == user.id,
            Role.name.in_(normalized),
        )
        .first()
    )
    return role_row is not None


def require_any_role(role_names: list[str]):
    """FastAPI dependency factory to enforce one-of role checks."""

    def _role_dependency(
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
    ) -> User:
        if not user_has_any_role(current_user, role_names, db):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Missing required role. Expected one of: {', '.join(role_names)}",
            )
        return current_user

    return _role_dependency
