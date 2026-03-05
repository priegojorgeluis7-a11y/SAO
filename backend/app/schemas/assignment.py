from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class AssignmentListItem(BaseModel):
    id: str
    project_id: str
    assignee_user_id: UUID
    activity_id: str
    title: str
    frente: str
    municipio: str
    estado: str
    pk: int
    start_at: datetime
    end_at: datetime
    risk: str
    status: str = "PROGRAMADA"


class AssignmentCreate(BaseModel):
    project_id: str = Field(..., min_length=1, max_length=10)
    assignee_user_id: UUID
    activity_type_code: str = Field(..., min_length=1, max_length=50)
    title: str | None = Field(default=None, max_length=200)
    front_id: UUID | None = None
    pk: int = Field(default=0, ge=0)
    start_at: datetime
    end_at: datetime
    risk: str = Field(default="bajo", max_length=20)


class AssignmentAssigneeOption(BaseModel):
    user_id: UUID
    full_name: str
    email: str
    role_name: str