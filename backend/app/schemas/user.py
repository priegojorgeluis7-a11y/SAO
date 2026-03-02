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
