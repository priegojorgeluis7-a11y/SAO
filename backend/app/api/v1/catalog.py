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
    CatalogVersionDigest,
    CatalogPackage,
    CatalogVersionPublish,
    CatalogVersionResponse,
)
from app.schemas.effective_catalog import (
    CurrentCatalogVersionResponse,
    DiffResponse,
    EffectiveCatalogResponse,
)
from app.schemas.catalog_editor import (
    ActivityCreateRequest,
    ActivityUpdateRequest,
    AttendeeCreateRequest,
    AttendeeUpdateRequest,
    CatalogEditorResponse,
    PurposeCreateRequest,
    PurposeUpdateRequest,
    RelActivityTopicUpsertRequest,
    ReorderEntityRequest,
    ResultCreateRequest,
    ResultUpdateRequest,
    SubcategoryCreateRequest,
    SubcategoryUpdateRequest,
    TopicCreateRequest,
    TopicUpdateRequest,
)
from app.schemas.catalog_bundle import (
    CatalogOp,
    CatalogPublishResponse,
    CatalogRollbackRequest,
    CatalogRollbackResponse,
    CatalogValidationResponse,
    ProjectOpsRequest,
)
from app.services.catalog_bundle_service import CatalogBundleService
from app.services.catalog_editor_service import CatalogEditorService
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


