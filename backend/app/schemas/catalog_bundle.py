"""Pydantic schemas for the sao.catalog.bundle.v1 format.

The bundle uses clean field names (active/order) rather than the
_effective suffix variants used by the /catalog/effective endpoint.
"""
from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, model_validator


# ─── Entity items (bundle spec uses 'active' and 'order') ─────────────────────

class CatalogBundleActivityItem(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    active: bool
    order: int


class CatalogBundleSubcategoryItem(BaseModel):
    id: str
    activity_id: str
    name: str
    description: Optional[str] = None
    active: bool
    order: int


class CatalogBundlePurposeItem(BaseModel):
    id: str
    activity_id: str
    subcategory_id: Optional[str] = None
    name: str
    active: bool
    order: int


class CatalogBundleTopicItem(BaseModel):
    id: str
    type: Optional[str] = None
    name: str
    description: Optional[str] = None
    active: bool
    order: int


class CatalogBundleResultItem(BaseModel):
    id: str
    category: str
    name: str
    description: Optional[str] = None
    active: bool
    order: int


class CatalogBundleAssistantItem(BaseModel):
    id: str
    type: str
    name: str
    description: Optional[str] = None
    active: bool
    order: int


# ─── Relations ────────────────────────────────────────────────────────────────

class CatalogBundleRelItem(BaseModel):
    activity_id: str
    topic_id: str
    active: bool


# ─── Effective section ────────────────────────────────────────────────────────

class CatalogBundleEntities(BaseModel):
    activities: list[CatalogBundleActivityItem]
    subcategories: list[CatalogBundleSubcategoryItem]
    purposes: list[CatalogBundlePurposeItem]
    topics: list[CatalogBundleTopicItem]
    results: list[CatalogBundleResultItem]
    assistants: list[CatalogBundleAssistantItem]


class CatalogBundleRelations(BaseModel):
    activity_to_topics_suggested: list[CatalogBundleRelItem]


class CatalogBundleRules(BaseModel):
    cascades: dict = Field(
        default_factory=lambda: {
            "subcategories_by_activity": True,
            "purposes_by_activity_and_subcategory": True,
        }
    )
    null_semantics: dict = Field(
        default_factory=lambda: {
            "purpose.subcategory_id": "null => propósito global para esa actividad"
        }
    )
    topic_policy: dict = Field(default_factory=lambda: {"default": "any"})


class CatalogBundleEffective(BaseModel):
    entities: CatalogBundleEntities
    relations: CatalogBundleRelations
    rules: CatalogBundleRules


# ─── Editor section (only when include_editor=true) ───────────────────────────

class CatalogBundleEditor(BaseModel):
    layers: dict
    validation: dict


# ─── Meta & top-level ─────────────────────────────────────────────────────────

class CatalogBundleMeta(BaseModel):
    project_id: str
    bundle_id: str
    generated_at: datetime
    etag: str
    versions: dict


class CatalogBundleResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    schema_: str = Field("sao.catalog.bundle.v1", alias="schema")
    meta: CatalogBundleMeta
    effective: CatalogBundleEffective
    editor: Optional[CatalogBundleEditor] = None


# ─── Project ops ──────────────────────────────────────────────────────────────

class CatalogOp(BaseModel):
    """A single catalog mutation op.

    Desktop clients send the payload under key ``payload``; newer clients may
    use ``data``.  Both are accepted — ``payload`` is normalized to ``data``
    before validation so downstream code always reads ``op.data``.
    """

    model_config = ConfigDict(extra="ignore")

    op: Literal[
        "upsert", "patch", "deactivate", "activate",
        "rel_upsert", "rel_deactivate", "reorder",
        "delete",  # remove row from bundle, accepted from Desktop clients
    ]
    entity: str
    id: str
    data: Optional[dict] = None

    @model_validator(mode="before")
    @classmethod
    def _normalize_payload_key(cls, values: dict) -> dict:
        """Accept 'payload' as an alias for 'data'."""
        if isinstance(values, dict) and not values.get("data") and values.get("payload"):
            values = {**values, "data": values["payload"]}
        return values


class ProjectOpsRequest(BaseModel):
    ops: list[CatalogOp]


# ─── Validate / Publish / Rollback ────────────────────────────────────────────

class CatalogValidationIssue(BaseModel):
    code: str
    severity: Literal["error", "warning", "info"]
    message: str
    entity_id: Optional[str] = None


class CatalogValidationResponse(BaseModel):
    status: Literal["ok", "warning", "error"]
    issues: list[CatalogValidationIssue]


class CatalogPublishResponse(BaseModel):
    version_id: str
    published_at: datetime
    status: str = "published"


class CatalogRollbackRequest(BaseModel):
    to_effective_version: str


class CatalogRollbackResponse(BaseModel):
    version_id: str
    restored_at: datetime
