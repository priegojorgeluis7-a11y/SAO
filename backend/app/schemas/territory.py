from pydantic import BaseModel, ConfigDict, Field


class FrontCreate(BaseModel):
    code: str | None = Field(default=None, max_length=10)
    name: str = Field(min_length=1, max_length=255)
    pk_start: int | None = None
    pk_end: int | None = None


class FrontOut(BaseModel):
    id: str
    project_id: str
    code: str
    name: str
    pk_start: int | None = None
    pk_end: int | None = None

    model_config = ConfigDict(from_attributes=True)


class LocationScopeCreate(BaseModel):
    estado: str = Field(min_length=1, max_length=100)
    municipio: str = Field(min_length=1, max_length=100)


class LocationOut(BaseModel):
    id: str
    estado: str
    municipio: str

    model_config = ConfigDict(from_attributes=True)


class StateSummaryOut(BaseModel):
    estado: str
    municipios_count: int
