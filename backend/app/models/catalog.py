from sqlalchemy import Column, String, Text, Integer, Boolean, ForeignKey, UniqueConstraint, Index, DateTime, JSON, Enum as SQLEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid
import enum
from app.models.base import BaseModel
from datetime import datetime


class CatalogStatus(str, enum.Enum):
    """Estados del ciclo de vida de un catálogo"""
    DRAFT = "draft"
    PUBLISHED = "published"
    DEPRECATED = "deprecated"


class EntityType(str, enum.Enum):
    """Tipos de entidades para formularios y workflows"""
    ACTIVITY = "activity"
    EVENT = "event"


class WidgetType(str, enum.Enum):
    """Tipos de widgets para formularios dinámicos"""
    TEXT = "text"
    NUMBER = "number"
    DATE = "date"
    TIME = "time"
    DATETIME = "datetime"
    TEXTAREA = "textarea"
    SELECT = "select"
    MULTISELECT = "multiselect"
    RADIO = "radio"
    CHECKBOX = "checkbox"
    GPS = "gps"
    SIGNATURE = "signature"
    FILE = "file"
    PHOTO = "photo"


def _enum_values(enum_cls):
    return [item.value for item in enum_cls]


class CatalogVersion(BaseModel):
    """Versión de catálogo con control de estado Draft→Published→Deprecated"""
    __tablename__ = "catalog_versions"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(String(10), ForeignKey("projects.id"), nullable=False)
    version_number = Column(String(20), nullable=False)  # '1.0.0'
    status = Column(
        SQLEnum(CatalogStatus, values_callable=_enum_values),
        default=CatalogStatus.DRAFT,
        nullable=False,
    )
    hash = Column(String(64), nullable=True)  # SHA256 del paquete completo
    notes = Column(Text, nullable=True)
    
    # Audit: quien publicó y cuando
    published_by_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    published_at = Column(DateTime(timezone=True), nullable=True)
    
    # Relationships
    project = relationship("Project", back_populates="catalog_versions")
    published_by = relationship("User", foreign_keys=[published_by_id])
    
    activity_types = relationship("CATActivityType", back_populates="version", cascade="all, delete-orphan")
    event_types = relationship("CATEventType", back_populates="version", cascade="all, delete-orphan")
    form_fields = relationship("CATFormField", back_populates="version", cascade="all, delete-orphan")
    workflow_states = relationship("CATWorkflowState", back_populates="version", cascade="all, delete-orphan")
    workflow_transitions = relationship("CATWorkflowTransition", back_populates="version", cascade="all, delete-orphan")
    evidence_rules = relationship("CATEvidenceRule", back_populates="version", cascade="all, delete-orphan")
    checklist_templates = relationship("CATChecklistTemplate", back_populates="version", cascade="all, delete-orphan")
    
    __table_args__ = (
        UniqueConstraint('project_id', 'version_number', name='uq_project_version'),
        Index('idx_catalog_project_status', 'project_id', 'status'),
    )
    
    def __repr__(self):
        return f"<CatalogVersion(project={self.project_id}, version={self.version_number}, status={self.status})>"


