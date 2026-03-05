"""Seed del catálogo efectivo (System B) para proyecto TMQ v2.0.0.

6 actividades operativas de campo:
  CAM  Caminamiento
  REU  Reunión
  ASP  Asamblea Protocolizada
  CIN  Consulta Indígena
  SOC  Socialización
  AIN  Acompañamiento Institucional

Subcategorías, propósitos, temas y relaciones actividad→tema.
Idempotente: usa INSERT ... ON CONFLICT DO UPDATE.
"""
from datetime import datetime, timezone
from sqlalchemy import text
from sqlalchemy.orm import Session

VERSION_ID = "tmq-v2.0.0"
PROJECT_ID = "TMQ"
_NOW = datetime.now(timezone.utc)

DEFAULT_COLOR_TOKENS = {
    "status": {
        "borrador": "#6B7280",
        "nuevo": "#2563EB",
        "en_revision": "#D97706",
        "aprobado": "#059669",
        "rechazado": "#DC2626",
    },
    "severity": {
        "baja": "#10B981",
        "media": "#F59E0B",
        "alta": "#EF4444",
    },
}

DEFAULT_FORM_FIELDS = [
    {
        "entity_type": "activity",
        "type_id": "CAM",
        "fields": [
            {
                "key": "tramo",
                "label": "Tramo",
                "widget": "text",
                "required": True,
            },
            {
                "key": "pk_inicio",
                "label": "PK Inicio",
                "widget": "text",
                "required": True,
            },
        ],
    },
    {
        "entity_type": "activity",
        "type_id": "REU",
        "fields": [
            {
                "key": "dependencia",
                "label": "Dependencia",
                "widget": "text",
                "required": True,
            }
        ],
    },
]


# ─── helpers ──────────────────────────────────────────────────────────────────

def _upsert(db: Session, table: str, pk_col: str, pk_val: str, row: dict) -> None:
    cols = list(row.keys())
    placeholders = ", ".join(f":{c}" for c in cols)
    updates = ", ".join(f"{c} = :{c}" for c in cols if c != pk_col)
    db.execute(
        text(
            f"INSERT INTO {table} ({', '.join(cols)}) VALUES ({placeholders}) "
            f"ON CONFLICT ({pk_col}) DO UPDATE SET {updates}"
        ),
        row,
    )


def _upsert2(db: Session, table: str, pk1: str, pk2: str, row: dict) -> None:
    cols = list(row.keys())
    placeholders = ", ".join(f":{c}" for c in cols)
    updates = ", ".join(f"{c} = :{c}" for c in cols if c not in (pk1, pk2))
    db.execute(
        text(
            f"INSERT INTO {table} ({', '.join(cols)}) VALUES ({placeholders}) "
            f"ON CONFLICT ({pk1}, {pk2}) DO UPDATE SET {updates}"
        ),
        row,
    )


# ─── seed principal ───────────────────────────────────────────────────────────

