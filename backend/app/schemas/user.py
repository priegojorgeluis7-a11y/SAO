from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr

from app.models.user import UserStatus


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
    
    model_config = ConfigDict(from_attributes=True)


class UserAgendaListItem(BaseModel):
    id: UUID
    full_name: str
    email: EmailStr
    role_name: str
    project_id: str | None = None
    is_active: bool = True


class AdminUserCreate(BaseModel):
    email: EmailStr
    full_name: str
    password: str
    role: str
    project_id: str | None = None


class AdminUserUpdate(BaseModel):
    full_name: str | None = None
    status: UserStatus | None = None
    role: str | None = None
    project_id: str | None = None


class AdminUserListItem(BaseModel):
    id: UUID
    email: EmailStr
    full_name: str
    status: UserStatus
    role_name: str
    project_id: str | None = None


class AdminUserCreateResponse(BaseModel):
    id: UUID
    email: EmailStr
    full_name: str
    status: UserStatus
    role_name: str
    project_id: str | None = None


class MyProjectItem(BaseModel):
    """Authorized project and role summary for authenticated user."""
    project_id: str
    project_name: str
    role_names: list[str]
