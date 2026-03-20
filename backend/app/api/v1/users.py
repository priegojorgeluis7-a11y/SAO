from typing import Any, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Query, status
from app.core.api_errors import api_error

from app.api.deps import get_current_user, require_any_role
from app.core.permission_catalog import CANONICAL_PERMISSION_CODES, DEFAULT_ROLE_PERMISSION_CODES
from app.core.security import get_password_hash
from app.core.enums import UserStatus
from app.schemas.user import (
    AdminUserCreate,
    AdminUserCreateResponse,
    AdminUserListItem,
    AdminUserPermissionInput,
    AdminUserPermissionItem,
    AdminUserScopeInput,
    AdminUserScopeItem,
    AdminUserUpdate,
    UserAgendaListItem,
)
from app.services.audit_service import write_firestore_audit_log
from app.services.firestore_identity_service import (
    list_firestore_users,
    create_firestore_user,
    get_firestore_user_by_email,
    update_firestore_user,
)

router = APIRouter(prefix="/users", tags=["users"])


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
) -> list[str]:
    role_permission_codes: list[str] = []
    for role_name in roles:
        role_permission_codes.extend(DEFAULT_ROLE_PERMISSION_CODES.get(role_name.strip().upper(), []))

    allow_codes = {
        str(item.get("permission_code") or "")
        for item in permission_scopes
        if str(item.get("effect") or "allow").lower() == "allow" and item.get("project_id") is None
    }
    deny_codes = {
        str(item.get("permission_code") or "")
        for item in permission_scopes
        if str(item.get("effect") or "allow").lower() == "deny" and item.get("project_id") is None
    }
    merged = _unique_keep_order(role_permission_codes + list(allow_codes))
    return [code for code in merged if code and code not in deny_codes]


@router.get("/admin/permissions", response_model=list[str])
def list_admin_permissions(
    _current_user: Any = Depends(require_any_role(["ADMIN", "SUPERVISOR"])),
):
    return list(CANONICAL_PERMISSION_CODES)


@router.get("/admin/role-permissions", response_model=dict[str, list[str]])
def list_admin_role_permissions(
    _current_user: Any = Depends(require_any_role(["ADMIN", "SUPERVISOR"])),
):
    return dict(DEFAULT_ROLE_PERMISSION_CODES)


@router.get("", response_model=list[UserAgendaListItem])
def list_users(
    role: Optional[str] = Query(None, description="Role filter, e.g. OPERATIVO"),
    project_id: Optional[str] = Query(None, description="Project scope filter"),
    _current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR"])),
):
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
                role_name=(principal.roles[0] if principal.roles else ""),
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
    return [
        AdminUserListItem(
            id=p.id,
            email=p.email,
            full_name=p.full_name,
            status=p.status,
            role_name=(p.roles[0] if p.roles else ""),
            project_id=(p.project_ids[0] if p.project_ids else None),
            roles=p.roles,
            project_ids=p.project_ids,
            scopes=_build_scopes_from_persisted_or_fallback(p.scopes, p.roles, p.project_ids),
            permission_codes=_firestore_merge_permission_codes(p.roles, p.permission_scopes),
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
        role_name=(roles[0] if roles else ""),
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
    updated = update_firestore_user(
        user_id=user_uuid,
        full_name=payload.full_name,
        status=status_value,
        roles=new_roles,
        project_ids=new_project_ids,
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
        role_name=(updated.roles[0] if updated.roles else ""),
        project_id=(updated.project_ids[0] if updated.project_ids else None),
        roles=updated.roles,
        project_ids=updated.project_ids,
        scopes=scopes,
        permission_codes=_firestore_merge_permission_codes(updated.roles, updated.permission_scopes),
        permission_scopes=_build_firestore_permission_scope_items(updated.permission_scopes),
    )

