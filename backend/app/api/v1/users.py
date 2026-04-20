from typing import Any, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Query, status
from app.core.api_errors import api_error

from app.api.deps import get_current_user, require_any_role, user_has_any_role
from app.core.permission_catalog import CANONICAL_PERMISSION_CODES
from app.core.security import get_password_hash
from app.core.enums import UserStatus
from app.schemas.user import (
    AdminRolePermissionsUpdate,
    AdminUserCreate,
    AdminUserCreateResponse,
    AdminUserListItem,
    AdminUserPasswordResetRequest,
    AdminUserPermissionInput,
    AdminUserPermissionItem,
    AdminUserScopeInput,
    AdminUserScopeItem,
    AdminUserUpdate,
    UserAgendaListItem,
)
from app.services.audit_service import canonicalize_role_name, write_firestore_audit_log
from app.services.firestore_identity_service import (
    list_firestore_users,
    create_firestore_user,
    get_firestore_user_by_id,
    get_firestore_user_by_email,
    delete_firestore_user,
    reset_firestore_user_password,
    update_firestore_user,
)
from app.services.role_permission_service import (
    get_role_permission_map,
    merge_role_permission_codes,
    save_role_permission_map,
)

router = APIRouter(prefix="/users", tags=["users"])

_PROTECTED_ADMIN_EMAIL = "admin@sao.mx"


def _normalized_email(value: Any) -> str:
    return str(value or "").strip().lower()


def _is_protected_admin_user(user: Any) -> bool:
    return _normalized_email(getattr(user, "email", None)) == _PROTECTED_ADMIN_EMAIL


def _is_root_admin_actor(user: Any) -> bool:
    return _normalized_email(getattr(user, "email", None)) == _PROTECTED_ADMIN_EMAIL


def _unique_keep_order(values: list[str]) -> list[str]:
    return list(dict.fromkeys([v for v in values if v]))


def _normalize_scope_payload(payload: AdminUserCreate | AdminUserUpdate) -> list[AdminUserScopeInput] | None:
    if payload.scopes is not None:
        return payload.scopes

    if payload.role is None and payload.project_id is None:
        return None

    role_name = (payload.role or "").strip().upper()
    if not role_name:
        return []

    project_id = payload.project_id.strip().upper() if payload.project_id and payload.project_id.strip() else None
    return [AdminUserScopeInput(role=role_name, project_id=project_id)]


def _normalize_permission_payload(
    payload: AdminUserCreate | AdminUserUpdate,
) -> list[AdminUserPermissionInput] | None:
    if payload.permission_scopes is not None:
        return payload.permission_scopes

    if payload.permission_codes is None:
        return None

    return [
        AdminUserPermissionInput(permission_code=code, project_id=None)
        for code in payload.permission_codes
    ]


def _build_firestore_scopes(roles: list[str], project_ids: list[str]) -> list[AdminUserScopeItem]:
    if not roles:
        return []
    if not project_ids:
        return [AdminUserScopeItem(role_name=role, project_id=None) for role in roles]
    if len(roles) == 1:
        return [AdminUserScopeItem(role_name=roles[0], project_id=project_id) for project_id in project_ids]

    limit = min(len(roles), len(project_ids))
    return [
        AdminUserScopeItem(role_name=roles[i], project_id=project_ids[i])
        for i in range(limit)
    ]


def _build_scopes_from_persisted_or_fallback(
    persisted_scopes: list[dict[str, str | None]] | None,
    roles: list[str],
    project_ids: list[str],
) -> list[AdminUserScopeItem]:
    if persisted_scopes:
        result: list[AdminUserScopeItem] = []
        seen: set[tuple[str, str | None]] = set()
        for item in persisted_scopes:
            role_name = str(item.get("role_name") or item.get("role") or "").strip().upper()
            if not role_name:
                continue
            project_raw = str(item.get("project_id") or "").strip().upper()
            project_id = project_raw or None
            key = (role_name, project_id)
            if key in seen:
                continue
            seen.add(key)
            result.append(AdminUserScopeItem(role_name=role_name, project_id=project_id))
        if result:
            return result

    return _build_firestore_scopes(roles, project_ids)


