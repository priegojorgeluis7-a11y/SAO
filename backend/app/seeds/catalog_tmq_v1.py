"""Seeds for TMQ Catalog v1.0.0."""

import argparse
import hashlib
import json
from datetime import datetime, timezone
from uuid import UUID, uuid4

from sqlalchemy import text
from sqlalchemy.orm import Session

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


def get_admin_user_id(db: Session) -> UUID:
    """Return preferred admin user id (admin@sao.mx) or first available user."""
    admin_row = db.execute(
        text("SELECT id FROM users WHERE email = :email ORDER BY created_at DESC LIMIT 1"),
        {"email": "admin@sao.mx"},
    ).first()
    if admin_row:
        return UUID(str(admin_row[0]))

    any_user_row = db.execute(
        text("SELECT id FROM users ORDER BY created_at ASC LIMIT 1")
    ).first()
    if any_user_row:
        return UUID(str(any_user_row[0]))

    raise RuntimeError("No users found in database. Run initial_data seeds first.")


def _catalog_metadata(admin_id: UUID) -> dict:
    return {
        "project_id": "TMQ",
        "version_number": "1.0.0",
        "status": CatalogStatus.PUBLISHED,
        "notes": "Catálogo inicial para proyecto Transmisión Mantaro-Quencoro",
        "published_by_id": admin_id,
        "published_at": datetime.now(timezone.utc),
    }


def _delete_version_children(db: Session, version_id: UUID) -> None:
    db.query(CATChecklistTemplate).filter(CATChecklistTemplate.version_id == version_id).delete(synchronize_session=False)
    db.query(CATWorkflowTransition).filter(CATWorkflowTransition.version_id == version_id).delete(synchronize_session=False)
    db.query(CATWorkflowState).filter(CATWorkflowState.version_id == version_id).delete(synchronize_session=False)
    db.query(CATEvidenceRule).filter(CATEvidenceRule.version_id == version_id).delete(synchronize_session=False)
    db.query(CATFormField).filter(CATFormField.version_id == version_id).delete(synchronize_session=False)
    db.query(CATEventType).filter(CATEventType.version_id == version_id).delete(synchronize_session=False)
    db.query(CATActivityType).filter(CATActivityType.version_id == version_id).delete(synchronize_session=False)


