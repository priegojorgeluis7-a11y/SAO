from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class AssignmentListItem(BaseModel):
    id: str
    project_id: str
    assignee_user_id: UUID
    assignee_name: str | None = None
    assignee_email: str | None = None
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
    latitude: float | None = None
    longitude: float | None = None


class AssignmentCreate(BaseModel):
    project_id: str = Field(..., min_length=1, max_length=10)
    assignee_user_id: UUID
    activity_type_code: str = Field(..., min_length=1, max_length=50)
    title: str | None = Field(default=None, max_length=200)
    front_id: UUID | None = None
    front_ref: str | None = Field(default=None, max_length=255)
    estado: str | None = Field(default=None, max_length=100)
    municipio: str | None = Field(default=None, max_length=100)
    colonia: str | None = Field(default=None, max_length=200)
    pk: int = Field(default=0, ge=0)
    start_at: datetime
    end_at: datetime
    risk: str = Field(default="bajo", max_length=20)
    latitude: float | None = None
    longitude: float | None = None


class AssignmentAssigneeOption(BaseModel):
    user_id: UUID
    full_name: str
    email: str
    role_name: str


class AssignmentCancelResponse(BaseModel):
    id: str
    canceled: bool
    execution_state: str
    canceled_at: datetime | None = None
    canceled_by_user_id: UUID | None = None
    cancel_reason: str | None = None


class AssignmentCancelRequest(BaseModel):
    reason: str | None = Field(default=None, max_length=500)


class AssignmentTransferRequest(BaseModel):
    assignee_user_id: UUID
    reason: str | None = Field(default=None, max_length=500)