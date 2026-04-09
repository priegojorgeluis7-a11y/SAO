from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ReviewQueueItemOut(BaseModel):
    id: UUID
    pk: str
    front: str | None = None
    municipality: str | None = None
    activity_type: str
    title: str | None = None
    project_id: str | None = None
    assigned_to_user_name: str | None = None
    risk: str
    created_at: datetime
    updated_at: datetime
    status: str
    gps_critical: bool
    missing_evidence: bool
    catalog_change_pending: bool
    checklist_incomplete: bool
    has_conflicts: bool
    severity: str
    evidence_count: int
    conflict_count: int
    lat: float | None = None
    lon: float | None = None
    operational_state: str = Field("PENDIENTE", description="PENDIENTE | EN_CURSO | POR_COMPLETAR | BLOQUEADA | CANCELADA")
    sync_state: str = Field("SYNCED", description="LOCAL_ONLY | READY_TO_SYNC | SYNC_IN_PROGRESS | SYNCED | SYNC_ERROR")
    review_state: str = Field("PENDING_REVIEW", description="NOT_APPLICABLE | PENDING_REVIEW | CHANGES_REQUIRED | APPROVED | REJECTED")
    next_action: str = Field("ESPERAR_DECISION_COORDINACION", description="Normalized next action for clients")


class ReviewQueueCountersOut(BaseModel):
    pending: int
    changed: int
    gps_critical: int
    rejected: int


class ReviewQueueResponse(BaseModel):
    items: list[ReviewQueueItemOut]
    counters: ReviewQueueCountersOut


class ReviewChangeFieldOut(BaseModel):
    field_key: str
    original: str | None = None
    proposed: str | None = None
    conflict_type: str
    suggested_options: list[str]


class ReviewActivityOut(BaseModel):
    id: UUID
    project_id: str
    front: str | None = None
    municipality: str | None = None
    activity_type: str
    title: str | None = None
    description: str | None = None
    wizard_payload: dict[str, object] | None = None
    pk: str | None = None
    status: str
    quality_flags: dict[str, bool]
    changeset: list[ReviewChangeFieldOut]
    history: list[dict]


class ReviewEvidenceOut(BaseModel):
    id: UUID
    takenAt: datetime
    lat: float | None = None
    lng: float | None = None
    accuracy: float | None = None
    device: str | None = None
    description: str | None = None
    gcsKey: str | None = None
    status: str


class ReviewFieldResolutionIn(BaseModel):
    field_key: str
    action: str
    chosen_catalog_id: str | None = None


class ReviewDecisionIn(BaseModel):
    decision: str
    reject_reason_code: str | None = None
    comment: str | None = None
    field_resolutions: list[ReviewFieldResolutionIn] = Field(default_factory=list)
    apply_to_similar: bool = False


class ReviewDecisionOut(BaseModel):
    ok: bool
    status: str


class ReviewEvidenceValidateIn(BaseModel):
    status: str
    reason_code: str | None = None
    comment: str | None = None


class ReviewEvidencePatchIn(BaseModel):
    description: str


class ReviewRejectPlaybookItemOut(BaseModel):
    reason_code: str
    label: str
    severity: str
    requires_comment: bool


class ReviewRejectPlaybookResponse(BaseModel):
    items: list[ReviewRejectPlaybookItemOut]


class ReviewRejectReasonCreateIn(BaseModel):
    reason_code: str
    label: str
    severity: str = "MED"
    requires_comment: bool = False
