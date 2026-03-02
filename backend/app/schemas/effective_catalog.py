from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel


class EffectiveCatalogMeta(BaseModel):
    project_id: str
    version_id: str
    generated_at: datetime


class EffectiveActivity(BaseModel):
    id: str
    name_effective: str
    description: Optional[str] = None
    is_enabled_effective: bool
    sort_order_effective: int
    color_effective: Optional[str] = None


class EffectiveSubcategory(BaseModel):
    id: str
    activity_id: str
    name_effective: str
    description: Optional[str] = None
    is_enabled_effective: bool
    sort_order_effective: int
    color_effective: Optional[str] = None


class EffectivePurpose(BaseModel):
    id: str
    activity_id: str
    subcategory_id: Optional[str] = None
    name_effective: str
    is_enabled_effective: bool
    sort_order_effective: int
    color_effective: Optional[str] = None


class EffectiveTopic(BaseModel):
    id: str
    type: Optional[str] = None
    description: Optional[str] = None
    name_effective: str
    is_enabled_effective: bool
    sort_order_effective: int
    color_effective: Optional[str] = None


class EffectiveRelActivityTopic(BaseModel):
    activity_id: str
    topic_id: str
    is_enabled_effective: bool


class EffectiveResult(BaseModel):
    id: str
    name_effective: str
    category: str
    severity_effective: Optional[str] = None
    is_enabled_effective: bool
    sort_order_effective: int
    color_effective: Optional[str] = None


class EffectiveAttendee(BaseModel):
    id: str
    type: str
    description: Optional[str] = None
    name_effective: str
    is_enabled_effective: bool
    sort_order_effective: int
    color_effective: Optional[str] = None


class EffectiveCatalogResponse(BaseModel):
    meta: EffectiveCatalogMeta
    activities: List[EffectiveActivity]
    subcategories: List[EffectiveSubcategory]
    purposes: List[EffectivePurpose]
    topics: List[EffectiveTopic]
    rel_activity_topics: List[EffectiveRelActivityTopic]
    results: List[EffectiveResult]
    attendees: List[EffectiveAttendee]


class CurrentCatalogVersionResponse(BaseModel):
    version_id: str
    generated_at: datetime


class DiffMeta(BaseModel):
    project_id: str
    from_version_id: str
    to_version_id: str
    generated_at: datetime
    catalog_hash: Optional[str] = None


class DiffEntityChanges(BaseModel):
    upserts: List[dict]
    deletes: List[str]


class DiffResponse(BaseModel):
    meta: DiffMeta
    changes: dict
