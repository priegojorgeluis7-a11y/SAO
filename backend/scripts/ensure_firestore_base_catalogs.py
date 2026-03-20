"""Ensure Firestore base template catalog and initial TMQ/TAP catalogs.

Usage (PowerShell):
  $env:FIRESTORE_PROJECT_ID = "sao-prod-488416"
  python backend/scripts/ensure_firestore_base_catalogs.py

Optional:
  python backend/scripts/ensure_firestore_base_catalogs.py --force
  python backend/scripts/ensure_firestore_base_catalogs.py --source-project-id TMQ
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import logging
from datetime import datetime, timezone
from typing import Any

from _script_utils import add_repo_root_to_path, configure_logging


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Ensure PROJECT_0 template and TMQ/TAP catalogs in Firestore"
    )
    parser.add_argument("--template-project-id", default="PROJECT_0")
    parser.add_argument("--source-project-id", default="TMQ")
    parser.add_argument("--force", action="store_true", help="Rewrite catalogs even if they already exist")
    return parser.parse_args()


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _compute_etag(bundle: dict[str, Any]) -> str:
    effective_payload = bundle.get("effective") or {}
    encoded = json.dumps(effective_payload, sort_keys=True, default=str).encode("utf-8")
    return "sha256:" + hashlib.sha256(encoded).hexdigest()


def _is_minimal_bundle(bundle: dict[str, Any]) -> bool:
    effective = bundle.get("effective") if isinstance(bundle, dict) else None
    entities = effective.get("entities") if isinstance(effective, dict) else None
    if not isinstance(entities, dict):
        return True

    activities = entities.get("activities") or []
    subcategories = entities.get("subcategories") or []
    purposes = entities.get("purposes") or []
    topics = entities.get("topics") or []
    results = entities.get("results") or []
    assistants = entities.get("assistants") or []

    # Treat a catalog as minimal if it only has CAM + empty dependent entities.
    if len(activities) <= 1 and not any([subcategories, purposes, topics, results, assistants]):
        return True
    return False


def _default_bundle(project_id: str, version_id: str, now: datetime) -> dict[str, Any]:
    activities = [
        {"id": "CAM", "name": "Caminamiento", "description": "Recorrido físico en campo para verificar DDV, accesos y afectaciones.", "active": True, "order": 0},
        {"id": "REU", "name": "Reunión", "description": "Coordinación técnica, social o institucional.", "active": True, "order": 1},
        {"id": "ASP", "name": "Asamblea Protocolizada", "description": "Acto formal agrario para aprobar acuerdos y COP.", "active": True, "order": 2},
        {"id": "CIN", "name": "Consulta Indígena", "description": "Proceso de participación conforme al Convenio 169 OIT.", "active": True, "order": 3},
        {"id": "SOC", "name": "Socialización", "description": "Presentación y sensibilización comunitaria.", "active": True, "order": 4},
        {"id": "AIN", "name": "Acompañamiento Institucional", "description": "Supervisión y documentación interinstitucional.", "active": True, "order": 5},
    ]

    subcategories = [
        {"id": "CAM_DDV", "activity_id": "CAM", "name": "Verificación de DDV", "description": "Revisión de límites del DDV en campo.", "active": True, "order": 0},
        {"id": "CAM_MAR", "activity_id": "CAM", "name": "Marcaje de afectaciones", "description": "Señalamiento físico de áreas afectadas.", "active": True, "order": 1},
        {"id": "CAM_ACC", "activity_id": "CAM", "name": "Revisión de accesos / BDT", "description": "Confirmación de caminos y bienes distintos a la tierra.", "active": True, "order": 2},
        {"id": "CAM_SEG", "activity_id": "CAM", "name": "Seguimiento técnico", "description": "Monitoreo y control de avances.", "active": True, "order": 3},
        {"id": "REU_TEC", "activity_id": "REU", "name": "Técnica / Interinstitucional", "description": "Coordinación entre dependencias.", "active": True, "order": 0},
        {"id": "REU_EJI", "activity_id": "REU", "name": "Ejidal / Comisariado", "description": "Diálogo con autoridades ejidales.", "active": True, "order": 1},
        {"id": "REU_MUN", "activity_id": "REU", "name": "Municipal / Estatal / PCivil", "description": "Vinculación con gobiernos locales.", "active": True, "order": 2},
        {"id": "REU_SEG", "activity_id": "REU", "name": "Seguimiento / Evaluación", "description": "Revisión de cumplimiento de acuerdos.", "active": True, "order": 3},
        {"id": "REU_INF", "activity_id": "REU", "name": "Informativa", "description": "Presentación de avances.", "active": True, "order": 4},
        {"id": "REU_MES", "activity_id": "REU", "name": "Mesa Técnica", "description": "Análisis puntual de temas técnicos/sociales.", "active": True, "order": 5},
        {"id": "ASP_1AP", "activity_id": "ASP", "name": "1ª Asamblea Protocolizada (1AP)", "description": "Convocatoria inicial y presentación del proyecto.", "active": True, "order": 0},
        {"id": "ASP_1AP_PER", "activity_id": "ASP", "name": "1ª Asamblea Protocolizada Permanente", "description": "Continúa otro día (con quórum legal).", "active": True, "order": 1},
        {"id": "ASP_2AP", "activity_id": "ASP", "name": "2ª Asamblea Protocolizada (2AP)", "description": "Con quórum legal para acuerdos.", "active": True, "order": 2},
        {"id": "ASP_2AP_PER", "activity_id": "ASP", "name": "2ª Asamblea Protocolizada Permanente", "description": "Continúa otro día.", "active": True, "order": 3},
        {"id": "ASP_INF", "activity_id": "ASP", "name": "Asamblea Informativa", "description": "Sesión explicativa previa.", "active": True, "order": 4},
        {"id": "CIN_INF", "activity_id": "CIN", "name": "Etapa Informativa", "description": "Difusión del proyecto.", "active": True, "order": 0},
        {"id": "CIN_CON", "activity_id": "CIN", "name": "Construcción de Acuerdos", "description": "Definición de compromisos.", "active": True, "order": 1},
        {"id": "CIN_ACT", "activity_id": "CIN", "name": "Etapa de Actos y Acuerdos", "description": "Firma de actas finales.", "active": True, "order": 2},
        {"id": "SOC_PRE", "activity_id": "SOC", "name": "Presentación Comunitaria", "description": "Exposición general.", "active": True, "order": 0},
        {"id": "SOC_DIF", "activity_id": "SOC", "name": "Difusión de Información", "description": "Entrega de materiales.", "active": True, "order": 1},
        {"id": "SOC_ATN", "activity_id": "SOC", "name": "Atención a Inquietudes", "description": "Gestión de dudas o quejas.", "active": True, "order": 2},
        {"id": "AIN_TEC", "activity_id": "AIN", "name": "Técnico", "description": "Supervisión de obras/trazos.", "active": True, "order": 0},
        {"id": "AIN_SOC", "activity_id": "AIN", "name": "Social", "description": "Seguimiento a compromisos.", "active": True, "order": 1},
        {"id": "AIN_DOC", "activity_id": "AIN", "name": "Documental", "description": "Registro y evidencias oficiales.", "active": True, "order": 2},
    ]

    purposes = [
        {"id": "AFEC_VER_CAM", "activity_id": "CAM", "subcategory_id": "CAM_DDV", "name": "Verificación de afectaciones", "active": True, "order": 0},
        {"id": "DDV_MAR_CAM", "activity_id": "CAM", "subcategory_id": "CAM_MAR", "name": "Marcaje o actualización de DDV / trazo", "active": True, "order": 1},
        {"id": "ACC_ALT_CAM", "activity_id": "CAM", "subcategory_id": "CAM_ACC", "name": "Análisis de accesos y pasos alternos", "active": True, "order": 2},
        {"id": "PRS_GEN_REU", "activity_id": "REU", "subcategory_id": "REU_INF", "name": "Presentación general del proyecto", "active": True, "order": 0},
        {"id": "DOC_CONV_REU", "activity_id": "REU", "subcategory_id": "REU_INF", "name": "Entrega de documentación / Convocatorias", "active": True, "order": 1},
        {"id": "SOC_CON_REU", "activity_id": "REU", "subcategory_id": "REU_SEG", "name": "Atención a inconformidades o conflictos", "active": True, "order": 2},
        {"id": "CONC_FER_REU", "activity_id": "REU", "subcategory_id": "REU_TEC", "name": "Coordinación con concesionarios ferroviarios", "active": True, "order": 3},
        {"id": "COOR_INST_REU", "activity_id": "REU", "subcategory_id": "REU_TEC", "name": "Coordinación institucional", "active": True, "order": 4},
        {"id": "PLAN_ACT_REU", "activity_id": "REU", "subcategory_id": "REU_SEG", "name": "Planeación de nuevas actividades", "active": True, "order": 5},
        {"id": "SEG_DOC_REU", "activity_id": "REU", "subcategory_id": "REU_SEG", "name": "Seguimiento administrativo / documental", "active": True, "order": 6},
        {"id": "PRS_GEN_ASP", "activity_id": "ASP", "subcategory_id": "ASP_1AP", "name": "Presentación general del proyecto", "active": True, "order": 0},
        {"id": "DOC_CONV_ASP", "activity_id": "ASP", "subcategory_id": "ASP_1AP", "name": "Entrega de documentación / Convocatorias", "active": True, "order": 1},
        {"id": "COP_FIR_ASP", "activity_id": "ASP", "subcategory_id": "ASP_2AP", "name": "Obtención de anuencia o firma de COP", "active": True, "order": 2},
        {"id": "AVAL_VAL_ASP", "activity_id": "ASP", "subcategory_id": None, "name": "Validación o ajuste de avalúos", "active": True, "order": 3},
    ]

    topics = [
        {"id": "TOP_GAL", "type": "Tecnico", "name": "Gálibos ferroviarios", "description": "Revisión de alturas/ancho de estructuras", "active": True, "order": 0},
        {"id": "TOP_ACC", "type": "Tecnico", "name": "Accesos y pasos vehiculares", "description": "Conectividad vial", "active": True, "order": 1},
        {"id": "TOP_TEN", "type": "Social/Agrario", "name": "Tenencia de la tierra", "description": "Propiedad/posesión", "active": True, "order": 2},
        {"id": "TOP_AVA", "type": "Social/Agrario", "name": "Avalúos y pagos", "description": "Valor m² y compensación", "active": True, "order": 3},
        {"id": "TOP_ARB", "type": "Ambiental", "name": "Arbolado / vegetación", "description": "Tala/reforestación", "active": True, "order": 4},
        {"id": "TOP_INAH", "type": "Patrimonial", "name": "Sitios arqueológicos / INAH", "description": "Protección patrimonial", "active": True, "order": 5},
        {"id": "TOP_CONS", "type": "Indigena", "name": "Consulta previa", "description": "Derecho de participación", "active": True, "order": 6},
    ]

    results = [
        {"id": "R01", "category": "Ejecución regular o exitosa", "name": "Actividad realizada conforme al programa", "active": True, "order": 0},
        {"id": "R02", "category": "Ejecución regular o exitosa", "name": "Asamblea con quórum legal y acuerdos aprobados", "active": True, "order": 1},
        {"id": "R03", "category": "Casos sociales o administrativos", "name": "Sin quórum / segunda convocatoria programada", "active": True, "order": 2},
        {"id": "R04", "category": "Ejecución regular o exitosa", "name": "Firma de acta informativa / COP", "active": True, "order": 3},
        {"id": "R05", "category": "Ejecución regular o exitosa", "name": "Se obtienen anuencias / permisos", "active": True, "order": 4},
        {"id": "R06", "category": "Reajustes o cambios técnicos", "name": "Se ajusta superficie o valor de afectación", "active": True, "order": 5},
    ]

    assistants = [
        {"id": "AST1", "type": "Dependencia", "name": "ARTF", "description": "Agencia Reguladora del Transporte Ferroviario", "active": True, "order": 0},
        {"id": "AST2", "type": "Dependencia", "name": "SEDATU", "description": "Secretaría de Desarrollo Agrario, Territorial y Urbano", "active": True, "order": 1},
        {"id": "AST3", "type": "Dependencia", "name": "Defensa (SEDENA)", "description": "Secretaría de la Defensa Nacional", "active": True, "order": 2},
    ]

    relations = [
        {"activity_id": "CAM", "topic_id": "TOP_GAL", "active": True},
        {"activity_id": "CAM", "topic_id": "TOP_ACC", "active": True},
        {"activity_id": "CAM", "topic_id": "TOP_TEN", "active": True},
        {"activity_id": "CAM", "topic_id": "TOP_AVA", "active": True},
        {"activity_id": "CAM", "topic_id": "TOP_ARB", "active": True},
        {"activity_id": "CAM", "topic_id": "TOP_INAH", "active": True},
        {"activity_id": "REU", "topic_id": "TOP_GAL", "active": True},
        {"activity_id": "REU", "topic_id": "TOP_AVA", "active": True},
        {"activity_id": "ASP", "topic_id": "TOP_TEN", "active": True},
        {"activity_id": "ASP", "topic_id": "TOP_AVA", "active": True},
        {"activity_id": "CIN", "topic_id": "TOP_CONS", "active": True},
        {"activity_id": "SOC", "topic_id": "TOP_TEN", "active": True},
        {"activity_id": "AIN", "topic_id": "TOP_GAL", "active": True},
        {"activity_id": "AIN", "topic_id": "TOP_ACC", "active": True},
    ]

    return {
        "schema": "sao.catalog.bundle.v1",
        "meta": {
            "project_id": project_id,
            "version_id": version_id,
            "generated_at": now,
            "versions": {
                "effective": version_id,
                "status": "published",
            },
        },
        "effective": {
            "entities": {
                "activities": activities,
                "subcategories": subcategories,
                "purposes": purposes,
                "topics": topics,
                "results": results,
                "assistants": assistants,
            },
            "relations": {
                "activity_to_topics_suggested": relations,
            },
            "color_tokens": {},
            "form_fields": [],
            "rules": {
                "completion": {
                    "activity_requires": ["result", "attendees", "comments"],
                    "allow_extra": True,
                }
            },
        },
    }


def _normalize_bundle(source: dict[str, Any], project_id: str, version_id: str, now: datetime) -> dict[str, Any]:
    bundle = copy.deepcopy(source)
    bundle.setdefault("schema", "sao.catalog.bundle.v1")
    bundle.setdefault("effective", {})
    bundle.setdefault("meta", {})

    meta = bundle["meta"]
    meta["project_id"] = project_id
    meta["version_id"] = version_id
    meta["generated_at"] = now

    versions = meta.setdefault("versions", {})
    versions["effective"] = version_id
    versions["status"] = "published"

    if not meta.get("etag"):
        meta["etag"] = _compute_etag(bundle)

    return bundle


def _get_current_version_id(client, project_id: str) -> str | None:
    project = project_id.strip().upper()

    current_snap = client.collection("catalog_current").document(project).get()
    if current_snap.exists:
        payload = current_snap.to_dict() or {}
        version_id = str(payload.get("version_id") or "").strip()
        if version_id:
            return version_id

    docs = (
        client.collection("catalog_versions")
        .where("project_id", "==", project)
        .where("is_current", "==", True)
        .limit(1)
        .stream()
    )
    for doc in docs:
        payload = doc.to_dict() or {}
        version_id = str(payload.get("version_id") or payload.get("id") or doc.id).strip()
        if version_id:
            return version_id

    return None


def _load_bundle(client, project_id: str, version_id: str | None) -> dict[str, Any] | None:
    project = project_id.strip().upper()
    candidates = []
    if version_id:
        candidates.append(client.collection("catalog_bundles").document(f"{project}:{version_id}").get())
        candidates.append(
            client.collection("catalog_bundles")
            .document(project)
            .collection("versions")
            .document(version_id)
            .get()
        )
    candidates.append(client.collection("catalog_bundles").document(project).get())

    for snap in candidates:
        if snap.exists:
            payload = snap.to_dict() or {}
            if isinstance(payload, dict) and payload.get("schema") and isinstance(payload.get("effective"), dict):
                return payload
    return None


def _pick_source_bundle(client, template_project_id: str, source_project_id: str) -> tuple[dict[str, Any] | None, str]:
    template_project = template_project_id.strip().upper()
    source_project = source_project_id.strip().upper()

    template_version = _get_current_version_id(client, template_project)
    template_bundle = _load_bundle(client, template_project, template_version)
    if template_bundle and not _is_minimal_bundle(template_bundle):
        return template_bundle, f"{template_project}:{template_version or 'current'}"

    source_version = _get_current_version_id(client, source_project)
    source_bundle = _load_bundle(client, source_project, source_version)
    if source_bundle and not _is_minimal_bundle(source_bundle):
        return source_bundle, f"{source_project}:{source_version or 'current'}"

    for doc in client.collection("catalog_bundles").limit(30).stream():
        payload = doc.to_dict() or {}
        if (
            isinstance(payload, dict)
            and payload.get("schema")
            and isinstance(payload.get("effective"), dict)
            and not _is_minimal_bundle(payload)
        ):
            return payload, f"{doc.id}"

    return None, "default"


def _ensure_project_doc(client, project_id: str, name: str, now: datetime) -> None:
    project = project_id.strip().upper()
    ref = client.collection("projects").document(project)
    snap = ref.get()

    payload = {
        "id": project,
        "name": name,
        "status": "active",
        "updated_at": now,
    }
    if not snap.exists:
        payload["created_at"] = now
        payload["start_date"] = now
    ref.set(payload, merge=True)


def _ensure_catalog(client, project_id: str, source_bundle: dict[str, Any], force: bool) -> str:
    project = project_id.strip().upper()
    now = _utc_now()
    existing_version = _get_current_version_id(client, project)
    version_id = existing_version or f"{project.lower()}-v1.0.0"

    existing_bundle = _load_bundle(client, project, existing_version)
    existing_is_minimal = bool(existing_bundle and _is_minimal_bundle(existing_bundle))

    if existing_version and not force and not existing_is_minimal:
        logging.info("Catalog already exists for %s (version=%s). Skipping.", project, existing_version)
        return existing_version

    if existing_is_minimal and not force:
        logging.warning(
            "Catalog for %s is minimal/incomplete (version=%s). Rewriting with source bundle.",
            project,
            existing_version,
        )

    bundle = _normalize_bundle(source_bundle, project, version_id, now)

    client.collection("catalog_bundles").document(project).set(bundle)
    client.collection("catalog_bundles").document(f"{project}:{version_id}").set(bundle)
    client.collection("catalog_bundles").document(project).collection("versions").document(version_id).set(bundle)

    current_payload = {
        "project_id": project,
        "version_id": version_id,
        "version_number": version_id,
        "published_at": now,
        "is_current": True,
        "hash": (bundle.get("meta") or {}).get("etag"),
        "updated_at": now,
    }
    client.collection("catalog_current").document(project).set(current_payload, merge=True)

    for doc in (
        client.collection("catalog_versions")
        .where("project_id", "==", project)
        .where("is_current", "==", True)
        .stream()
    ):
        doc.reference.set({"is_current": False, "updated_at": now}, merge=True)

    client.collection("catalog_versions").document(version_id).set(
        {
            "id": version_id,
            "version_id": version_id,
            "version_number": version_id,
            "project_id": project,
            "status": "published",
            "hash": (bundle.get("meta") or {}).get("etag"),
            "published_at": now,
            "created_at": now,
            "updated_at": now,
            "is_current": True,
        },
        merge=True,
    )

    return version_id


def main() -> int:
    configure_logging()
    args = _parse_args()
    add_repo_root_to_path()

    from app.core.firestore import get_firestore_client

    client = get_firestore_client()
    now = _utc_now()

    template_project = args.template_project_id.strip().upper()
    source_project = args.source_project_id.strip().upper()

    _ensure_project_doc(client, template_project, "Proyecto 0 - Catalogo Base", now)
    _ensure_project_doc(client, "TMQ", "Tren Mexico-Queretaro", now)
    _ensure_project_doc(client, "TAP", "Tren AIFA-Pachuca", now)

    source_bundle, source_label = _pick_source_bundle(client, template_project, source_project)
    if source_bundle is None:
        logging.warning(
            "No source bundle found in Firestore. Creating a comprehensive default catalog template."
        )
        source_bundle = _default_bundle(template_project, f"{template_project.lower()}-v1.0.0", now)
        source_label = "default"

    logging.info("Using source bundle: %s", source_label)

    template_version = _ensure_catalog(client, template_project, source_bundle, args.force)
    tmq_version = _ensure_catalog(client, "TMQ", source_bundle, args.force)
    tap_version = _ensure_catalog(client, "TAP", source_bundle, args.force)

    logging.info("Template project ensured: %s version=%s", template_project, template_version)
    logging.info("Project ensured: TMQ version=%s", tmq_version)
    logging.info("Project ensured: TAP version=%s", tap_version)
    logging.info("Firestore base catalogs are ready.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
