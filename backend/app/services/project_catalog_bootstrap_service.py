import hashlib
import json
import logging
from datetime import datetime, timezone
from uuid import uuid4

logger = logging.getLogger(__name__)

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.models.catalog_effective import CatProject
from app.models.catalog import (
    CATActivityType,
    CATChecklistTemplate,
    CATEvidenceRule,
    CATEventType,
    CATFormField,
    CATWorkflowState,
    CATWorkflowTransition,
    CatalogStatus,
    CatalogVersion,
)


def bootstrap_project_catalog_from_base(
    db: Session,
    *,
    target_project_id: str,
    source_project_id: str = "TMQ",
    source_version_number: str | None = None,
    target_version_number: str = "1.0.0",
    published_by_id=None,
) -> CatalogVersion:
    source_query = db.query(CatalogVersion).filter(CatalogVersion.project_id == source_project_id)
    if source_version_number and source_version_number.strip():
        source_query = source_query.filter(CatalogVersion.version_number == source_version_number.strip())
    else:
        source_query = source_query.order_by(
            CatalogVersion.status.desc(),
            CatalogVersion.published_at.desc(),
            CatalogVersion.created_at.desc(),
        )

    source_version = source_query.first()
    if not source_version:
        raise ValueError(f"Base catalog not found for project '{source_project_id}'")

    existing_target = (
        db.query(CatalogVersion)
        .filter(
            CatalogVersion.project_id == target_project_id,
            CatalogVersion.version_number == target_version_number,
        )
        .first()
    )
    if existing_target:
        raise ValueError(
            f"Target catalog already exists for project '{target_project_id}' version '{target_version_number}'"
        )

    activity_map: dict = {}
    event_map: dict = {}
    state_map: dict = {}

    target_version_id = uuid4()
    source_hash = source_version.hash or ""
    target_hash = hashlib.sha256(
        json.dumps(
            {
                "source_project_id": source_project_id,
                "source_version_number": source_version.version_number,
                "target_project_id": target_project_id,
                "target_version_number": target_version_number,
                "source_hash": source_hash,
            },
            sort_keys=True,
        ).encode()
    ).hexdigest()

    target_version = CatalogVersion(
        id=target_version_id,
        project_id=target_project_id,
        version_number=target_version_number,
        status=CatalogStatus.PUBLISHED,
        hash=target_hash,
        notes=(
            f"Bootstrap from {source_project_id} v{source_version.version_number}"
            if not source_version_number
            else f"Bootstrap from {source_project_id} v{source_version_number}"
        ),
        published_by_id=published_by_id,
        published_at=datetime.now(timezone.utc),
    )
    db.add(target_version)
    db.flush()

    source_activity_types = (
        db.query(CATActivityType)
        .filter(CATActivityType.version_id == source_version.id)
        .all()
    )
    for item in source_activity_types:
        new_id = uuid4()
        activity_map[item.id] = new_id
        db.add(
            CATActivityType(
                id=new_id,
                version_id=target_version_id,
                code=item.code,
                name=item.name,
                description=item.description,
                icon=item.icon,
                color=item.color,
                sort_order=item.sort_order,
                is_active=item.is_active,
                requires_approval=item.requires_approval,
                max_duration_minutes=item.max_duration_minutes,
                notification_email=item.notification_email,
            )
        )

    source_event_types = (
        db.query(CATEventType)
        .filter(CATEventType.version_id == source_version.id)
        .all()
    )
    for item in source_event_types:
        new_id = uuid4()
        event_map[item.id] = new_id
        db.add(
            CATEventType(
                id=new_id,
                version_id=target_version_id,
                code=item.code,
                name=item.name,
                description=item.description,
                icon=item.icon,
                color=item.color,
                priority=item.priority,
                sort_order=item.sort_order,
                is_active=item.is_active,
                auto_create_activity=item.auto_create_activity,
                requires_immediate_response=item.requires_immediate_response,
            )
        )

    source_states = (
        db.query(CATWorkflowState)
        .filter(CATWorkflowState.version_id == source_version.id)
        .all()
    )
    for item in source_states:
        new_id = uuid4()
        state_map[item.id] = new_id
        db.add(
            CATWorkflowState(
                id=new_id,
                version_id=target_version_id,
                entity_type=item.entity_type,
                code=item.code,
                label=item.label,
                color=item.color,
                is_initial=item.is_initial,
                is_final=item.is_final,
                sort_order=item.sort_order,
            )
        )

    source_transitions = (
        db.query(CATWorkflowTransition)
        .filter(CATWorkflowTransition.version_id == source_version.id)
        .all()
    )
    for item in source_transitions:
        from_state_id = state_map.get(item.from_state_id)
        to_state_id = state_map.get(item.to_state_id)
        if not from_state_id or not to_state_id:
            continue
        db.add(
            CATWorkflowTransition(
                id=uuid4(),
                version_id=target_version_id,
                from_state_id=from_state_id,
                to_state_id=to_state_id,
                label=item.label,
                description=item.description,
                allowed_roles=item.allowed_roles,
                required_permissions=item.required_permissions,
                required_fields=item.required_fields,
                confirm_message=item.confirm_message,
                sort_order=item.sort_order,
            )
        )

    source_form_fields = (
        db.query(CATFormField)
        .filter(CATFormField.version_id == source_version.id)
        .all()
    )
    for item in source_form_fields:
        mapped_type_id = activity_map.get(item.type_id) or event_map.get(item.type_id)
        if mapped_type_id is None:
            continue
        db.add(
            CATFormField(
                id=uuid4(),
                version_id=target_version_id,
                entity_type=item.entity_type,
                type_id=mapped_type_id,
                key=item.key,
                label=item.label,
                help_text=item.help_text,
                widget=item.widget,
                sort_order=item.sort_order,
                required=item.required,
                validation_regex=item.validation_regex,
                validation_message=item.validation_message,
                min_value=item.min_value,
                max_value=item.max_value,
                min_length=item.min_length,
                max_length=item.max_length,
                options=item.options,
                visible_when=item.visible_when,
                required_when=item.required_when,
                default_value=item.default_value,
            )
        )

    source_evidence_rules = (
        db.query(CATEvidenceRule)
        .filter(CATEvidenceRule.version_id == source_version.id)
        .all()
    )
    for item in source_evidence_rules:
        mapped_type_id = activity_map.get(item.type_id) or event_map.get(item.type_id)
        if mapped_type_id is None:
            continue
        db.add(
            CATEvidenceRule(
                id=uuid4(),
                version_id=target_version_id,
                entity_type=item.entity_type,
                type_id=mapped_type_id,
                min_photos=item.min_photos,
                max_photos=item.max_photos,
                requires_gps=item.requires_gps,
                requires_signature=item.requires_signature,
                allowed_file_types=item.allowed_file_types,
                max_file_size_mb=item.max_file_size_mb,
                description=item.description,
            )
        )

    source_checklists = (
        db.query(CATChecklistTemplate)
        .filter(CATChecklistTemplate.version_id == source_version.id)
        .all()
    )
    for item in source_checklists:
        mapped_activity_id = activity_map.get(item.activity_type_id)
        if mapped_activity_id is None:
            continue
        db.add(
            CATChecklistTemplate(
                id=uuid4(),
                version_id=target_version_id,
                activity_type_id=mapped_activity_id,
                name=item.name,
                description=item.description,
                items=item.items,
            )
        )

    db.flush()

    # Registrar proyecto en Sistema B (cat_projects) para que el bundle endpoint funcione
    seed_project_effective_catalog(
        db,
        target_project_id=target_project_id,
        source_project_id=source_project_id,
    )

    return target_version