def seed_catalog_tmq_v1(db: Session, force_update: bool = False) -> None:
    """Create TMQ v1.0.0 catalog or refresh it when force_update is enabled."""
    print("\n=== Seeding TMQ Catalog v1.0.0 ===\n")

    admin_id = get_admin_user_id(db)
    existing = (
        db.query(CatalogVersion)
        .filter(CatalogVersion.project_id == "TMQ", CatalogVersion.version_number == "1.0.0")
        .first()
    )

    if existing and not force_update:
        print(f"[SKIP] Catalog TMQ v1.0.0 already exists (ID: {existing.id})")
        return

    if existing and force_update:
        version = existing
        _delete_version_children(db, version.id)
        for key, value in _catalog_metadata(admin_id).items():
            setattr(version, key, value)
        db.flush()
        print(f"[FORCE] Refreshed CatalogVersion 1.0.0 (ID: {version.id})")
    else:
        version = CatalogVersion(id=uuid4(), **_catalog_metadata(admin_id))
        db.add(version)
        db.flush()
        print(f"[OK] Created CatalogVersion 1.0.0 (ID: {version.id})")

    activity_types = [
        CATActivityType(id=uuid4(), version_id=version.id, code="INSP_CIVIL", name="Inspección Civil", description="Inspección de obras civiles: cimentaciones, estructuras, torres", icon="engineering", color="#1976D2", requires_approval=True, sort_order=1),
        CATActivityType(id=uuid4(), version_id=version.id, code="ASAMBLEA", name="Asamblea Informativa", description="Reuniones con comunidades y stakeholders para socialización del proyecto", icon="groups", color="#388E3C", requires_approval=False, sort_order=2),
        CATActivityType(id=uuid4(), version_id=version.id, code="RECORRIDO", name="Recorrido de Línea", description="Recorrido de verificación de servidumbre y derecho de vía", icon="explore", color="#F57C00", requires_approval=False, sort_order=3),
        CATActivityType(id=uuid4(), version_id=version.id, code="GESTION", name="Gestión Social", description="Atención a solicitudes y consultas de la población", icon="support_agent", color="#7B1FA2", requires_approval=False, sort_order=4),
        CATActivityType(id=uuid4(), version_id=version.id, code="CAPACITACION", name="Capacitación", description="Capacitaciones al personal de campo y contratistas", icon="school", color="#0097A7", requires_approval=False, sort_order=5),
    ]
    db.add_all(activity_types)
    db.flush()

    event_types = [
        CATEventType(id=uuid4(), version_id=version.id, code="INCIDENTE", name="Incidente", description="Eventos no planificados que requieren atención inmediata", icon="warning", color="#F44336", priority="high", auto_create_activity=True, sort_order=1),
        CATEventType(id=uuid4(), version_id=version.id, code="HALLAZGO", name="Hallazgo", description="Observaciones durante inspecciones o recorridos", icon="search", color="#FF9800", priority="medium", auto_create_activity=False, sort_order=2),
        CATEventType(id=uuid4(), version_id=version.id, code="SOLICITUD", name="Solicitud Ciudadana", description="Consultas o solicitudes de la población local", icon="contact_support", color="#2196F3", priority="normal", auto_create_activity=True, sort_order=3),
    ]
    db.add_all(event_types)
    db.flush()

    form_fields = [
        CATFormField(id=uuid4(), version_id=version.id, entity_type="activity", type_id=activity_types[0].id, key="num_inspeccion", label="Número de Inspección", widget="text", required=True, validation_regex=r"^INS-\d{4}$", validation_message="Debe seguir el formato INS-0001", sort_order=1),
        CATFormField(id=uuid4(), version_id=version.id, entity_type="activity", type_id=activity_types[0].id, key="hora_inicio", label="Hora de Inicio", widget="time", required=True, sort_order=2),
        CATFormField(id=uuid4(), version_id=version.id, entity_type="activity", type_id=activity_types[0].id, key="hora_fin", label="Hora de Fin", widget="time", required=True, sort_order=3),
        CATFormField(id=uuid4(), version_id=version.id, entity_type="activity", type_id=activity_types[0].id, key="tipo_estructura", label="Tipo de Estructura", widget="select", required=True, options=[{"value": "torre_suspension", "label": "Torre Suspensión"}, {"value": "torre_tension", "label": "Torre Tensión"}, {"value": "torre_angulo", "label": "Torre Ángulo"}, {"value": "cimentacion", "label": "Cimentación"}], sort_order=4),
        CATFormField(id=uuid4(), version_id=version.id, entity_type="activity", type_id=activity_types[0].id, key="observaciones", label="Observaciones", widget="textarea", required=False, sort_order=5),
        CATFormField(id=uuid4(), version_id=version.id, entity_type="activity", type_id=activity_types[0].id, key="conforme", label="¿Conforme?", widget="checkbox", required=True, sort_order=6),
        CATFormField(id=uuid4(), version_id=version.id, entity_type="activity", type_id=activity_types[1].id, key="comunidad", label="Comunidad", widget="text", required=True, sort_order=1),
        CATFormField(id=uuid4(), version_id=version.id, entity_type="activity", type_id=activity_types[1].id, key="num_asistentes", label="Número de Asistentes", widget="number", required=True, min_value=1, max_value=500, sort_order=2),
        CATFormField(id=uuid4(), version_id=version.id, entity_type="activity", type_id=activity_types[1].id, key="temas_tratados", label="Temas Tratados", widget="multiselect", required=True, options=[{"value": "avance_obra", "label": "Avance de Obra"}, {"value": "servidumbre", "label": "Servidumbre"}, {"value": "contratacion_local", "label": "Contratación Local"}, {"value": "seguridad", "label": "Seguridad"}, {"value": "medio_ambiente", "label": "Medio Ambiente"}], sort_order=3),
        CATFormField(id=uuid4(), version_id=version.id, entity_type="activity", type_id=activity_types[1].id, key="acuerdos", label="Acuerdos", widget="textarea", required=True, sort_order=4),
        CATFormField(id=uuid4(), version_id=version.id, entity_type="event", type_id=event_types[0].id, key="tipo_incidente", label="Tipo de Incidente", widget="select", required=True, options=[{"value": "seguridad", "label": "Seguridad"}, {"value": "ambiental", "label": "Ambiental"}, {"value": "social", "label": "Social"}, {"value": "operacional", "label": "Operacional"}], sort_order=1),
        CATFormField(id=uuid4(), version_id=version.id, entity_type="event", type_id=event_types[0].id, key="gravedad", label="Gravedad", widget="select", required=True, options=[{"value": "leve", "label": "Leve"}, {"value": "moderado", "label": "Moderado"}, {"value": "grave", "label": "Grave"}, {"value": "muy_grave", "label": "Muy Grave"}], sort_order=2),
        CATFormField(id=uuid4(), version_id=version.id, entity_type="event", type_id=event_types[0].id, key="descripcion_incidente", label="Descripción del Incidente", widget="textarea", required=True, sort_order=3),
    ]
    db.add_all(form_fields)
    db.flush()

    workflow_states = [
        CATWorkflowState(id=uuid4(), version_id=version.id, entity_type="activity", code="PROGRAMADA", label="Programada", color="#FFC107", is_initial=True, is_final=False, sort_order=1),
        CATWorkflowState(id=uuid4(), version_id=version.id, entity_type="activity", code="EN_EJECUCION", label="En Ejecución", color="#FF5722", is_initial=False, is_final=False, sort_order=2),
        CATWorkflowState(id=uuid4(), version_id=version.id, entity_type="activity", code="ENVIADA", label="Enviada", color="#2196F3", is_initial=False, is_final=False, sort_order=3),
        CATWorkflowState(id=uuid4(), version_id=version.id, entity_type="activity", code="VALIDADA", label="Validada", color="#4CAF50", is_initial=False, is_final=True, sort_order=4),
        CATWorkflowState(id=uuid4(), version_id=version.id, entity_type="activity", code="CANCELADA", label="Cancelada", color="#9E9E9E", is_initial=False, is_final=True, sort_order=5),
    ]
    db.add_all(workflow_states)
    db.flush()

    transitions = [
        CATWorkflowTransition(id=uuid4(), version_id=version.id, from_state_id=workflow_states[0].id, to_state_id=workflow_states[1].id, label="Iniciar", allowed_roles=[4, 3, 2], required_fields=[], sort_order=1),
        CATWorkflowTransition(id=uuid4(), version_id=version.id, from_state_id=workflow_states[0].id, to_state_id=workflow_states[4].id, label="Cancelar", allowed_roles=[3, 2], required_fields=["motivo_cancelacion"], sort_order=2),
        CATWorkflowTransition(id=uuid4(), version_id=version.id, from_state_id=workflow_states[1].id, to_state_id=workflow_states[2].id, label="Enviar", allowed_roles=[4, 3], required_fields=[], sort_order=3),
        CATWorkflowTransition(id=uuid4(), version_id=version.id, from_state_id=workflow_states[2].id, to_state_id=workflow_states[3].id, label="Validar", allowed_roles=[3, 2], required_fields=[], sort_order=4),
        CATWorkflowTransition(id=uuid4(), version_id=version.id, from_state_id=workflow_states[2].id, to_state_id=workflow_states[1].id, label="Rechazar", allowed_roles=[3, 2], required_fields=["motivo_rechazo"], sort_order=5),
    ]
    db.add_all(transitions)
    db.flush()

    evidence_rules = [
        CATEvidenceRule(id=uuid4(), version_id=version.id, entity_type="activity", type_id=activity_types[0].id, min_photos=2, max_photos=20, requires_gps=True, requires_signature=False),
        CATEvidenceRule(id=uuid4(), version_id=version.id, entity_type="activity", type_id=activity_types[1].id, min_photos=3, max_photos=30, requires_gps=True, requires_signature=True),
        CATEvidenceRule(id=uuid4(), version_id=version.id, entity_type="event", type_id=event_types[0].id, min_photos=1, max_photos=10, requires_gps=True, requires_signature=False),
    ]
    db.add_all(evidence_rules)
    db.flush()

    checklist = CATChecklistTemplate(
        id=uuid4(),
        version_id=version.id,
        activity_type_id=activity_types[0].id,
        name="Checklist Inspección Civil",
        description="Lista de verificación para inspecciones de obras civiles",
        items=[
            {"id": 1, "label": "Verificar replanteo topográfico", "required": True},
            {"id": 2, "label": "Revisar dimensiones de excavación", "required": True},
            {"id": 3, "label": "Verificar armadura de acero", "required": True},
            {"id": 4, "label": "Revisar calidad del concreto", "required": True},
            {"id": 5, "label": "Verificar planos de detalle", "required": True},
            {"id": 6, "label": "Revisar ensayos de laboratorio", "required": False},
            {"id": 7, "label": "Tomar coordenadas GPS", "required": True},
        ],
    )
    db.add(checklist)

    catalog_data = {
        "version": version.version_number,
        "project_id": version.project_id,
        "activity_types": [{"code": at.code, "name": at.name, "color": at.color} for at in activity_types],
        "event_types": [{"code": et.code, "name": et.name, "priority": et.priority} for et in event_types],
        "form_fields": [{"key": ff.key, "widget": ff.widget, "required": ff.required} for ff in form_fields],
        "workflow_states": [{"code": ws.code, "label": ws.label} for ws in workflow_states],
        "workflow_transitions": len(transitions),
        "evidence_rules": len(evidence_rules),
    }

    version.hash = hashlib.sha256(json.dumps(catalog_data, sort_keys=True).encode()).hexdigest()
    db.commit()

    print(f"[OK] Generated catalog hash: {version.hash[:16]}...")
    print("\n=== TMQ Catalog v1.0.0 seeded successfully ===\n")


if __name__ == "__main__":
    from app.core.database import SessionLocal

    parser = argparse.ArgumentParser(description="Seed TMQ catalog v1.0.0")
    parser.add_argument(
        "--force-update",
        action="store_true",
        help="Refresh existing TMQ v1.0.0 catalog data instead of skipping",
    )
    args = parser.parse_args()

    db = SessionLocal()
    try:
        seed_catalog_tmq_v1(db, force_update=args.force_update)
    except Exception as error:
        print(f"\n[ERROR] Failed to seed catalog: {error}")
        db.rollback()
        raise
    finally:
        db.close()