def _build_firestore_permission_scope_items(
    permission_scopes: list[dict[str, str | None]],
) -> list[AdminUserPermissionItem]:
    return [
        AdminUserPermissionItem(
            permission_code=str(item.get("permission_code") or ""),
            project_id=item.get("project_id"),
            effect=str(item.get("effect") or "allow"),
        )
        for item in permission_scopes
        if str(item.get("permission_code") or "").strip()
    ]


def _firestore_merge_permission_codes(
    roles: list[str],
    permission_scopes: list[dict[str, str | None]],
    role_permissions_map: dict[str, list[str]] | None = None,
) -> list[str]:
    return merge_role_permission_codes(
        roles,
        permission_scopes,
        role_permissions_map=role_permissions_map,
    )


@router.get("/admin/permissions", response_model=list[str])
def list_admin_permissions(
    _current_user: Any = Depends(require_any_role(["ADMIN", "SUPERVISOR"])),
):
    return list(CANONICAL_PERMISSION_CODES)


@router.get("/admin/role-permissions", response_model=dict[str, list[str]])
def list_admin_role_permissions(
    _current_user: Any = Depends(require_any_role(["ADMIN", "SUPERVISOR"])),
):
    return get_role_permission_map()


@router.put("/admin/role-permissions", response_model=dict[str, list[str]])
def update_admin_role_permissions(
    payload: AdminRolePermissionsUpdate,
    current_user: Any = Depends(require_any_role(["ADMIN"])),
):
    try:
        updated_permissions = save_role_permission_map(payload.role_permissions)
        write_firestore_audit_log(
            action="admin.role_permissions.updated",
            entity="system_settings",
            entity_id="role_permissions",
            actor=current_user,
            details={"role_permissions": updated_permissions},
        )
        return updated_permissions
    except Exception as exc:
        raise api_error(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            code="ROLE_PERMISSION_SETTINGS_UNAVAILABLE",
            message=f"No se pudieron guardar los permisos globales: {exc}",
        )


@router.get("", response_model=list[UserAgendaListItem])
def list_users(
    role: Optional[str] = Query(None, description="Role filter, e.g. OPERATIVO"),
    project_id: Optional[str] = Query(None, description="Project scope filter"),
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
):
    import logging
    logger = logging.getLogger(__name__)
    
    logger.info(f"list_users called: current_user={current_user.full_name} roles={current_user.roles} role_query={role} project={project_id}")
    
    # If user is OPERATIVO ONLY (no ADMIN/COORD/SUPERVISOR), only return self
    has_privileged_role = user_has_any_role(current_user, ["ADMIN", "COORD", "SUPERVISOR"], None)
    is_only_operativo = user_has_any_role(current_user, ["OPERATIVO"], None) and not has_privileged_role
    
    logger.info(f"  is_only_operativo={is_only_operativo} has_privileged_role={has_privileged_role}")
    
    if is_only_operativo:
        principal = current_user
        logger.info(f"  OPERATIVO-ONLY path: returning self {principal.full_name}")
        if principal.status != UserStatus.ACTIVE:
            return []
        return [
            UserAgendaListItem(
                id=principal.id,
                full_name=principal.full_name,
                email=principal.email,
                role_name=canonicalize_role_name(principal.roles[0] if principal.roles else "") or "",
                project_id=(principal.project_ids[0] if principal.project_ids else None),
                is_active=principal.status == UserStatus.ACTIVE,
            )
        ]

    logger.info(f"  Privileged path: fetching all users with role={role}")
    principals = list_firestore_users(role=role)
    project_filter = project_id.strip().upper() if project_id and project_id.strip() else None

    items: list[UserAgendaListItem] = []
    for principal in principals:
        if principal.status != UserStatus.ACTIVE:
            continue
        if project_filter and principal.project_ids and project_filter not in principal.project_ids:
            continue
        items.append(
            UserAgendaListItem(
                id=principal.id,
                full_name=principal.full_name,
                email=principal.email,
                role_name=canonicalize_role_name(principal.roles[0] if principal.roles else "") or "",
                project_id=(principal.project_ids[0] if principal.project_ids else None),
                is_active=principal.status == UserStatus.ACTIVE,
            )
        )

    items.sort(key=lambda item: item.full_name.lower())
    return items