@router.get("/versions", response_model=list[CatalogVersionResponse] | dict[str, CatalogVersionDigest])
def list_catalog_versions(
    project_id: Optional[str] = Query(None, description="Project ID"),
    project_ids: Optional[str] = Query(
        None,
        description="Comma-separated project IDs for lightweight latest-version check",
    ),
    status_filter: Optional[CatalogStatus] = Query(None, alias="status", description="Filter by status"),
    limit: int = Query(20, ge=1, le=100),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Lista todas las versiones de catálogo para un proyecto o retorna digest ligero multiproyecto.
    
    Útil para el admin desktop para ver historial de versiones.
    """
    service = CatalogService(db)
    if project_ids:
        requested_project_ids = [item.strip() for item in project_ids.split(",") if item.strip()]
        if not requested_project_ids:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="project_ids must include at least one project",
            )

        digests = service.get_latest_published_digests(requested_project_ids)
        return {
            pid: CatalogVersionDigest(
                version_id=version.id if version else None,
                version_number=version.version_number if version else None,
                hash=version.hash if version else None,
                published_at=version.published_at if version else None,
            )
            for pid, version in digests.items()
        }

    if not project_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either project_id or project_ids must be provided",
        )

    versions = service.list_versions(project_id, status_filter, limit)
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
        version_id = service.resolve_current_version_id(project_id=project_id)
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
            resolved_to_version = service.resolve_current_version_id(project_id=project_id)
        except HTTPException:
            raise
    return service.diff_effective_catalog(
        project_id=project_id,
        from_version_id=from_version_id,
        to_version_id=resolved_to_version,
    )


# ── Bundle / project-ops / validate / publish / rollback ──────────────────────

@router.get("/bundle")
def get_catalog_bundle(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    include_editor: bool = Query(False, description="Include editor layer (admin only)"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Returns the full sao.catalog.bundle.v1 for a project.

    - Wizard (mobile/field): call without include_editor — returns only effective.
    - Desktop admin: call with include_editor=true — returns effective + editor layers.
    """
    return CatalogBundleService(db).get_bundle(project_id=project_id, include_editor=include_editor)


@router.get("/workflow")
def get_catalog_workflow(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Returns only the workflow machine from effective.rules.workflow."""
    bundle = CatalogBundleService(db).get_bundle(project_id=project_id, include_editor=False)
    effective = bundle.get("effective") if isinstance(bundle, dict) else {}
    rules = effective.get("rules") if isinstance(effective, dict) else {}
    workflow = rules.get("workflow") if isinstance(rules, dict) else {}
    return workflow if isinstance(workflow, dict) else {}


@router.patch("/project-ops")
def apply_project_ops(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    body: ProjectOpsRequest = ...,
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Apply a batch of catalog ops (upsert/patch/deactivate/activate/rel_*/reorder/delete)
    and return the updated bundle with include_editor=true.
    """
    logger.info(
        "[project-ops] project_id=%s ops_count=%d ops=%s",
        project_id,
        len(body.ops),
        [{"op": o.op, "entity": o.entity, "id": o.id, "data_keys": list((o.data or {}).keys())} for o in body.ops],
    )
    svc_ed = CatalogEditorService(db)
    version_id = svc_ed._resolve_version_id(None, project_id=project_id)
    for op in body.ops:
        _dispatch_catalog_op(svc_ed, op, project_id, version_id)
    bundle = CatalogBundleService(db).get_bundle(project_id=project_id, include_editor=True)
    logger.info("[project-ops] done project_id=%s version=%s", project_id, bundle.get("meta", {}).get("versions"))
    return bundle


@router.post("/validate", response_model=CatalogValidationResponse)
def validate_catalog(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Validate FK integrity of the current catalog and return any issues."""
    return CatalogBundleService(db).validate(project_id=project_id)


@router.post("/publish", response_model=CatalogPublishResponse)
def publish_catalog(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Publish the current catalog state — creates a new version_id marked as is_current."""
    return CatalogBundleService(db).publish(project_id=project_id)


@router.post("/rollback", response_model=CatalogRollbackResponse)
def rollback_catalog(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    body: CatalogRollbackRequest = ...,
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Restore a previously published catalog version as the current one."""
    return CatalogBundleService(db).rollback(
        project_id=project_id,
        to_version=body.to_effective_version,
    )


def _dispatch_catalog_op(
    svc: CatalogEditorService,
    op: CatalogOp,
    project_id: str,
    version_id: str,
) -> None:
    """Dispatch a single catalog op to the appropriate editor service method."""
    logger.info("[op] %s entity=%s id=%s data=%s", op.op, op.entity, op.id, op.data)
    from app.schemas.catalog_editor import (
        ActivityCreateRequest,
        ActivityUpdateRequest,
        PurposeCreateRequest,
        PurposeUpdateRequest,
        SubcategoryCreateRequest,
        SubcategoryUpdateRequest,
        TopicCreateRequest,
        TopicUpdateRequest,
    )

    data = op.data or {}

    if op.op in ("upsert", "patch"):
        if op.entity == "activities":
            if svc._activity_exists(op.id, version_id):
                svc.upsert_entity_override(
                    project_id=project_id,
                    version_id=version_id,
                    entity_type="activity",
                    entity_id=op.id,
                    display_name=data.get("name"),
                    is_enabled=data.get("active"),
                )
                svc.db.commit()
            else:
                svc.create_activity(ActivityCreateRequest(id=op.id, **data), version_id)
        elif op.entity == "subcategories":
            if svc._subcategory_exists(op.id, version_id):
                svc.upsert_entity_override(
                    project_id=project_id,
                    version_id=version_id,
                    entity_type="subcategory",
                    entity_id=op.id,
                    display_name=data.get("name"),
                    is_enabled=data.get("active"),
                )
                svc.db.commit()
            else:
                svc.create_subcategory(SubcategoryCreateRequest(id=op.id, **data), version_id)
        elif op.entity == "purposes":
            exists = (
                svc.db.query(
                    __import__("app.models.catalog_effective", fromlist=["CatPurpose"]).CatPurpose
                )
                .filter_by(purpose_id=op.id, version_id=version_id)
                .first()
            )
            if exists:
                svc.upsert_entity_override(
                    project_id=project_id,
                    version_id=version_id,
                    entity_type="purpose",
                    entity_id=op.id,
                    display_name=data.get("name"),
                    is_enabled=data.get("active"),
                )
                svc.db.commit()
            else:
                svc.create_purpose(PurposeCreateRequest(id=op.id, **data), version_id)
        elif op.entity == "topics":
            if svc._topic_exists(op.id, version_id):
                svc.upsert_entity_override(
                    project_id=project_id,
                    version_id=version_id,
                    entity_type="topic",
                    entity_id=op.id,
                    display_name=data.get("name"),
                    is_enabled=data.get("active"),
                )
                svc.db.commit()
            else:
                svc.create_topic(TopicCreateRequest(id=op.id, **data), version_id)
        elif op.entity == "results":
            if svc._result_exists(op.id, version_id):
                svc.upsert_entity_override(
                    project_id=project_id,
                    version_id=version_id,
                    entity_type="result",
                    entity_id=op.id,
                    display_name=data.get("name"),
                    is_enabled=data.get("active"),
                )
                svc.db.commit()
            else:
                svc.create_result(
                    result_id=op.id,
                    category=(data.get("category") or "General"),
                    name=(data.get("name") or op.id),
                    description=data.get("description"),
                    version_id=version_id,
                )
        elif op.entity in ("assistants", "attendees"):
            if svc._attendee_exists(op.id, version_id):
                svc.upsert_entity_override(
                    project_id=project_id,
                    version_id=version_id,
                    entity_type="attendee",
                    entity_id=op.id,
                    display_name=data.get("name"),
                    is_enabled=data.get("active"),
                )
                svc.db.commit()
            else:
                svc.create_attendee(
                    attendee_id=op.id,
                    attendee_type=(data.get("type") or "General"),
                    name=(data.get("name") or op.id),
                    description=data.get("description"),
                    version_id=version_id,
                )
        elif op.entity == "activity_to_topics_suggested":
            activity_id = data.get("activity_id", "")
            topic_id = data.get("topic_id", "")
            if activity_id and topic_id and svc._rel_exists(activity_id, topic_id, version_id):
                svc.upsert_relation_override(
                    project_id=project_id,
                    version_id=version_id,
                    activity_id=activity_id,
                    topic_id=topic_id,
                    is_enabled=True,
                )
                svc.db.commit()
            else:
                svc.upsert_rel_activity_topic(
                    activity_id=activity_id,
                    topic_id=topic_id,
                    version_id=version_id,
                )

    elif op.op == "deactivate":
        if op.entity == "activities":
            svc.upsert_entity_override(
                project_id=project_id,
                version_id=version_id,
                entity_type="activity",
                entity_id=op.id,
                is_enabled=False,
            )
        elif op.entity == "subcategories":
            svc.upsert_entity_override(
                project_id=project_id,
                version_id=version_id,
                entity_type="subcategory",
                entity_id=op.id,
                is_enabled=False,
            )
        elif op.entity == "purposes":
            svc.upsert_entity_override(
                project_id=project_id,
                version_id=version_id,
                entity_type="purpose",
                entity_id=op.id,
                is_enabled=False,
            )
        elif op.entity == "topics":
            svc.upsert_entity_override(
                project_id=project_id,
                version_id=version_id,
                entity_type="topic",
                entity_id=op.id,
                is_enabled=False,
            )
        elif op.entity == "results":
            svc.upsert_entity_override(
                project_id=project_id,
                version_id=version_id,
                entity_type="result",
                entity_id=op.id,
                is_enabled=False,
            )
        elif op.entity in ("assistants", "attendees"):
            svc.upsert_entity_override(
                project_id=project_id,
                version_id=version_id,
                entity_type="attendee",
                entity_id=op.id,
                is_enabled=False,
            )
        svc.db.commit()

    elif op.op == "activate":
        if op.entity == "activities":
            svc.upsert_entity_override(
                project_id=project_id,
                version_id=version_id,
                entity_type="activity",
                entity_id=op.id,
                is_enabled=True,
            )
        elif op.entity == "subcategories":
            svc.upsert_entity_override(
                project_id=project_id,
                version_id=version_id,
                entity_type="subcategory",
                entity_id=op.id,
                is_enabled=True,
            )
        elif op.entity == "purposes":
            svc.upsert_entity_override(
                project_id=project_id,
                version_id=version_id,
                entity_type="purpose",
                entity_id=op.id,
                is_enabled=True,
            )
        elif op.entity == "topics":
            svc.upsert_entity_override(
                project_id=project_id,
                version_id=version_id,
                entity_type="topic",
                entity_id=op.id,
                is_enabled=True,
            )
        elif op.entity == "results":
            svc.upsert_entity_override(
                project_id=project_id,
                version_id=version_id,
                entity_type="result",
                entity_id=op.id,
                is_enabled=True,
            )
        elif op.entity in ("assistants", "attendees"):
            svc.upsert_entity_override(
                project_id=project_id,
                version_id=version_id,
                entity_type="attendee",
                entity_id=op.id,
                is_enabled=True,
            )
        svc.db.commit()

    elif op.op == "rel_upsert":
        svc.upsert_rel_activity_topic(
            activity_id=data.get("activity_id", ""),
            topic_id=data.get("topic_id", ""),
            version_id=version_id,
        )

    elif op.op == "rel_deactivate":
        svc.delete_rel_activity_topic(
            activity_id=data.get("activity_id", ""),
            topic_id=data.get("topic_id", ""),
            version_id=version_id,
        )

    elif op.op == "reorder":
        svc.reorder_entities(
            project_id=project_id,
            entity=op.entity,
            ids=data.get("ids", []),
            version_id=version_id,
        )

    elif op.op == "delete":
        # 'delete' is an alias for 'deactivate' sent by Desktop clients
        if op.entity == "activities":
            svc.upsert_entity_override(
                project_id=project_id,
                version_id=version_id,
                entity_type="activity",
                entity_id=op.id,
                is_enabled=False,
            )
        elif op.entity == "subcategories":
            svc.upsert_entity_override(
                project_id=project_id,
                version_id=version_id,
                entity_type="subcategory",
                entity_id=op.id,
                is_enabled=False,
            )
        elif op.entity == "purposes":
            svc.upsert_entity_override(
                project_id=project_id,
                version_id=version_id,
                entity_type="purpose",
                entity_id=op.id,
                is_enabled=False,
            )
        elif op.entity == "topics":
            svc.upsert_entity_override(
                project_id=project_id,
                version_id=version_id,
                entity_type="topic",
                entity_id=op.id,
                is_enabled=False,
            )
        elif op.entity == "results":
            svc.upsert_entity_override(
                project_id=project_id,
                version_id=version_id,
                entity_type="result",
                entity_id=op.id,
                is_enabled=False,
            )
        elif op.entity in ("assistants", "attendees"):
            svc.upsert_entity_override(
                project_id=project_id,
                version_id=version_id,
                entity_type="attendee",
                entity_id=op.id,
                is_enabled=False,
            )
        elif op.entity == "activity_to_topics_suggested":
            activity_id = data.get("activity_id", "")
            topic_id = data.get("topic_id", "")
            if not activity_id or not topic_id:
                parts = op.id.split("|")
                if len(parts) == 2:
                    activity_id, topic_id = parts
            if activity_id and topic_id and svc._rel_exists(activity_id, topic_id, version_id):
                svc.upsert_relation_override(
                    project_id=project_id,
                    version_id=version_id,
                    activity_id=activity_id,
                    topic_id=topic_id,
                    is_enabled=False,
                )
            else:
                svc.delete_rel_activity_topic(activity_id=activity_id, topic_id=topic_id, version_id=version_id)
        svc.db.commit()


@router.get("/editor", response_model=CatalogEditorResponse)
def get_catalog_editor(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    return service.get_editor_catalog(project_id=project_id, version_id=version_id)


@router.post("/editor/activities", status_code=status.HTTP_204_NO_CONTENT)
def create_activity_editor(
    payload: ActivityCreateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.create_activity(payload, version_id=resolved_version)
    return None


@router.patch("/editor/activities/{activity_id}", status_code=status.HTTP_204_NO_CONTENT)
def update_activity_editor(
    activity_id: str,
    payload: ActivityUpdateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.update_activity(activity_id, payload, version_id=resolved_version)
    return None


@router.delete("/editor/activities/{activity_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_activity_editor(
    activity_id: str,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.delete_activity(activity_id, version_id=resolved_version)
    return None


@router.post("/editor/subcategories", status_code=status.HTTP_204_NO_CONTENT)
def create_subcategory_editor(
    payload: SubcategoryCreateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.create_subcategory(payload, version_id=resolved_version)
    return None


@router.patch("/editor/subcategories/{subcategory_id}", status_code=status.HTTP_204_NO_CONTENT)
def update_subcategory_editor(
    subcategory_id: str,
    payload: SubcategoryUpdateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.update_subcategory(subcategory_id, payload, version_id=resolved_version)
    return None


@router.delete("/editor/subcategories/{subcategory_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_subcategory_editor(
    subcategory_id: str,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.delete_subcategory(subcategory_id, version_id=resolved_version)
    return None


@router.post("/editor/purposes", status_code=status.HTTP_204_NO_CONTENT)
def create_purpose_editor(
    payload: PurposeCreateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.create_purpose(payload, version_id=resolved_version)
    return None


@router.patch("/editor/purposes/{purpose_id}", status_code=status.HTTP_204_NO_CONTENT)
def update_purpose_editor(
    purpose_id: str,
    payload: PurposeUpdateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.update_purpose(purpose_id, payload, version_id=resolved_version)
    return None


@router.delete("/editor/purposes/{purpose_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_purpose_editor(
    purpose_id: str,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.delete_purpose(purpose_id, version_id=resolved_version)
    return None


@router.post("/editor/topics", status_code=status.HTTP_204_NO_CONTENT)
def create_topic_editor(
    payload: TopicCreateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.create_topic(payload, version_id=resolved_version)
    return None


@router.patch("/editor/topics/{topic_id}", status_code=status.HTTP_204_NO_CONTENT)
def update_topic_editor(
    topic_id: str,
    payload: TopicUpdateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.update_topic(topic_id, payload, version_id=resolved_version)
    return None


@router.delete("/editor/topics/{topic_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_topic_editor(
    topic_id: str,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.delete_topic(topic_id, version_id=resolved_version)
    return None


@router.post("/editor/results", status_code=status.HTTP_204_NO_CONTENT)
def create_result_editor(
    payload: ResultCreateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.create_result(
        result_id=payload.id,
        category=payload.category,
        name=payload.name,
        description=payload.description,
        version_id=resolved_version,
    )
    return None


@router.patch("/editor/results/{result_id}", status_code=status.HTTP_204_NO_CONTENT)
def update_result_editor(
    result_id: str,
    payload: ResultUpdateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.update_result(
        result_id=result_id,
        category=payload.category,
        name=payload.name,
        description=payload.description,
        is_active=payload.is_active,
        version_id=resolved_version,
    )
    return None


@router.delete("/editor/results/{result_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_result_editor(
    result_id: str,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.delete_result(result_id, version_id=resolved_version)
    return None


@router.post("/editor/attendees", status_code=status.HTTP_204_NO_CONTENT)
def create_attendee_editor(
    payload: AttendeeCreateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.create_attendee(
        attendee_id=payload.id,
        attendee_type=payload.type,
        name=payload.name,
        description=payload.description,
        version_id=resolved_version,
    )
    return None


@router.patch("/editor/attendees/{attendee_id}", status_code=status.HTTP_204_NO_CONTENT)
def update_attendee_editor(
    attendee_id: str,
    payload: AttendeeUpdateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.update_attendee(
        attendee_id=attendee_id,
        attendee_type=payload.type,
        name=payload.name,
        description=payload.description,
        is_active=payload.is_active,
        version_id=resolved_version,
    )
    return None


@router.delete("/editor/attendees/{attendee_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_attendee_editor(
    attendee_id: str,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.delete_attendee(attendee_id, version_id=resolved_version)
    return None


@router.post("/editor/rel-activity-topics", status_code=status.HTTP_204_NO_CONTENT)
def upsert_rel_activity_topic_editor(
    payload: RelActivityTopicUpsertRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.upsert_rel_activity_topic(
        activity_id=payload.activity_id,
        topic_id=payload.topic_id,
        version_id=resolved_version,
    )
    return None


@router.delete("/editor/rel-activity-topics", status_code=status.HTTP_204_NO_CONTENT)
def delete_rel_activity_topic_editor(
    activity_id: str = Query(..., description="Activity ID"),
    topic_id: str = Query(..., description="Topic ID"),
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.delete_rel_activity_topic(activity_id=activity_id, topic_id=topic_id, version_id=resolved_version)
    return None


@router.post("/editor/reorder", status_code=status.HTTP_204_NO_CONTENT)
def reorder_catalog_editor(
    payload: ReorderEntityRequest,
    project_id: str = Query(..., description="Project ID"),
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = CatalogEditorService(db)
    resolved_version = service._resolve_version_id(version_id, project_id=project_id)
    service.reorder_entities(
        project_id=project_id,
        entity=payload.entity,
        ids=payload.ids,
        version_id=resolved_version,
    )
    return None
