"""Catalog API endpoints"""

import logging
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.catalog import CatalogStatus
from app.models.user import User
from app.schemas.catalog import (
    CatalogPackage,
    CatalogVersionPublish,
    CatalogVersionResponse,
)
from app.schemas.effective_catalog import (
    CurrentCatalogVersionResponse,
    DiffResponse,
    EffectiveCatalogResponse,
)
from app.services.catalog_service import CatalogService
from app.services.effective_catalog_service import EffectiveCatalogService

logger = logging.getLogger(__name__)


router = APIRouter(prefix="/catalog", tags=["catalog"])


@router.get("/latest", response_model=CatalogPackage)
def get_latest_catalog(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Descarga el catálogo PUBLISHED más reciente para un proyecto.
    
    Usado por la app móvil para obtener el catálogo completo.
    """
    service = CatalogService(db)
    catalog = service.get_latest_published(project_id)
    return catalog


@router.get("/check-updates")
def check_catalog_updates(
    project_id: str = Query(..., description="Project ID"),
    # Bug fix: current_hash es Optional — en el primer sync la app no tiene hash.
    # Con Query(...) el backend devolvía 422 antes de verificar el token,
    # rompiendo silenciosamente el primer sync.
    # Si es None → siempre retorna update_available=True (fuerza descarga inicial).
    current_hash: Optional[str] = Query(None, description="Current catalog hash"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Verifica si hay actualizaciones disponibles del catálogo.

    Compara el hash local con el hash del catálogo publicado más reciente.
    Si current_hash es None (primer sync), siempre retorna update_available=True.
    """
    service = CatalogService(db)
    result = service.check_updates(project_id, current_hash)
    return result


@router.get("/versions", response_model=list[CatalogVersionResponse])
def list_catalog_versions(
    project_id: str = Query(..., description="Project ID"),
    status: Optional[CatalogStatus] = Query(None, description="Filter by status"),
    limit: int = Query(20, ge=1, le=100),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Lista todas las versiones de catálogo para un proyecto.
    
    Útil para el admin desktop para ver historial de versiones.
    """
    service = CatalogService(db)
    versions = service.list_versions(project_id, status, limit)
    return versions


@router.get("/versions/{version_id}", response_model=CatalogPackage)
def get_catalog_version(
    version_id: UUID,
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Obtiene una versión específica de catálogo por ID.
    
    Puede devolver DRAFT, PUBLISHED, o DEPRECATED.
    """
    service = CatalogService(db)
    version = service.get_version_by_id(version_id)
    
    if not version:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Catalog version {version_id} not found",
        )
    
    return service._serialize_catalog(version)


@router.post("/versions/{version_id}/publish", response_model=CatalogVersionResponse)
def publish_catalog_version(
    version_id: UUID,
    publish_data: Optional[CatalogVersionPublish] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Publica un catálogo DRAFT.
    
    Requiere permiso RBAC de publicación de catálogo.
    
    Acciones:
    - Valida el catálogo
    - Depreca la versión anterior
    - Genera hash SHA256
    - Marca como PUBLISHED
    """
    service = CatalogService(db)
    
    # Actualizar notas si se proporcionaron
    if publish_data and publish_data.notes:
        version = service.get_version_by_id(version_id)
        if version:
            version.notes = publish_data.notes
            db.commit()
    
    published_version = service.publish_version(version_id, current_user.id)
    return published_version


@router.get("/effective", response_model=EffectiveCatalogResponse)
def get_effective_catalog(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Returns the effective catalog for a project (with overrides applied).

    Responses:
    - 200: catalog resolved successfully
    - 404: no published catalog version configured (app shows "Reintentar")
    - 503: DB error / migrations pending (contact admin)
    """
    service = EffectiveCatalogService(db)
    try:
        result = service.get_effective_catalog(project_id=project_id, version_id=version_id)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "Unexpected error in GET /catalog/effective "
            "(user=%s, project_id=%s, version_id=%s): %s",
            current_user.email,
            project_id,
            version_id or "(auto)",
            exc,
            exc_info=True,
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Catalog service unavailable. Contact your administrator.",
        )
    logger.info(
        "Effective catalog resolved: project_id=%s version_id=%s user=%s "
        "activities=%d subcategories=%d",
        project_id,
        result["meta"]["version_id"],
        current_user.email,
        len(result.get("activities", [])),
        len(result.get("subcategories", [])),
    )
    return result


@router.get("/version/current", response_model=CurrentCatalogVersionResponse)
def get_current_catalog_version(
    project_id: Optional[str] = Query(None, description="Optional project id"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Devuelve el ID de la versión de catálogo marcada como is_current=true.

    Respuestas:
    - 200: versión encontrada
    - 404: no hay ninguna versión publicada (app muestra "Reintentar")
    - 503: fallo de base de datos (tabla inexistente / migraciones pendientes)
    """
    service = EffectiveCatalogService(db)
    try:
        version_id = service.resolve_current_version_id()
    except HTTPException:
        # Re-lanza el 404 (sin catálogo) o 503 (DB error) tal cual.
        # Nunca debe convertirse en 500.
        raise
    except Exception as exc:
        logger.error(
            "Unexpected error in GET /catalog/version/current (user=%s): %s",
            current_user.email,
            exc,
            exc_info=True,
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Catalog service unavailable. Contact your administrator.",
        )
    logger.info(
        "Catalog version resolved: version_id=%s user=%s",
        version_id,
        current_user.email,
    )
    return {"version_id": version_id, "generated_at": datetime.now(timezone.utc)}


@router.get("/diff", response_model=DiffResponse)
def get_catalog_diff(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    from_version_id: str = Query(..., description="Source catalog version"),
    to_version_id: Optional[str] = Query(None, description="Target catalog version"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = EffectiveCatalogService(db)
    resolved_to_version = to_version_id
    if not resolved_to_version:
        try:
            resolved_to_version = service.resolve_current_version_id()
        except HTTPException:
            raise
    return service.diff_effective_catalog(
        project_id=project_id,
        from_version_id=from_version_id,
        to_version_id=resolved_to_version,
    )