@router.get("/admin", response_model=list[AdminUserListItem])
def list_admin_users(
    role: Optional[str] = Query(None),
    _current_user: Any = Depends(require_any_role(["ADMIN", "SUPERVISOR"])),
):
    principals = list_firestore_users(role=role)
    role_permissions_map = get_role_permission_map()
    return [
        AdminUserListItem(
            id=p.id,
            email=p.email,
            full_name=p.full_name,
            status=p.status,
            role_name=canonicalize_role_name(p.roles[0] if p.roles else "") or "",
            project_id=(p.project_ids[0] if p.project_ids else None),
            roles=[canonicalize_role_name(role) or str(role).strip().upper() for role in p.roles],
            project_ids=p.project_ids,
            scopes=_build_scopes_from_persisted_or_fallback(p.scopes, p.roles, p.project_ids),
            permission_codes=_firestore_merge_permission_codes(
                p.roles,
                p.permission_scopes,
                role_permissions_map=role_permissions_map,
            ),
            permission_scopes=_build_firestore_permission_scope_items(p.permission_scopes),
        )
        for p in principals
    ]


@router.post("/admin", response_model=AdminUserCreateResponse, status_code=status.HTTP_201_CREATED)
def create_admin_user(
    payload: AdminUserCreate,
    _current_user: Any = Depends(require_any_role(["ADMIN"])),
):
    if get_firestore_user_by_email(payload.email.strip().lower()):
        raise api_error(status_code=status.HTTP_409_CONFLICT, code="USER_EMAIL_ALREADY_REGISTERED", message="Email already registered")

    normalized_scopes = _normalize_scope_payload(payload)
    if normalized_scopes is None:
        normalized_scopes = []
    if not normalized_scopes:
        raise api_error(status_code=status.HTTP_400_BAD_REQUEST, code="USER_ROLE_SCOPE_REQUIRED", message="At least one role scope is required")

    normalized_permission_scopes = _normalize_permission_payload(payload)
    if normalized_permission_scopes is None:
        normalized_permission_scopes = []
    requested_permission_codes = _unique_keep_order(
        [item.permission_code.strip() for item in normalized_permission_scopes if item.permission_code.strip()]
    )
    missing_permissions = [
        permission_code
        for permission_code in requested_permission_codes
        if permission_code not in CANONICAL_PERMISSION_CODES
    ]
    if missing_permissions:
        raise api_error(status_code=status.HTTP_400_BAD_REQUEST, code="USER_PERMISSION_NOT_CONFIGURED", message=f"Permission not configured: {missing_permissions[0]}")

    roles = _unique_keep_order([scope.role.strip().upper() for scope in normalized_scopes])
    project_ids = _unique_keep_order(
        [scope.project_id.strip().upper() for scope in normalized_scopes if scope.project_id and scope.project_id.strip()]
    )
    firestore_permission_scopes = [
        {
            "permission_code": item.permission_code.strip(),
            "project_id": item.project_id.strip().upper() if item.project_id and item.project_id.strip() else None,
            "effect": item.effect.strip().lower(),
        }
        for item in normalized_permission_scopes
        if item.permission_code.strip()
    ]
    firestore_scopes = [
        {
            "role_name": scope.role.strip().upper(),
            "project_id": scope.project_id.strip().upper() if scope.project_id and scope.project_id.strip() else None,
        }
        for scope in normalized_scopes
        if scope.role.strip()
    ]
    principal = create_firestore_user(
        email=payload.email,
        full_name=payload.full_name,
        password_hash=get_password_hash(payload.password),
        roles=roles,
        project_ids=project_ids,
        first_name=payload.first_name,
        last_name=payload.last_name,
        second_last_name=payload.second_last_name,
        birth_date=payload.birth_date,
        scopes=firestore_scopes,
        permission_scopes=firestore_permission_scopes,
    )
    scopes = _build_scopes_from_persisted_or_fallback(principal.scopes, roles, project_ids)
    write_firestore_audit_log(
        action="USER_CREATED",
        entity="user",
        entity_id=str(principal.id),
        actor=_current_user,
        details={"email": principal.email, "roles": roles},
    )
    return AdminUserCreateResponse(
        id=principal.id,
        email=principal.email,
        full_name=principal.full_name,
        status=principal.status,
        role_name=canonicalize_role_name(roles[0] if roles else "") or "",
        project_id=(project_ids[0] if project_ids else None),
        roles=roles,
        project_ids=project_ids,
        scopes=scopes,
        permission_codes=_firestore_merge_permission_codes(roles, principal.permission_scopes),
        permission_scopes=_build_firestore_permission_scope_items(principal.permission_scopes),
    )


