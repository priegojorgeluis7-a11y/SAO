from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.catalog import CatalogStatus, EntityType, WidgetType


ORM_CONFIG = ConfigDict(from_attributes=True)


class CatalogVersionBase(BaseModel):
    """Base schema for CatalogVersion"""
    project_id: str
    version_number: str
    notes: Optional[str] = None


class CatalogVersionCreate(CatalogVersionBase):
    """Schema for creating a catalog version (DRAFT)"""
    pass


class CatalogVersionPublish(BaseModel):
    """Schema for publishing a catalog"""
    notes: Optional[str] = None


class CatalogVersionResponse(CatalogVersionBase):
    """Schema for catalog version response"""
    id: UUID
    status: CatalogStatus
    hash: Optional[str] = None
    published_by_id: Optional[UUID] = None
    published_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime
    
    model_config = ORM_CONFIG


# =================== Activity Types ===================

class CATActivityTypeBase(BaseModel):
    """Base schema for Activity Type"""
    code: str = Field(..., max_length=50)
    name: str = Field(..., max_length=255)
    description: Optional[str] = None
    icon: Optional[str] = Field(None, max_length=50)
    color: Optional[str] = Field(None, pattern=r"^#[0-9A-Fa-f]{6}$")
    sort_order: int = 0
    is_active: bool = True
    requires_approval: bool = False
    max_duration_minutes: Optional[int] = None
    notification_email: Optional[str] = None


class CATActivityTypeResponse(CATActivityTypeBase):
    """Schema for activity type response"""
    id: UUID
    version_id: UUID
    created_at: datetime
    updated_at: datetime
    
    model_config = ORM_CONFIG


# =================== Event Types ===================

class CATEventTypeBase(BaseModel):
    """Base schema for Event Type"""
    code: str = Field(..., max_length=50)
    name: str = Field(..., max_length=255)
    description: Optional[str] = None
    icon: Optional[str] = Field(None, max_length=50)
    color: Optional[str] = Field(None, pattern=r"^#[0-9A-Fa-f]{6}$")
    priority: Optional[str] = None
    sort_order: int = 0
    is_active: bool = True
    auto_create_activity: bool = False
    requires_immediate_response: bool = False


class CATEventTypeResponse(CATEventTypeBase):
    """Schema for event type response"""
    id: UUID
    version_id: UUID
    created_at: datetime
    updated_at: datetime
    
    model_config = ORM_CONFIG


# =================== Form Fields ===================

class CATFormFieldBase(BaseModel):
    """Base schema for Form Field"""
    entity_type: EntityType
    type_id: UUID
    key: str = Field(..., max_length=100)
    label: str = Field(..., max_length=255)
    help_text: Optional[str] = None
    widget: WidgetType
    sort_order: int = 0
    required: bool = False
    validation_regex: Optional[str] = Field(None, max_length=500)
    validation_message: Optional[str] = Field(None, max_length=255)
    min_value: Optional[int] = None
    max_value: Optional[int] = None
    min_length: Optional[int] = None
    max_length: Optional[int] = None
    options: Optional[List[Dict[str, Any]]] = None
    visible_when: Optional[Dict[str, Any]] = None
    required_when: Optional[Dict[str, Any]] = None
    default_value: Optional[str] = None


class CATFormFieldResponse(CATFormFieldBase):
    """Schema for form field response"""
    id: UUID
    version_id: UUID
    created_at: datetime
    updated_at: datetime
    
    model_config = ORM_CONFIG


# =================== Workflow States ===================

class CATWorkflowStateBase(BaseModel):
    """Base schema for Workflow State"""
    entity_type: EntityType
    code: str = Field(..., max_length=50)
    label: str = Field(..., max_length=255)
    color: Optional[str] = Field(None, pattern=r"^#[0-9A-Fa-f]{6}$")
    is_initial: bool = False
    is_final: bool = False
    sort_order: int = 0


class CATWorkflowStateResponse(CATWorkflowStateBase):
    """Schema for workflow state response"""
    id: UUID
    version_id: UUID
    created_at: datetime
    updated_at: datetime
    
    model_config = ORM_CONFIG


# =================== Workflow Transitions ===================

class CATWorkflowTransitionBase(BaseModel):
    """Base schema for Workflow Transition"""
    from_state_id: UUID
    to_state_id: UUID
    label: str = Field(..., max_length=255)
    description: Optional[str] = None
    allowed_roles: Optional[List[int]] = None
    required_permissions: Optional[List[str]] = None
    required_fields: Optional[List[str]] = None
    confirm_message: Optional[str] = Field(None, max_length=500)
    sort_order: int = 0


class CATWorkflowTransitionResponse(CATWorkflowTransitionBase):
    """Schema for workflow transition response"""
    id: UUID
    version_id: UUID
    created_at: datetime
    updated_at: datetime
    
    model_config = ORM_CONFIG


# =================== Evidence Rules ===================

class CATEvidenceRuleBase(BaseModel):
    """Base schema for Evidence Rule"""
    entity_type: EntityType
    type_id: UUID
    min_photos: int = 0
    max_photos: Optional[int] = None
    requires_gps: bool = True
    requires_signature: bool = False
    allowed_file_types: Optional[List[str]] = None
    max_file_size_mb: int = 10
    description: Optional[str] = None


class CATEvidenceRuleResponse(CATEvidenceRuleBase):
    """Schema for evidence rule response"""
    id: UUID
    version_id: UUID
    created_at: datetime
    updated_at: datetime
    
    model_config = ORM_CONFIG


# =================== Checklist Templates ===================

class CATChecklistTemplateBase(BaseModel):
    """Base schema for Checklist Template"""
    activity_type_id: UUID
    name: str = Field(..., max_length=255)
    description: Optional[str] = None
    items: List[Dict[str, Any]] = Field(default_factory=list)


class CATChecklistTemplateResponse(CATChecklistTemplateBase):
    """Schema for checklist template response"""
    id: UUID
    version_id: UUID
    created_at: datetime
    updated_at: datetime
    
    model_config = ORM_CONFIG


# =================== Complete Catalog Package ===================

class CatalogPackage(BaseModel):
    """Complete catalog package for mobile download"""
    version_id: UUID
    version_number: str
    project_id: str
    hash: str
    published_at: datetime
    
    activity_types: List[CATActivityTypeResponse]
    event_types: List[CATEventTypeResponse]
    form_fields: List[CATFormFieldResponse]
    workflow_states: List[CATWorkflowStateResponse]
    workflow_transitions: List[CATWorkflowTransitionResponse]
    evidence_rules: List[CATEvidenceRuleResponse]
    checklist_templates: List[CATChecklistTemplateResponse]
    
    model_config = ORM_CONFIG
