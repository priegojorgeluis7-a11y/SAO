from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field

from app.core.enums import ProjectStatus
from app.schemas.territory import FrontCreate, LocationScopeCreate


class ProjectFrontSummary(BaseModel):
    code: str
    name: str
    pk_start: int | None = None
    pk_end: int | None = None


class ProjectLocationSummary(BaseModel):
    estado: str
    municipio: str


class ProjectStateSummary(BaseModel):
    estado: str
    municipios_count: int


class ProjectFrontLocationSummary(BaseModel):
    front_code: str
    front_name: str | None = None
    estado: str
    municipio: str


class FrontLocationScopeCreate(BaseModel):
    front_code: str = Field(min_length=1, max_length=10)
    front_name: str | None = Field(default=None, max_length=255)
    estado: str = Field(min_length=1, max_length=100)
    municipio: str = Field(min_length=1, max_length=100)


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
    front_location_scope: list[FrontLocationScopeCreate] = Field(default_factory=list)


class ProjectUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    status: ProjectStatus | None = None
    start_date: date | None = None
    end_date: date | None = None
    fronts: list[FrontCreate] | None = None
    location_scope: list[LocationScopeCreate] | None = None
    front_location_scope: list[FrontLocationScopeCreate] | None = None


class ProjectOut(BaseModel):
    id: str
    name: str
    status: ProjectStatus
    start_date: date
    end_date: date | None = None
    fronts_count: int = 0
    municipalities_count: int = 0
    states_count: int = 0
    fronts: list[ProjectFrontSummary] = Field(default_factory=list)
    location_scope: list[ProjectLocationSummary] = Field(default_factory=list)
    front_location_scope: list[ProjectFrontLocationSummary] = Field(default_factory=list)
    states: list[ProjectStateSummary] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
