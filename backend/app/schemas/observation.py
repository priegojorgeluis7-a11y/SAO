from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ObservationCreateIn(BaseModel):
    project_id: str
    activity_id: UUID
    assignee_user_id: UUID | None = None
    tags: list[str] = Field(default_factory=list)
    message: str
    severity: str = "MED"
    due_date: datetime | None = None


class ObservationOut(BaseModel):
    id: UUID
    project_id: str
    activity_id: UUID
    assignee_user_id: UUID | None = None
    tags: list[str] = Field(default_factory=list)
    message: str
    severity: str
    due_date: datetime | None = None
    status: str
    resolved_at: datetime | None = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ObservationResolveOut(BaseModel):
    ok: bool
