"""Authentication and authorization dependencies for API endpoints."""

import logging
from typing import Any

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordBearer

from app.core.config import settings
from app.core.enums import UserStatus
from app.core.security import verify_token
from app.services.firestore_identity_service import get_firestore_user_by_id
from app.services.role_permission_service import get_role_permission_map

logger = logging.getLogger(__name__)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


def get_db_optional():
    """Firestore-only runtime: always yield None (no SQL session)."""
    yield None

_PERMISSION_ALIASES: dict[str, set[str]] = {
    "activity.view": {"activity.view", "ver actividades"},
    "activity.create": {"activity.create", "crear actividades"},
    "activity.edit": {"activity.edit", "editar actividades"},
    "activity.delete": {"activity.delete", "eliminar actividades"},
    "activity.approve": {"activity.approve", "aprobar actividades"},
    "activity.reject": {"activity.reject", "rechazar actividades"},
    "event.view": {"event.view", "ver eventos"},
    "event.create": {"event.create", "crear eventos"},
    "event.edit": {"event.edit", "editar eventos"},
    "catalog.view": {"catalog.view", "ver catálogo", "ver catalogo"},
    "catalog.edit": {"catalog.edit", "editar catálogo", "editar catalogo"},
    "catalog.publish": {"catalog.publish", "publicar catálogo", "publicar catalogo"},
    "user.view": {"user.view", "ver usuarios"},
    "user.create": {"user.create", "crear usuarios"},
    "user.edit": {"user.edit", "editar usuarios"},
    "report.view": {"report.view", "ver reportes"},
    "report.export": {"report.export", "exportar reportes"},
    "assignment.manage": {"assignment.manage", "administrar asignaciones"},
    "project.manage": {"project.manage", "administrar proyectos"},
    "flow.approve_exception": {
        "flow.approve_exception",
        "aprobar excepciones de flujo",
    },
}


def _normalize_permission_code(value: str | None) -> str:
    return str(value or "").strip().lower()


def _permission_matches(candidate: str | None, requested: str) -> bool:
    candidate_norm = _normalize_permission_code(candidate)
    requested_norm = _normalize_permission_code(requested)
    if not candidate_norm or not requested_norm:
        return False

    aliases = _PERMISSION_ALIASES.get(requested_norm)
    if aliases:
        return candidate_norm in aliases

    reverse_aliases = _PERMISSION_ALIASES.get(candidate_norm)
    if reverse_aliases:
        return requested_norm in reverse_aliases

    return candidate_norm == requested_norm


async def get_current_user(
    request: Request,
    token: str = Depends(oauth2_scheme),
    db: Any | None = Depends(get_db_optional),
) -> Any:
    """Dependency para obtener usuario actual desde JWT."""
    _ = db  # Firestore-only runtime keeps signature parity with existing dependencies.

    if settings.DATA_BACKEND != "firestore":
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Only firestore backend mode is supported",
        )

    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = verify_token(token, expected_type="access")
        user_id = str(payload.get("sub") or "").strip()
        if not user_id:
            raise credentials_exception
    except ValueError:
        raise credentials_exception

    user = get_firestore_user_by_id(user_id)
    if user is None:
        raise credentials_exception

    if user.status != UserStatus.ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive or locked",
        )

    token_iat = payload.get("iat")
    if token_iat and user.last_logout_at:
        from datetime import datetime, timezone as _tz

        token_issued_at = datetime.fromtimestamp(token_iat, tz=_tz.utc)
        if token_issued_at < user.last_logout_at:
            raise credentials_exception

    request.state.user_id = str(getattr(user, "id", ""))
    return user


def _normalize_project_id(project_id: str | None) -> str | None:
    if project_id is None:
        return None
    normalized = project_id.strip().upper()
    return normalized or None


def resolve_user_project_access(user: Any) -> tuple[bool, set[str]]:
    """Return whether the user has global access and the explicit project ids they can access."""
    role_names = {
        str(role).strip().upper()
        for role in (getattr(user, "roles", []) or [])
        if str(role).strip()
    }
    explicit_project_ids = {
        normalized
        for normalized in (
            _normalize_project_id(str(project_id or ""))
            for project_id in (getattr(user, "project_ids", []) or [])
        )
        if normalized
    }

    has_global_scope = "*" in explicit_project_ids or "ADMIN" in role_names
    if not has_global_scope and not explicit_project_ids and "SUPERVISOR" in role_names:
        has_global_scope = True

    allowed_project_ids = {
        project_id
        for project_id in explicit_project_ids
        if project_id != "*"
    }
    denied_project_ids: set[str] = set()

    for scope in (getattr(user, "permission_scopes", []) or []):
        if not isinstance(scope, dict):
            continue
        scope_project_id = _normalize_project_id(scope.get("project_id"))
        if scope_project_id is None:
            continue
        if scope_project_id == "*":
            if str(scope.get("effect") or "allow").strip().lower() != "deny":
                has_global_scope = True
            continue
        if str(scope.get("effect") or "allow").strip().lower() == "deny":
            denied_project_ids.add(scope_project_id)
        else:
            allowed_project_ids.add(scope_project_id)

    allowed_project_ids.difference_update(denied_project_ids)
    return has_global_scope, allowed_project_ids