def seed_effective_catalog_tmq(db: Session) -> None:
    print("\n=== Seeding Effective Catalog TMQ v2.0.0 ===\n")

    # 1. catalog_version ──────────────────────────────────────────────────────
    db.execute(text("UPDATE catalog_version SET is_current = false WHERE is_current = true"))
    _upsert(db, "catalog_version", "version_id", VERSION_ID, {
        "version_id": VERSION_ID,
        "is_current": True,
        "created_at": _NOW,
        "changelog": "Catálogo TMQ v2 — 6 actividades de campo operativas",
    })
    print(f"[OK] catalog_version: {VERSION_ID} (is_current=true)")

    # 2. cat_projects ─────────────────────────────────────────────────────────
    _upsert(db, "cat_projects", "project_id", PROJECT_ID, {
        "project_id": PROJECT_ID,
        "name": "Transmisión Mantaro-Quencoro",
        "version_id": VERSION_ID,
        "is_active": True,
        "updated_at": _NOW,
    })
    print(f"[OK] cat_projects: {PROJECT_ID}")

    # 3. cat_activities ───────────────────────────────────────────────────────
    activities = [
        ("CAM", "Caminamiento",                "Recorrido físico en campo para verificar DDV, accesos y afectaciones.", 0),
        ("REU", "Reunión",                     "Coordinación técnica, social o institucional.", 1),
        ("ASP", "Asamblea Protocolizada",      "Acto formal agrario para aprobar acuerdos y Convenio de Ocupación Previa (COP).", 2),
        ("CIN", "Consulta Indígena",           "Proceso de participación conforme al Convenio 169 OIT.", 3),
        ("SOC", "Socialización",               "Presentación y sensibilización comunitaria.", 4),
        ("AIN", "Acompañamiento Institucional","Supervisión y documentación interinstitucional.", 5),
    ]
    for act_id, name, desc, _order in activities:
        _upsert(db, "cat_activities", "activity_id", act_id, {
            "activity_id": act_id,
            "name": name,
            "description": desc,
            "version_id": VERSION_ID,
            "is_active": True,
            "updated_at": _NOW,
        })
    print(f"[OK] cat_activities: {len(activities)} registros")

    # 4. cat_subcategories ────────────────────────────────────────────────────
    subcategories = [
        # Caminamiento
        ("CAM_DDV", "CAM", "Verificación de DDV",        "Revisión de límites del DDV en campo.", 0),
        ("CAM_MAR", "CAM", "Marcaje de afectaciones",    "Señalamiento físico de áreas afectadas.", 1),
        ("CAM_ACC", "CAM", "Revisión de accesos / BDT",  "Confirmación de caminos y bienes distintos a la tierra.", 2),
        ("CAM_SEG", "CAM", "Seguimiento técnico",        "Monitoreo y control de avances.", 3),
        # Reunión
        ("REU_TEC", "REU", "Técnica / Interinstitucional","Coordinación entre dependencias.", 0),
        ("REU_EJI", "REU", "Ejidal / Comisariado",       "Diálogo con autoridades ejidales.", 1),
        ("REU_MUN", "REU", "Municipal / Estatal / PCivil","Vinculación con gobiernos locales.", 2),
        ("REU_SEG", "REU", "Seguimiento / Evaluación",   "Revisión de cumplimiento de acuerdos.", 3),
        ("REU_INF", "REU", "Informativa",                "Presentación de avances.", 4),
        ("REU_MES", "REU", "Mesa Técnica",               "Análisis puntual de temas técnicos/sociales.", 5),
        # Asamblea Protocolizada
        ("ASP_1AP",     "ASP", "1ª Asamblea Protocolizada (1AP)",           "Convocatoria inicial, presentación del proyecto.", 0),
        ("ASP_1AP_PER", "ASP", "1ª Asamblea Protocolizada Permanente",       "Continúa otro día (con quórum legal).", 1),
        ("ASP_2AP",     "ASP", "2ª Asamblea Protocolizada (2AP)",           "Con quórum legal para acuerdos.", 2),
        ("ASP_2AP_PER", "ASP", "2ª Asamblea Protocolizada Permanente",       "Continúa otro día.", 3),
        ("ASP_INF",     "ASP", "Asamblea Informativa",                       "Sesión explicativa previa.", 4),
        # Consulta Indígena
        ("CIN_INF", "CIN", "Etapa Informativa",               "Difusión del proyecto.", 0),
        ("CIN_CON", "CIN", "Construcción de Acuerdos",        "Definición de compromisos.", 1),
        ("CIN_ACT", "CIN", "Etapa de Actos y Acuerdos",       "Firma de actas finales.", 2),
        # Socialización
        ("SOC_PRE", "SOC", "Presentación Comunitaria",  "Exposición general.", 0),
        ("SOC_DIF", "SOC", "Difusión de Información",   "Entrega de materiales.", 1),
        ("SOC_ATN", "SOC", "Atención a Inquietudes",    "Gestión de dudas o quejas.", 2),
        # Acompañamiento Institucional
        ("AIN_TEC", "AIN", "Técnico",    "Supervisión de obras/trazos.", 0),
        ("AIN_SOC", "AIN", "Social",     "Seguimiento a compromisos.", 1),
        ("AIN_DOC", "AIN", "Documental", "Registro y evidencias oficiales.", 2),
    ]
    for sub_id, act_id, name, desc, _order in subcategories:
        _upsert(db, "cat_subcategories", "subcategory_id", sub_id, {
            "subcategory_id": sub_id,
            "activity_id": act_id,
            "name": name,
            "description": desc,
            "version_id": VERSION_ID,
            "is_active": True,
            "updated_at": _NOW,
        })
    print(f"[OK] cat_subcategories: {len(subcategories)} registros")

    # 5. cat_purposes ─────────────────────────────────────────────────────────
    purposes = [
        # Caminamiento
        ("AFEC_VER_CAM",  "CAM", "CAM_DDV", "Verificación de afectaciones"),
        ("DDV_MAR_CAM",   "CAM", "CAM_MAR", "Marcaje o actualización de DDV / trazo"),
        ("ACC_ALT_CAM",   "CAM", "CAM_ACC", "Análisis de accesos y pasos alternos"),
        # Reunión
        ("PRS_GEN_REU",   "REU", "REU_INF", "Presentación general del proyecto"),
        ("DOC_CONV_REU",  "REU", "REU_INF", "Entrega de documentación / Convocatorias"),
        ("SOC_CON_REU",   "REU", "REU_SEG", "Atención a inconformidades o conflictos"),
        ("CONC_FER_REU",  "REU", "REU_TEC", "Coordinación con concesionarios ferroviarios"),
        ("COOR_INST_REU", "REU", "REU_TEC", "Coordinación institucional"),
        ("PLAN_ACT_REU",  "REU", "REU_SEG", "Planeación de nuevas actividades"),
        ("SEG_DOC_REU",   "REU", "REU_SEG", "Seguimiento administrativo / documental"),
        # Asamblea Protocolizada
        ("PRS_GEN_ASP",  "ASP", "ASP_1AP", "Presentación general del proyecto"),
        ("DOC_CONV_ASP", "ASP", "ASP_1AP", "Entrega de documentación / Convocatorias"),
        ("COP_FIR_ASP",  "ASP", "ASP_2AP", "Obtención de anuencia o firma de COP"),
        ("AVAL_VAL_ASP", "ASP", None,      "Validación o ajuste de avalúos"),
    ]
    for pur_id, act_id, sub_id, name in purposes:
        _upsert(db, "cat_purposes", "purpose_id", pur_id, {
            "purpose_id": pur_id,
            "activity_id": act_id,
            "subcategory_id": sub_id,
            "name": name,
            "version_id": VERSION_ID,
            "is_active": True,
            "updated_at": _NOW,
        })
    print(f"[OK] cat_purposes: {len(purposes)} registros")

    # 6. cat_topics ───────────────────────────────────────────────────────────
    topics = [
        ("TOP_GAL",  "Tecnico",        "Gálibos ferroviarios",     "Revisión de alturas/ancho de estructuras"),
        ("TOP_ACC",  "Tecnico",        "Accesos y pasos vehiculares","Conectividad vial"),
        ("TOP_TEN",  "Social/Agrario", "Tenencia de la tierra",    "Propiedad/posesión"),
        ("TOP_AVA",  "Social/Agrario", "Avalúos y pagos",          "Valor m² y compensación"),
        ("TOP_ARB",  "Ambiental",      "Arbolado / vegetación",    "Tala/reforestación"),
        ("TOP_INAH", "Patrimonial",    "Sitios arqueológicos / INAH","Protección patrimonial"),
        ("TOP_CONS", "Indigena",       "Consulta previa",          "Derecho de participación"),
    ]
    for top_id, tipo, name, desc in topics:
        _upsert(db, "cat_topics", "topic_id", top_id, {
            "topic_id": top_id,
            "type": tipo,
            "name": name,
            "description": desc,
            "version_id": VERSION_ID,
            "is_active": True,
            "updated_at": _NOW,
        })
    print(f"[OK] cat_topics: {len(topics)} registros")

    # 7. rel_activity_topics ──────────────────────────────────────────────────
    rels = [
        ("CAM", "TOP_GAL"),
        ("CAM", "TOP_ACC"),
        ("CAM", "TOP_TEN"),
        ("CAM", "TOP_AVA"),
        ("CAM", "TOP_ARB"),
        ("CAM", "TOP_INAH"),
        ("REU", "TOP_GAL"),
        ("REU", "TOP_AVA"),
        ("ASP", "TOP_TEN"),
        ("ASP", "TOP_AVA"),
        ("CIN", "TOP_CONS"),
        ("SOC", "TOP_TEN"),
        ("AIN", "TOP_GAL"),
        ("AIN", "TOP_ACC"),
    ]
    for act_id, top_id in rels:
        _upsert2(db, "rel_activity_topics", "activity_id", "topic_id", {
            "activity_id": act_id,
            "topic_id": top_id,
            "version_id": VERSION_ID,
            "is_active": True,
            "updated_at": _NOW,
        })
    print(f"[OK] rel_activity_topics: {len(rels)} registros")

    # 8. cat_results ──────────────────────────────────────────────────────────
    results = [
        ("R01", "Ejecución regular o exitosa",                       "Actividad realizada conforme al programa"),
        ("R02", "Ejecución regular o exitosa",                       "Asamblea con quórum legal y acuerdos aprobados"),
        ("R03", "Casos sociales o administrativos",                  "Sin quórum / segunda convocatoria programada"),
        ("R04", "Ejecución regular o exitosa",                       "Firma de acta informativa / COP"),
        ("R05", "Ejecución regular o exitosa",                       "Se obtienen anuencias / permisos"),
        ("R06", "Reajustes o cambios técnicos",                      "Se ajusta superficie o valor de afectación"),
        ("R07", "Reajustes o cambios técnicos",                      "Nuevas afectaciones identificadas"),
        ("R08", "Reajustes o cambios técnicos",                      "Solicitud canalizada a dependencia"),
        ("R09", "Seguimiento y compromisos interinstitucionales",    "Se acuerda mantenimiento o intervención"),
        ("R10", "Casos sociales o administrativos",                  "Proceso en revisión / sin acuerdo final"),
        ("R11", "Casos sociales o administrativos",                  "Sin acuerdos / reunión informativa únicamente"),
        ("R12", "Seguimiento y compromisos interinstitucionales",    "Se programa nueva reunión o seguimiento"),
    ]
    for res_id, cat, name in results:
        _upsert(db, "cat_results", "result_id", res_id, {
            "result_id": res_id,
            "name": name,
            "category": cat,
            "version_id": VERSION_ID,
            "is_active": True,
            "updated_at": _NOW,
        })
    print(f"[OK] cat_results: {len(results)} registros")

    # 9. cat_attendees ────────────────────────────────────────────────────────
    attendees = [
        ("AST1", "Dependencia", "ARTF",           "Agencia Reguladora del Transporte Ferroviario"),
        ("AST2", "Dependencia", "SEDATU",          "Secretaría de Desarrollo Agrario, Territorial y Urbano"),
        ("AST3", "Dependencia", "Defensa (SEDENA)","Secretaría de la Defensa Nacional"),
    ]
    for att_id, tipo, name, desc in attendees:
        _upsert(db, "cat_attendees", "attendee_id", att_id, {
            "attendee_id": att_id,
            "type": tipo,
            "name": name,
            "description": desc,
            "version_id": VERSION_ID,
            "is_active": True,
            "updated_at": _NOW,
        })
    print(f"[OK] cat_attendees: {len(attendees)} registros")

    db.commit()
    print("\n[OK] Effective catalog TMQ v2.0.0 seeded successfully!\n")
