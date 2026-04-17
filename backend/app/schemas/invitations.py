from datetime import datetime
from typing import Literal

from pydantic import BaseModel, EmailStr, Field


class InvitationCreateRequest(BaseModel):
    role: Literal["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO", "LECTOR"]
    target_email: EmailStr | None = None
    expire_days: int = Field(default=7, ge=1, le=30)


class InvitationResponse(BaseModel):
    invite_id: str
    role: str
    created_by: str
    target_email: EmailStr | None = None
    expires_at: datetime
    used: bool = False
    used_by: EmailStr | None = None
    used_at: datetime | None = None
    created_at: datetime