@router.patch("/admin/{user_id}", response_model=AdminUserCreateResponse)
def update_admin_user(
    user_id: str,
    payload: AdminUserUpdate,
    _current_user: Any = Depends(require_any_role(["ADMIN"])),
):
    try:
        user_uuid = UUID(user_id)
    except ValueError:
        raise api_error(status_code=status.HTTP_400_BAD_REQUEST, code="USER_INVALID_ID", message="Invalid user id")

    existing = get_firestore_user_by_id(user_uuid)
    if existing is None:
        raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="USER_NOT_FOUND", message="User not found")

    scopes_payload = _normalize_scope_payload(payload)
    new_roles = None
    new_project_ids = None
    firestore_scopes = None
    if scopes_payload is not None:
        new_roles = _unique_keep_order([scope.role.strip().upper() for scope in scopes_payload])
        new_project_ids = _unique_keep_order(
            [scope.project_id.strip().upper() for scope in scopes_payload if scope.project_id and scope.project_id.strip()]
        )
        firestore_scopes = [
            {
                "role_name": scope.role.strip().upper(),
                "project_id": scope.project_id.strip().upper() if scope.project_id and scope.project_id.strip() else None,
            }
            for scope in scopes_payload
            if scope.role.strip()
        ]

    permission_payload = _normalize_permission_payload(payload)
    firestore_permission_scopes = None
    if permission_payload is not None:
        requested_permission_codes = _unique_keep_order(
            [item.permission_code.strip() for item in permission_payload if item.permission_code.strip()]
        )
        missing_permissions = [
            permission_code
            for permission_code in requested_permission_codes
            if permission_code not in CANONICAL_PERMISSION_CODES
        ]
        if missing_permissions:
            raise api_error(status_code=status.HTTP_400_BAD_REQUEST, code="USER_PERMISSION_NOT_CONFIGURED", message=f"Permission not configured: {missing_permissions[0]}")
        firestore_permission_scopes = [
            {
                "permission_code": item.permission_code.strip(),
                "project_id": item.project_id.strip().upper() if item.project_id and item.project_id.strip() else None,
                "effect": item.effect.strip().lower(),
            }
            for item in permission_payload
            if item.permission_code.strip()
        ]

    status_value = payload.status.value if payload.status is not None else None
    if _is_protected_admin_user(existing):
        if status_value is not None and status_value != UserStatus.ACTIVE.value:
            raise api_error(
                status_code=status.HTTP_403_FORBIDDEN,
                code="USER_PROTECTED",
                message="El usuario admin@sao.mx no se puede desactivar ni borrar",
            )
        if new_roles is not None and "ADMIN" not in new_roles:
            raise api_error(
                status_code=status.HTTP_403_FORBIDDEN,
                code="USER_PROTECTED",
                message="El usuario admin@sao.mx debe conservar el rol ADMIN",
            )

    updated = update_firestore_user(
        user_id=user_uuid,
        full_name=payload.full_name,
        status=status_value,
        roles=new_roles,
        project_ids=new_project_ids,
        first_name=payload.first_name,
        last_name=payload.last_name,
        second_last_name=payload.second_last_name,
        birth_date=payload.birth_date,
        scopes=firestore_scopes,
        permission_scopes=firestore_permission_scopes,
    )
    if updated is None:
        raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="USER_NOT_FOUND", message="User not found")
    write_firestore_audit_log(
        action="USER_UPDATED",
        entity="user",
        entity_id=str(updated.id),
        actor=_current_user,
        details={"roles": updated.roles, "status": str(getattr(updated, "status", ""))},
    )
    scopes = _build_scopes_from_persisted_or_fallback(updated.scopes, updated.roles, updated.project_ids)
    return AdminUserCreateResponse(
        id=updated.id,
        email=updated.email,
        full_name=updated.full_name,
        status=updated.status,
        role_name=canonicalize_role_name(updated.roles[0] if updated.roles else "") or "",
        project_id=(updated.project_ids[0] if updated.project_ids else None),
        roles=updated.roles,
        project_ids=updated.project_ids,
        scopes=scopes,
        permission_codes=_firestore_merge_permission_codes(updated.roles, updated.permission_scopes),
        permission_scopes=_build_firestore_permission_scope_items(updated.permission_scopes),
    )


