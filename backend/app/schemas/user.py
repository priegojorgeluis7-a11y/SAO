from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.core.enums import UserStatus


class UserBase(BaseModel):
    email: EmailStr
    full_name: str


class UserCreate(UserBase):
    password: str


class UserResponse(UserBase):
    id: UUID
    status: UserStatus
    last_login_at: datetime | None
    created_at: datetime
    roles: list[str] = Field(default_factory=list)
    permission_codes: list[str] = Field(default_factory=list)
    permission_scopes: list[dict[str, str | None]] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)


class UserAgendaListItem(BaseModel):
    id: UUID
    full_name: str
    email: EmailStr
    role_name: str
    project_id: str | None = None
    is_active: bool = True


class AdminUserScopeInput(BaseModel):
    role: str
    project_id: str | None = None


class AdminUserScopeItem(BaseModel):
    role_name: str
    project_id: str | None = None


class AdminUserPermissionInput(BaseModel):
    permission_code: str
    project_id: str | None = None
    effect: Literal["allow", "deny"] = "allow"


class AdminUserPermissionItem(BaseModel):
    permission_code: str
    project_id: str | None = None
    effect: Literal["allow", "deny"] = "allow"


class AdminRolePermissionsUpdate(BaseModel):
    role_permissions: dict[str, list[str]] = Field(default_factory=dict)


class AdminUserCreate(BaseModel):
    email: EmailStr
    full_name: str
    password: str
    first_name: str | None = None
    last_name: str | None = None
    second_last_name: str | None = None
    birth_date: str | None = None
    role: str | None = None
    project_id: str | None = None
    scopes: list[AdminUserScopeInput] | None = None
    permission_codes: list[str] | None = None
    permission_scopes: list[AdminUserPermissionInput] | None = None


class AdminUserUpdate(BaseModel):
    full_name: str | None = None
    first_name: str | None = None
    last_name: str | None = None
    second_last_name: str | None = None
    birth_date: str | None = None
    status: UserStatus | None = None
    role: str | None = None
    project_id: str | None = None
    scopes: list[AdminUserScopeInput] | None = None
    permission_codes: list[str] | None = None
    permission_scopes: list[AdminUserPermissionInput] | None = None


class AdminUserPasswordResetRequest(BaseModel):
    new_password: str = Field(..., min_length=8, max_length=256)


class AdminUserListItem(BaseModel):
    id: UUID
    email: EmailStr
    full_name: str
    status: UserStatus
    role_name: str
    project_id: str | None = None
    roles: list[str] = Field(default_factory=list)
    project_ids: list[str] = Field(default_factory=list)
    scopes: list[AdminUserScopeItem] = Field(default_factory=list)
    permission_codes: list[str] = Field(default_factory=list)
    permission_scopes: list[AdminUserPermissionItem] = Field(default_factory=list)


class AdminUserCreateResponse(BaseModel):
    id: UUID
    email: EmailStr
    full_name: str
    status: UserStatus
    role_name: str
    project_id: str | None = None
    roles: list[str] = Field(default_factory=list)
    project_ids: list[str] = Field(default_factory=list)
    scopes: list[AdminUserScopeItem] = Field(default_factory=list)
    permission_codes: list[str] = Field(default_factory=list)
    permission_scopes: list[AdminUserPermissionItem] = Field(default_factory=list)


class MyProjectItem(BaseModel):
    """Authorized project and role summary for authenticated user."""
    project_id: str
    project_name: str
    role_names: list[str]