class CATActivityType(BaseModel):
    """Catálogo de tipos de actividades"""
    __tablename__ = "cat_activity_types"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    version_id = Column(UUID(as_uuid=True), ForeignKey("catalog_versions.id"), nullable=False)
    code = Column(String(50), nullable=False)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    icon = Column(String(50), nullable=True)  # Material Icon name
    color = Column(String(7), nullable=True)  # Hex color #RRGGBB
    sort_order = Column(Integer, default=0, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    
    # Config adicional
    requires_approval = Column(Boolean, default=False, nullable=False)
    max_duration_minutes = Column(Integer, nullable=True)
    notification_email = Column(String(255), nullable=True)
    
    # Relationships
    version = relationship("CatalogVersion", back_populates="activity_types")
    # Note: form_fields and evidence_rules are polymorphic (entity_type + type_id)
    # They cannot be directly joined. Use version.form_fields with filtering instead.
    
    __table_args__ = (
        UniqueConstraint('version_id', 'code', name='uq_activity_type_code'),
        Index('idx_activity_type_version', 'version_id'),
    )
    
    def __repr__(self):
        return f"<CATActivityType(code={self.code}, name={self.name})>"


class CATEventType(BaseModel):
    """Catálogo de tipos de eventos"""
    __tablename__ = "cat_event_types"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    version_id = Column(UUID(as_uuid=True), ForeignKey("catalog_versions.id"), nullable=False)
    code = Column(String(50), nullable=False)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    icon = Column(String(50), nullable=True)
    color = Column(String(7), nullable=True)
    priority = Column(String(20), nullable=True)  # 'low', 'medium', 'high', 'critical'
    sort_order = Column(Integer, default=0, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    
    # Config
    auto_create_activity = Column(Boolean, default=False, nullable=False)
    requires_immediate_response = Column(Boolean, default=False, nullable=False)
    
    # Relationships
    version = relationship("CatalogVersion", back_populates="event_types")
    # Note: form_fields and evidence_rules are polymorphic (entity_type + type_id)
    # They cannot be directly joined. Use version.form_fields with filtering instead.
    
    __table_args__ = (
        UniqueConstraint('version_id', 'code', name='uq_event_type_code'),
        Index('idx_event_type_version', 'version_id'),
    )
    
    def __repr__(self):
        return f"<CATEventType(code={self.code}, name={self.name})>"


class CATFormField(BaseModel):
    """Catálogo de campos de formulario dinámicos"""
    __tablename__ = "cat_form_fields"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    version_id = Column(UUID(as_uuid=True), ForeignKey("catalog_versions.id"), nullable=False)
    
    # A qué entidad y tipo pertenece
    entity_type = Column(SQLEnum(EntityType, values_callable=_enum_values), nullable=False)  # 'activity' o 'event'
    type_id = Column(UUID(as_uuid=True), nullable=False)  # FK a CATActivityType o CATEventType
    
    # Configuración del campo
    key = Column(String(100), nullable=False)  # nombre de la variable
    label = Column(String(255), nullable=False)
    help_text = Column(Text, nullable=True)
    widget = Column(SQLEnum(WidgetType, values_callable=_enum_values), nullable=False)
    sort_order = Column(Integer, default=0, nullable=False)
    
    # Validación
    required = Column(Boolean, default=False, nullable=False)
    validation_regex = Column(String(500), nullable=True)
    validation_message = Column(String(255), nullable=True)
    min_value = Column(Integer, nullable=True)
    max_value = Column(Integer, nullable=True)
    min_length = Column(Integer, nullable=True)
    max_length = Column(Integer, nullable=True)
    
    # Opciones para select/radio/checkbox
    options = Column(JSON, nullable=True)  # [{"value": "A", "label": "Opción A"}]
    
    # Condicionalidad
    visible_when = Column(JSON, nullable=True)  # {"field": "tipo", "op": "==", "value": "X"}
    required_when = Column(JSON, nullable=True)
    
    # Valores por defecto
    default_value = Column(String(500), nullable=True)
    
    # Relationships
    version = relationship("CatalogVersion", back_populates="form_fields")
    
    __table_args__ = (
        UniqueConstraint('version_id', 'entity_type', 'type_id', 'key', name='uq_form_field_key'),
        Index('idx_form_field_version_entity', 'version_id', 'entity_type', 'type_id'),
    )
    
    def __repr__(self):
        return f"<CATFormField(entity={self.entity_type}, key={self.key}, widget={self.widget})>"


class CATWorkflowState(BaseModel):
    """Catálogo de estados de workflow"""
    __tablename__ = "cat_workflow_states"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    version_id = Column(UUID(as_uuid=True), ForeignKey("catalog_versions.id"), nullable=False)
    entity_type = Column(SQLEnum(EntityType, values_callable=_enum_values), nullable=False)
    
    code = Column(String(50), nullable=False)
    label = Column(String(255), nullable=False)
    color = Column(String(7), nullable=True)  # Hex color
    is_initial = Column(Boolean, default=False, nullable=False)
    is_final = Column(Boolean, default=False, nullable=False)
    sort_order = Column(Integer, default=0, nullable=False)
    
    # Relationships
    version = relationship("CatalogVersion", back_populates="workflow_states")
    transitions_from = relationship("CATWorkflowTransition", foreign_keys="CATWorkflowTransition.from_state_id", back_populates="from_state")
    transitions_to = relationship("CATWorkflowTransition", foreign_keys="CATWorkflowTransition.to_state_id", back_populates="to_state")
    
    __table_args__ = (
        UniqueConstraint('version_id', 'entity_type', 'code', name='uq_workflow_state_code'),
        Index('idx_workflow_state_version_entity', 'version_id', 'entity_type'),
    )
    
    def __repr__(self):
        return f"<CATWorkflowState(entity={self.entity_type}, code={self.code})>"


class CATWorkflowTransition(BaseModel):
    """Catálogo de transiciones de workflow"""
    __tablename__ = "cat_workflow_transitions"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    version_id = Column(UUID(as_uuid=True), ForeignKey("catalog_versions.id"), nullable=False)
    
    from_state_id = Column(UUID(as_uuid=True), ForeignKey("cat_workflow_states.id"), nullable=False)
    to_state_id = Column(UUID(as_uuid=True), ForeignKey("cat_workflow_states.id"), nullable=False)
    
    label = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    allowed_roles = Column(JSON, nullable=True)  # [1, 2, 4] (IDs de roles)
    required_permissions = Column(JSON, nullable=True)  # ["activity.approve"]
    required_fields = Column(JSON, nullable=True)  # ["hora_fin", "observaciones"]
    confirm_message = Column(String(500), nullable=True)
    
    sort_order = Column(Integer, default=0, nullable=False)
    
    # Relationships
    version = relationship("CatalogVersion", back_populates="workflow_transitions")
    from_state = relationship("CATWorkflowState", foreign_keys=[from_state_id], back_populates="transitions_from")
    to_state = relationship("CATWorkflowState", foreign_keys=[to_state_id], back_populates="transitions_to")
    
    __table_args__ = (
        Index('idx_workflow_transition_version', 'version_id'),
        Index('idx_workflow_transition_states', 'from_state_id', 'to_state_id'),
    )
    
    def __repr__(self):
        return f"<CATWorkflowTransition(label={self.label})>"


class CATEvidenceRule(BaseModel):
    """Reglas de evidencias requeridas por tipo de actividad/evento"""
    __tablename__ = "cat_evidence_rules"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    version_id = Column(UUID(as_uuid=True), ForeignKey("catalog_versions.id"), nullable=False)
    
    entity_type = Column(SQLEnum(EntityType, values_callable=_enum_values), nullable=False)
    type_id = Column(UUID(as_uuid=True), nullable=False)  # FK a CATActivityType o CATEventType
    
    # Reglas
    min_photos = Column(Integer, default=0, nullable=False)
    max_photos = Column(Integer, nullable=True)
    requires_gps = Column(Boolean, default=True, nullable=False)
    requires_signature = Column(Boolean, default=False, nullable=False)
    allowed_file_types = Column(JSON, nullable=True)  # ["image/jpeg", "application/pdf"]
    max_file_size_mb = Column(Integer, default=10, nullable=False)
    
    description = Column(Text, nullable=True)
    
    # Relationships
    version = relationship("CatalogVersion", back_populates="evidence_rules")
    
    __table_args__ = (
        UniqueConstraint('version_id', 'entity_type', 'type_id', name='uq_evidence_rule_type'),
        Index('idx_evidence_rule_version', 'version_id'),
    )
    
    def __repr__(self):
        return f"<CATEvidenceRule(entity={self.entity_type}, min_photos={self.min_photos})>"


class CATChecklistTemplate(BaseModel):
    """Plantillas de checklist para tipos de actividad"""
    __tablename__ = "cat_checklist_templates"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    version_id = Column(UUID(as_uuid=True), ForeignKey("catalog_versions.id"), nullable=False)
    activity_type_id = Column(UUID(as_uuid=True), ForeignKey("cat_activity_types.id"), nullable=False)
    
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    items = Column(JSON, nullable=False)  # [{"order": 1, "text": "Verificar...", "critical": true}]
    
    # Relationships
    version = relationship("CatalogVersion", back_populates="checklist_templates")
    activity_type = relationship("CATActivityType", foreign_keys=[activity_type_id])
    
    __table_args__ = (
        Index('idx_checklist_version', 'version_id'),
        Index('idx_checklist_activity', 'activity_type_id'),
    )
    
    def __repr__(self):
        return f"<CATChecklistTemplate(name={self.name})>"
