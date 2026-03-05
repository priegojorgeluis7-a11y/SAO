from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field


class CatalogEditorMeta(BaseModel):
    project_id: str
    version_id: str
    generated_at: datetime


class CatalogEditorActivity(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    is_active: bool
    sort_order: int


class CatalogEditorSubcategory(BaseModel):
    id: str
    activity_id: str
    name: str
    description: Optional[str] = None
    is_active: bool
    sort_order: int


class CatalogEditorPurpose(BaseModel):
    id: str
    activity_id: str
    subcategory_id: Optional[str] = None
    name: str
    is_active: bool
    sort_order: int


class CatalogEditorTopic(BaseModel):
    id: str
    type: Optional[str] = None
    name: str
    description: Optional[str] = None
    is_active: bool
    sort_order: int


class CatalogEditorRelActivityTopic(BaseModel):
    activity_id: str
    topic_id: str
    is_active: bool


class CatalogEditorResult(BaseModel):
    id: str
    category: str
    name: str
    description: Optional[str] = None
    is_active: bool
    sort_order: int


class CatalogEditorAttendee(BaseModel):
    id: str
    type: str
    name: str
    description: Optional[str] = None
    is_active: bool
    sort_order: int


class CatalogEditorResponse(BaseModel):
    meta: CatalogEditorMeta
    activities: list[CatalogEditorActivity]
    subcategories: list[CatalogEditorSubcategory]
    purposes: list[CatalogEditorPurpose]
    topics: list[CatalogEditorTopic]
    rel_activity_topics: list[CatalogEditorRelActivityTopic]
    results: list[CatalogEditorResult] = []
    attendees: list[CatalogEditorAttendee] = []


class ActivityCreateRequest(BaseModel):
    id: str = Field(..., min_length=1)
    name: str = Field(..., min_length=1)
    description: Optional[str] = None


class ActivityUpdateRequest(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1)
    description: Optional[str] = None
    is_active: Optional[bool] = None
    sort_order: Optional[int] = None


class SubcategoryCreateRequest(BaseModel):
    id: str = Field(..., min_length=1)
    activity_id: str = Field(..., min_length=1)
    name: str = Field(..., min_length=1)
    description: Optional[str] = None


class SubcategoryUpdateRequest(BaseModel):
    activity_id: Optional[str] = Field(default=None, min_length=1)
    name: Optional[str] = Field(default=None, min_length=1)
    description: Optional[str] = None
    is_active: Optional[bool] = None
    sort_order: Optional[int] = None


class PurposeCreateRequest(BaseModel):
    id: str = Field(..., min_length=1)
    activity_id: str = Field(..., min_length=1)
    subcategory_id: Optional[str] = None
    name: str = Field(..., min_length=1)


class PurposeUpdateRequest(BaseModel):
    activity_id: Optional[str] = Field(default=None, min_length=1)
    subcategory_id: Optional[str] = None
    name: Optional[str] = Field(default=None, min_length=1)
    is_active: Optional[bool] = None
    sort_order: Optional[int] = None


class TopicCreateRequest(BaseModel):
    id: str = Field(..., min_length=1)
    type: Optional[str] = None
    name: str = Field(..., min_length=1)
    description: Optional[str] = None


class TopicUpdateRequest(BaseModel):
    type: Optional[str] = None
    name: Optional[str] = Field(default=None, min_length=1)
    description: Optional[str] = None
    is_active: Optional[bool] = None
    sort_order: Optional[int] = None


class ResultCreateRequest(BaseModel):
    id: str = Field(..., min_length=1)
    category: str = Field(..., min_length=1)
    name: str = Field(..., min_length=1)
    description: Optional[str] = None


class ResultUpdateRequest(BaseModel):
    category: Optional[str] = Field(default=None, min_length=1)
    name: Optional[str] = Field(default=None, min_length=1)
    description: Optional[str] = None
    is_active: Optional[bool] = None


class AttendeeCreateRequest(BaseModel):
    id: str = Field(..., min_length=1)
    type: str = Field(..., min_length=1)
    name: str = Field(..., min_length=1)
    description: Optional[str] = None


class AttendeeUpdateRequest(BaseModel):
    type: Optional[str] = Field(default=None, min_length=1)
    name: Optional[str] = Field(default=None, min_length=1)
    description: Optional[str] = None
    is_active: Optional[bool] = None


class RelActivityTopicUpsertRequest(BaseModel):
    activity_id: str = Field(..., min_length=1)
    topic_id: str = Field(..., min_length=1)


class ReorderEntityRequest(BaseModel):
    entity: Literal["activity", "subcategory", "purpose", "topic"]
    ids: list[str] = Field(default_factory=list)
