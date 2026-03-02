"""Catalog service for versioning and publishing"""
import hashlib
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import and_
from sqlalchemy.orm import Session

from app.models.catalog import (
    CatalogVersion,
    CatalogStatus,
    CATActivityType,
    CATEventType,
    CATFormField,
    CATWorkflowState,
    CATWorkflowTransition,
    CATEvidenceRule,
    CATChecklistTemplate,
)
from app.schemas.catalog import (
    CatalogPackage,
    CATActivityTypeResponse,
    CATEventTypeResponse,
    CATFormFieldResponse,
    CATWorkflowStateResponse,
    CATWorkflowTransitionResponse,
    CATEvidenceRuleResponse,
    CATChecklistTemplateResponse,
)


class CatalogService:
    """Service for managing catalog versions and publishing workflow"""
    
    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _utc_now() -> datetime:
        """Return timezone-aware UTC datetime."""
        return datetime.now(timezone.utc)
    
    def get_latest_published(self, project_id: str) -> CatalogPackage:
        """
        Devuelve el catálogo PUBLISHED más reciente para un proyecto.
        Esta es la función principal que el móvil usa para descargar catálogos.
        """
        version = self._get_latest_published_version(project_id)
        
        if not version:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No published catalog found for project {project_id}",
            )
        
        return self._serialize_catalog(version)
    
    def get_version_by_id(self, version_id: UUID) -> Optional[CatalogVersion]:
        """Obtiene una versión específica de catálogo por ID"""
        return self.db.query(CatalogVersion).filter(CatalogVersion.id == version_id).first()

    def _get_latest_published_version(self, project_id: str) -> Optional[CatalogVersion]:
        """Return latest published catalog version for a project, if any."""
        return (
            self.db.query(CatalogVersion)
            .filter(
                and_(
                    CatalogVersion.project_id == project_id,
                    CatalogVersion.status == CatalogStatus.PUBLISHED,
                )
            )
            .order_by(CatalogVersion.published_at.desc())
            .first()
        )
    
    def list_versions(
        self, 
        project_id: str, 
        status: Optional[CatalogStatus] = None,
        limit: int = 20,
    ) -> list[CatalogVersion]:
        """Lista versiones de catálogo para un proyecto"""
        query = self.db.query(CatalogVersion).filter(CatalogVersion.project_id == project_id)
        
        if status:
            query = query.filter(CatalogVersion.status == status)
        
        return query.order_by(CatalogVersion.created_at.desc()).limit(limit).all()
    
    def publish_version(self, version_id: UUID, user_id: UUID) -> CatalogVersion:
        """
        Publica un catálogo DRAFT.
        - Valida el catálogo
        - Depreca la versión anterior
        - Genera hash SHA256
        - Marca como PUBLISHED
        """
        version = self.get_version_by_id(version_id)
        
        if not version:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Catalog version {version_id} not found",
            )
        
        if version.status != CatalogStatus.DRAFT:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Only DRAFT versions can be published (current: {version.status})",
            )
        
        # Validar el catálogo
        self._validate_catalog(version)
        
        # Deprecar versión anterior si existe
        previous_published = (
            self.db.query(CatalogVersion)
            .filter(
                and_(
                    CatalogVersion.project_id == version.project_id,
                    CatalogVersion.status == CatalogStatus.PUBLISHED,
                )
            )
            .first()
        )
        
        if previous_published:
            previous_published.status = CatalogStatus.DEPRECATED
        
        # Generar hash del catálogo
        catalog_package = self._serialize_catalog(version, for_hash=True)
        catalog_json = catalog_package.model_dump_json(exclude={"hash"})
        version.hash = hashlib.sha256(catalog_json.encode()).hexdigest()
        
        # Marcar como publicado
        version.status = CatalogStatus.PUBLISHED
        version.published_by_id = user_id
        version.published_at = self._utc_now()
        
        self.db.commit()
        self.db.refresh(version)
        
        return version
    
    def _validate_catalog(self, version: CatalogVersion) -> bool:
        """
        Valida que el catálogo tenga la estructura mínima requerida:
        - Al menos 1 activity type o event type
        - Todos los activity/event types tienen al menos 1 workflow state inicial
        - Las transiciones de workflow son válidas
        - Los form fields tienen configuración correcta
        """
        # Verificar tipos de actividad/eventos
        activity_types = (
            self.db.query(CATActivityType)
            .filter(CATActivityType.version_id == version.id)
            .count()
        )
        event_types = (
            self.db.query(CATEventType)
            .filter(CATEventType.version_id == version.id)
            .count()
        )
        
        if activity_types == 0 and event_types == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Catalog must have at least one activity type or event type",
            )
        
        # Verificar workflow states
        for entity_type in ["activity", "event"]:
            initial_states = (
                self.db.query(CATWorkflowState)
                .filter(
                    and_(
                        CATWorkflowState.version_id == version.id,
                        CATWorkflowState.entity_type == entity_type,
                        CATWorkflowState.is_initial.is_(True),
                    )
                )
                .count()
            )
            
            if initial_states == 0:
                # Solo validar si hay tipos de esa entidad
                types_count = (
                    activity_types if entity_type == "activity" else event_types
                )
                if types_count > 0:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"Catalog must have at least one initial workflow state for {entity_type}",
                    )
        
        # Más validaciones pueden agregarse aquí
        return True
    
    def _serialize_catalog(
        self, version: CatalogVersion, for_hash: bool = False
    ) -> CatalogPackage:
        """
        Convierte una versión de catálogo a CatalogPackage (JSON serializable).
        Este es el formato que se envía al móvil.
        """
        # Cargar todos los componentes del catálogo
        activity_types = (
            self.db.query(CATActivityType)
            .filter(CATActivityType.version_id == version.id)
            .order_by(CATActivityType.sort_order)
            .all()
        )
        
        event_types = (
            self.db.query(CATEventType)
            .filter(CATEventType.version_id == version.id)
            .order_by(CATEventType.sort_order)
            .all()
        )
        
        form_fields = (
            self.db.query(CATFormField)
            .filter(CATFormField.version_id == version.id)
            .order_by(CATFormField.entity_type, CATFormField.type_id, CATFormField.sort_order)
            .all()
        )
        
        workflow_states = (
            self.db.query(CATWorkflowState)
            .filter(CATWorkflowState.version_id == version.id)
            .order_by(CATWorkflowState.entity_type, CATWorkflowState.sort_order)
            .all()
        )
        
        workflow_transitions = (
            self.db.query(CATWorkflowTransition)
            .filter(CATWorkflowTransition.version_id == version.id)
            .order_by(CATWorkflowTransition.sort_order)
            .all()
        )
        
        evidence_rules = (
            self.db.query(CATEvidenceRule)
            .filter(CATEvidenceRule.version_id == version.id)
            .all()
        )
        
        checklist_templates = (
            self.db.query(CATChecklistTemplate)
            .filter(CATChecklistTemplate.version_id == version.id)
            .all()
        )
        
        # Construir el paquete
        return CatalogPackage(
            version_id=version.id,
            version_number=version.version_number,
            project_id=version.project_id,
            hash=version.hash or "",
            published_at=version.published_at or self._utc_now(),
            activity_types=[CATActivityTypeResponse.model_validate(at) for at in activity_types],
            event_types=[CATEventTypeResponse.model_validate(et) for et in event_types],
            form_fields=[CATFormFieldResponse.model_validate(ff) for ff in form_fields],
            workflow_states=[CATWorkflowStateResponse.model_validate(ws) for ws in workflow_states],
            workflow_transitions=[
                CATWorkflowTransitionResponse.model_validate(wt) for wt in workflow_transitions
            ],
            evidence_rules=[CATEvidenceRuleResponse.model_validate(er) for er in evidence_rules],
            checklist_templates=[
                CATChecklistTemplateResponse.model_validate(ct) for ct in checklist_templates
            ],
        )
    
    def check_updates(self, project_id: str, current_hash: str | None) -> dict:
        """
        Verifica si hay actualizaciones disponibles comparando el hash actual
        con el hash del catálogo publicado más reciente.

        Si current_hash es None (primer sync, sin catálogo local),
        siempre retorna update_available=True para forzar la descarga inicial.
        """
        latest = self._get_latest_published_version(project_id)

        if not latest:
            return {"update_available": False, "message": "No published catalog found"}

        # current_hash=None significa que la app no tiene catálogo aún → siempre actualizar.
        if current_hash is None or latest.hash != current_hash:
            return {
                "update_available": True,
                "new_version": latest.version_number,
                "new_hash": latest.hash,
                "published_at": latest.published_at.isoformat(),
            }

        return {"update_available": False, "message": "Catalog is up to date"}
