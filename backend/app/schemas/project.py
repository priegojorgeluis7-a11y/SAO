from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.project import ProjectStatus
from app.schemas.territory import FrontCreate, LocationScopeCreate


class ProjectCreate(BaseModel):
    id: str = Field(min_length=1, max_length=10)
    name: str = Field(min_length=1, max_length=255)
    status: ProjectStatus = ProjectStatus.ACTIVE
    start_date: date
    end_date: date | None = None
    bootstrap_from_tmq: bool = False
    base_catalog_version: str | None = None
    fronts: list[FrontCreate] = Field(default_factory=list)
    location_scope: list[LocationScopeCreate] = Field(default_factory=list)


class ProjectUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    status: ProjectStatus | None = None
    start_date: date | None = None
    end_date: date | None = None


class ProjectOut(BaseModel):
    id: str
    name: str
    status: ProjectStatus
    start_date: date
    end_date: date | None = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