def verify_project_access(user: Any, project_id: str, db: Any) -> None:
    """Verify that the user can access the requested project id."""
    _ = db

    if settings.DATA_BACKEND != "firestore":
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Only firestore backend mode is supported",
        )

    normalized_project_id = _normalize_project_id(project_id)
    if normalized_project_id is None:
        return

    has_global_scope, allowed_project_ids = resolve_user_project_access(user)
    if has_global_scope or normalized_project_id in allowed_project_ids:
        return

    logger.warning(
        "PROJECT_ACCESS_DENIED user_id=%s project_id=%s",
        getattr(user, "id", "?"),
        normalized_project_id,
    )
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail=f"User does not have access to project {normalized_project_id}",
    )


    if project_id is None:
        return None
    normalized = project_id.strip().upper()
    return normalized or None


def user_has_permission(
    user: Any,
    permission_code: str,
    db: Any | None,
    project_id: str | None = None,
) -> bool:
    """Return True if user has the requested permission with deny-overrides semantics."""
    _ = db

    if settings.DATA_BACKEND != "firestore":
        return False

    normalized_project_id = _normalize_project_id(project_id)
    direct_scopes = getattr(user, "permission_scopes", []) or []

    def _scope_applies(scope_project_id: str | None) -> bool:
        if normalized_project_id is None:
            return scope_project_id is None
        return scope_project_id is None or scope_project_id == normalized_project_id

    for scope in direct_scopes:
        scope_code = str(scope.get("permission_code") or "").strip()
        scope_effect = str(scope.get("effect") or "allow").strip().lower()
        scope_project_id = _normalize_project_id(scope.get("project_id"))
        if _permission_matches(scope_code, permission_code) and scope_effect == "deny" and _scope_applies(scope_project_id):
            return False

    role_permissions_map = get_role_permission_map()
    role_codes: set[str] = set()
    for role_name in getattr(user, "roles", []) or []:
        role_codes.update(
            role_permissions_map.get(str(role_name).strip().upper(), [])
        )
    if any(_permission_matches(code, permission_code) for code in role_codes):
        return True

    for scope in direct_scopes:
        scope_code = str(scope.get("permission_code") or "").strip()
        scope_effect = str(scope.get("effect") or "allow").strip().lower()
        scope_project_id = _normalize_project_id(scope.get("project_id"))
        if _permission_matches(scope_code, permission_code) and scope_effect == "allow" and _scope_applies(scope_project_id):
            return True
    return False


def require_permission(permission_code: str):
    """FastAPI dependency factory to enforce RBAC permissions."""

    def _permission_dependency(
        current_user: Any = Depends(get_current_user),
        db: Any | None = Depends(get_db_optional),
    ) -> Any:
        if settings.DATA_BACKEND != "firestore":
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Only firestore backend mode is supported",
            )
        if not user_has_permission(current_user, permission_code, db):
            logger.warning(
                "PERMISSION_DENIED user_id=%s permission=%s",
                getattr(current_user, "id", "?"),
                permission_code,
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Missing permission: {permission_code}",
            )
        return current_user

    return _permission_dependency


def require_project_permission(permission_code: str, project_param: str = "project_id"):
    """Dependency factory that enforces permission within a project scope."""

    async def _permission_dependency(
        request: Request,
        current_user: Any = Depends(get_current_user),
        db: Any | None = Depends(get_db_optional),
    ) -> Any:
        if settings.DATA_BACKEND != "firestore":
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Only firestore backend mode is supported",
            )

        project_id = request.path_params.get(project_param) or request.query_params.get(project_param)
        if project_id is None:
            try:
                body = await request.json()
            except Exception:
                body = None
            if isinstance(body, dict):
                project_id = body.get(project_param)

        normalized_project_id = _normalize_project_id(project_id)
        if normalized_project_id is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Missing required project parameter: {project_param}",
            )

        if not user_has_permission(
            current_user,
            permission_code,
            db,
            project_id=normalized_project_id,
        ):
            logger.warning(
                "PERMISSION_DENIED user_id=%s permission=%s project_id=%s",
                getattr(current_user, "id", "?"),
                permission_code,
                normalized_project_id,
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    f"Missing permission: {permission_code} "
                    f"for project: {normalized_project_id}"
                ),
            )

        request.state.project_id = normalized_project_id
        return current_user

    return _permission_dependency


def user_has_any_role(user: Any, role_names: list[str], db: Any | None) -> bool:
    """Return True if user has at least one role from role_names."""
    _ = db

    normalized = [name.strip().upper() for name in role_names if name and name.strip()]
    if not normalized or settings.DATA_BACKEND != "firestore":
        return False

    user_roles = [r.upper() for r in (getattr(user, "roles", []) or [])]
    return any(role in normalized for role in user_roles)


def require_any_role(role_names: list[str]):
    """FastAPI dependency factory to enforce one-of role checks."""

    def _role_dependency(
        current_user: Any = Depends(get_current_user),
        db: Any | None = Depends(get_db_optional),
    ) -> Any:
        if not user_has_any_role(current_user, role_names, db):
            logger.warning(
                "ROLE_DENIED user_id=%s required=%s",
                getattr(current_user, "id", "?"),
                role_names,
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Missing required role. Expected one of: {', '.join(role_names)}",
            )
        return current_user

    return _role_dependency