def seed_project_effective_catalog(
    db: Session,
    *,
    target_project_id: str,
    source_project_id: str = "TMQ",
) -> str:
    """
    Registra target_project_id en Sistema B (cat_projects) apuntando al mismo
    version_id que source_project_id. Las entidades cat_* son compartidas entre
    proyectos; la separación por proyecto se hace vía proj_catalog_override.

    Idempotente: si ya existe una fila en cat_projects para target_project_id,
    retorna el version_id existente sin modificar nada.

    Returns:
        version_id compartido del proyecto fuente.

    Raises:
        ValueError: si source_project_id no existe en cat_projects.
    """
    now = datetime.now(timezone.utc)
    normalized_target = target_project_id.strip().upper()
    normalized_source = source_project_id.strip().upper()

    existing = (
        db.query(CatProject)
        .filter(CatProject.project_id == normalized_target)
        .first()
    )
    if existing:
        return existing.version_id

    source_project = (
        db.query(CatProject)
        .filter(CatProject.project_id == normalized_source, CatProject.is_active.is_(True))
        .first()
    )
    if not source_project:
        # Source not in Sistema B yet (seed not run). Skip registration silently.
        # Sistema A bootstrap (CatalogVersion) still completes successfully.
        logger.warning(
            "seed_project_effective_catalog: source '%s' not in cat_projects. "
            "Skipping Sistema B registration for '%s'. "
            "Run seeds to enable bundle endpoint for this project.",
            normalized_source,
            normalized_target,
        )
        return ""

    db.execute(
        text(
            "INSERT INTO cat_projects (project_id, name, version_id, is_active, updated_at) "
            "VALUES (:pid, :name, :vid, :active, :now) "
            "ON CONFLICT (project_id) DO NOTHING"
        ),
        {
            "pid": normalized_target,
            "name": normalized_target,
            "vid": source_project.version_id,
            "active": True,
            "now": now,
        },
    )
    db.flush()
    return source_project.version_id
