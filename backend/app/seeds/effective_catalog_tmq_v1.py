"""Seed del catálogo efectivo (System B) para proyecto TMQ v1.

Sistema separado de catalog_versions (admin).  Provee los datos que la app
móvil descarga al hacer GET /catalog/effective (actividades, subcategorías,
propósitos, temas, resultados y asistentes).

Las actividades coinciden con catalog_tmq_v1.py (admin) para mantener coherencia.
IDs son texto estable (no UUID) — se pueden referenciar desde el wizard.
"""
from datetime import datetime, timezone
from sqlalchemy import text
from sqlalchemy.orm import Session

VERSION_ID = "tmq-v1.0.0"
PROJECT_ID = "TMQ"
_NOW = datetime.now(timezone.utc)


# ─── helpers ──────────────────────────────────────────────────────────────────

def _upsert(db: Session, table: str, pk_col: str, pk_val: str, row: dict) -> None:
    """INSERT ... ON CONFLICT DO UPDATE para idempotencia."""
    cols = list(row.keys())
    vals = list(row.values())
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
    """Idem para tablas con PK compuesta de 2 columnas."""
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
    print("\n=== Seeding Effective Catalog TMQ v1.0.0 ===\n")

    # 1. catalog_version ──────────────────────────────────────────────────────
    # Marcar todas las versiones existentes como no-current antes de insertar.
    db.execute(text("UPDATE catalog_version SET is_current = false WHERE is_current = true"))
    _upsert(db, "catalog_version", "version_id", VERSION_ID, {
        "version_id": VERSION_ID,
        "is_current": True,
        "created_at": _NOW,
        "changelog": "Catálogo inicial para Transmisión Mantaro-Quencoro",
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
        ("act_insp_civil",  "Inspección Civil",       "Inspección de obras civiles: cimentaciones, estructuras, torres", 1),
        ("act_asamblea",    "Asamblea Informativa",    "Reuniones con comunidades y stakeholders", 2),
        ("act_recorrido",   "Recorrido de Línea",      "Recorrido de verificación de servidumbre y derecho de vía", 3),
        ("act_gestion",     "Gestión Social",          "Atención a solicitudes y consultas de la población", 4),
        ("act_capacitacion","Capacitación",            "Capacitaciones al personal de campo y contratistas", 5),
    ]
    for act_id, name, desc, _ in activities:
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
        # Inspección Civil
        ("sub_ic_cimentacion",  "act_insp_civil",  "Cimentación",           "Revisión de fundaciones y anclajes"),
        ("sub_ic_estructura",   "act_insp_civil",  "Estructura Metálica",   "Torres y soportes de transmisión"),
        ("sub_ic_tierra",       "act_insp_civil",  "Puesta a Tierra",       "Sistemas de puesta a tierra"),
        ("sub_ic_conductor",    "act_insp_civil",  "Conductor",             "Estado del conductor eléctrico"),
        # Asamblea
        ("sub_asm_socializacion","act_asamblea",   "Socialización",         "Presentación del proyecto a la comunidad"),
        ("sub_asm_consulta",    "act_asamblea",    "Consulta Previa",       "Proceso de consulta con comunidades"),
        # Recorrido
        ("sub_rec_servidumbre", "act_recorrido",   "Servidumbre",           "Verificación de fajas de servidumbre"),
        ("sub_rec_dv",          "act_recorrido",   "Derecho de Vía",        "Control del derecho de vía"),
        # Gestión social
        ("sub_ges_solicitud",   "act_gestion",     "Solicitud Ciudadana",   "Atención de solicitudes de vecinos"),
        ("sub_ges_queja",       "act_gestion",     "Quejas y Reclamos",     "Registro y seguimiento de quejas"),
        # Capacitación
        ("sub_cap_seguridad",   "act_capacitacion","Seguridad Industrial",  "SSOMA y prevención de accidentes"),
        ("sub_cap_ambiental",   "act_capacitacion","Gestión Ambiental",     "Manejo ambiental en campo"),
        ("sub_cap_proc",        "act_capacitacion","Procedimientos",        "Procedimientos operativos estándar"),
    ]
    for sub_id, act_id, name, desc in subcategories:
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
    # (activity_id, subcategory_id | None, purpose_id, name)
    purposes = [
        ("act_insp_civil", "sub_ic_cimentacion", "pur_ic_ci_insp",   "Inspección Rutinaria"),
        ("act_insp_civil", "sub_ic_cimentacion", "pur_ic_ci_repara",  "Verificación Post-Reparación"),
        ("act_insp_civil", "sub_ic_estructura",  "pur_ic_est_vert",  "Verificación de Verticalidad"),
        ("act_insp_civil", "sub_ic_estructura",  "pur_ic_est_corr",  "Control de Corrosión"),
        ("act_insp_civil", "sub_ic_tierra",      "pur_ic_tie_medir", "Medición de Resistencia"),
        ("act_insp_civil", "sub_ic_conductor",   "pur_ic_con_flec",  "Inspección de Flecha"),
        ("act_asamblea",   "sub_asm_socializacion","pur_asm_soc_ini", "Reunión de Inicio"),
        ("act_asamblea",   "sub_asm_socializacion","pur_asm_soc_seg", "Seguimiento de Compromisos"),
        ("act_asamblea",   "sub_asm_consulta",   "pur_asm_con_pi",   "Consulta Previa Indígena"),
        ("act_recorrido",  "sub_rec_servidumbre", "pur_rec_ser_men",  "Mantenimiento de Faja"),
        ("act_recorrido",  "sub_rec_dv",         "pur_rec_dv_lib",   "Verificación de Libre Acceso"),
        ("act_gestion",    "sub_ges_solicitud",  "pur_ges_sol_aten", "Atención Directa"),
        ("act_gestion",    "sub_ges_queja",      "pur_ges_que_reg",  "Registro de Queja"),
        ("act_capacitacion","sub_cap_seguridad",  "pur_cap_seg_ind",  "Inducción SSOMA"),
        ("act_capacitacion","sub_cap_ambiental",  "pur_cap_amb_mej",  "Mejores Prácticas Ambientales"),
        ("act_capacitacion","sub_cap_proc",       "pur_cap_pro_eoc",  "Entrenamiento en Campo"),
    ]
    for act_id, sub_id, pur_id, name in purposes:
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
        ("top_seg_ind",  "seguridad",   "Seguridad Industrial",       "SSOMA, EPP, riesgos eléctricos"),
        ("top_med_amb",  "ambiental",   "Gestión Ambiental",          "Manejo de residuos, flora, fauna"),
        ("top_rel_com",  "social",      "Relaciones Comunitarias",    "Comunicación y compromisos sociales"),
        ("top_cal_tec",  "técnico",     "Calidad Técnica",            "Estándares técnicos de líneas de transmisión"),
        ("top_der_hum",  "social",      "Derechos Humanos",           "DDHH y consulta previa"),
        ("top_cap_per",  "formación",   "Capacitación al Personal",   "Desarrollo de competencias técnicas"),
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
        ("act_insp_civil",   "top_seg_ind"),
        ("act_insp_civil",   "top_cal_tec"),
        ("act_insp_civil",   "top_med_amb"),
        ("act_asamblea",     "top_rel_com"),
        ("act_asamblea",     "top_der_hum"),
        ("act_recorrido",    "top_seg_ind"),
        ("act_recorrido",    "top_med_amb"),
        ("act_gestion",      "top_rel_com"),
        ("act_gestion",      "top_der_hum"),
        ("act_capacitacion", "top_cap_per"),
        ("act_capacitacion", "top_seg_ind"),
        ("act_capacitacion", "top_med_amb"),
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
        ("res_conforme",    "Conforme",           "inspeccion", None),
        ("res_no_conf",     "No Conforme",         "inspeccion", "alta"),
        ("res_observacion", "Observación",         "inspeccion", "media"),
        ("res_pendiente",   "Pendiente de Cierre", "inspeccion", "baja"),
        ("res_acuerdo",     "Acuerdo Alcanzado",   "social",     None),
        ("res_sin_acuerdo", "Sin Acuerdo",         "social",     "media"),
        ("res_completada",  "Capacitación Completa","formacion",  None),
    ]
    for res_id, name, cat, sev in results:
        _upsert(db, "cat_results", "result_id", res_id, {
            "result_id": res_id,
            "name": name,
            "category": cat,
            "severity_default": sev,
            "version_id": VERSION_ID,
            "is_active": True,
            "updated_at": _NOW,
        })
    print(f"[OK] cat_results: {len(results)} registros")

    # 9. cat_attendees ────────────────────────────────────────────────────────
    attendees = [
        ("att_inspector",  "tecnico",  "Inspector Técnico",       "Profesional de inspección en campo"),
        ("att_supervisor", "tecnico",  "Supervisor de Campo",     "Responsable del equipo de campo"),
        ("att_jefe_proy",  "gestion",  "Jefe de Proyecto",        "Responsable general del proyecto"),
        ("att_comunero",   "social",   "Representante Comunal",   "Representante de la comunidad"),
        ("att_autoridad",  "social",   "Autoridad Local",         "Alcalde, teniente o similar"),
        ("att_contratista","tecnico",  "Contratista",             "Personal de empresa contratada"),
        ("att_ssoma",      "seguridad","Especialista SSOMA",      "Responsable de seguridad y medio ambiente"),
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
    print("\n[OK] Effective catalog TMQ v1.0.0 seeded successfully!\n")