@router.put("/admin/{user_id}/reset-password", status_code=status.HTTP_200_OK)
def reset_admin_user_password_route(
    user_id: str,
    payload: AdminUserPasswordResetRequest,
    current_user: Any = Depends(require_any_role(["ADMIN"])),
):
    try:
        user_uuid = UUID(user_id)
    except ValueError:
        raise api_error(status_code=status.HTTP_400_BAD_REQUEST, code="USER_INVALID_ID", message="Invalid user id")

    if not _is_root_admin_actor(current_user):
        raise api_error(
            status_code=status.HTTP_403_FORBIDDEN,
            code="PASSWORD_RESET_FORBIDDEN",
            message="Solo admin@sao.mx puede reiniciar contraseñas de usuarios",
        )

    existing = get_firestore_user_by_id(user_uuid)
    if existing is None:
        raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="USER_NOT_FOUND", message="User not found")

    updated = reset_firestore_user_password(user_uuid, get_password_hash(payload.new_password))
    if updated is None:
        raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="USER_NOT_FOUND", message="User not found")

    write_firestore_audit_log(
        action="USER_PASSWORD_RESET",
        entity="user",
        entity_id=str(updated.id),
        actor=current_user,
        details={"email": updated.email},
    )
    return {"ok": True}


@router.delete("/admin/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_admin_user(
    user_id: str,
    current_user: Any = Depends(require_any_role(["ADMIN"])),
):
    try:
        user_uuid = UUID(user_id)
    except ValueError:
        raise api_error(status_code=status.HTTP_400_BAD_REQUEST, code="USER_INVALID_ID", message="Invalid user id")

    if not _is_root_admin_actor(current_user):
        raise api_error(
            status_code=status.HTTP_403_FORBIDDEN,
            code="USER_DELETE_FORBIDDEN",
            message="Solo admin@sao.mx puede eliminar usuarios",
        )

    existing = get_firestore_user_by_id(user_uuid)
    if existing is None:
        raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="USER_NOT_FOUND", message="User not found")
    if _is_protected_admin_user(existing):
        raise api_error(
            status_code=status.HTTP_403_FORBIDDEN,
            code="USER_PROTECTED",
            message="El usuario admin@sao.mx no se puede borrar",
        )
    if existing.status != UserStatus.INACTIVE:
        raise api_error(
            status_code=status.HTTP_409_CONFLICT,
            code="USER_DELETE_REQUIRES_INACTIVE",
            message="User must be inactive before deletion",
        )

    deleted = delete_firestore_user(user_uuid)
    if not deleted:
        raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="USER_NOT_FOUND", message="User not found")

    write_firestore_audit_log(
        action="USER_DELETED",
        entity="user",
        entity_id=str(existing.id),
        actor=current_user,
        details={"email": existing.email, "roles": existing.roles},
    )
    return None

