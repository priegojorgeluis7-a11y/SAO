#!/usr/bin/env python3
"""
Batch script to generate PDF reports for approved activities that are missing them.

This script:
1. Finds all approved activities WITHOUT report_generated_at
2. Generates a professional PDF report for each activity
3. Uploads the PDF to GCS as evidence
4. Marks the activity as report_generated in Firestore

Usage:
    python3 backend/scripts/batch_generate_reports.py [--dry-run] [--project PROJECT_ID]
    
    --dry-run       Only show what would be done, don't modify anything
    --project       Only process a specific project (e.g., TQI, TSNL, TMQ, TAP, TQSL)
    --output-dir    Directory to save PDFs locally (default: ./generated_reports)
"""

import argparse
import logging
import os
import sys
from datetime import datetime, timezone
from uuid import uuid4

from fpdf import FPDF
from google.cloud import firestore, storage

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("batch_reports")

DRY_RUN = False
PROJECT_FILTER = None
OUTPUT_DIR = "generated_reports"

FIRESTORE_PROJECT = "sao-prod-488416"
FIRESTORE_DATABASE = "(default)"
GCS_BUCKET = "sao-evidences-488416"


def get_client():
    return firestore.Client(project=FIRESTORE_PROJECT, database=FIRESTORE_DATABASE)


def get_storage_client():
    return storage.Client(project=FIRESTORE_PROJECT)


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _fmt_date(dt) -> str:
    if isinstance(dt, datetime):
        return dt.strftime("%d/%m/%Y %H:%M")
    return str(dt)[:19] if dt else ""


def _safe_str(value, default="") -> str:
    if value is None:
        return default
    s = str(value).strip()
    return s if s else default


def _extract_nested(doc: dict, keys: list) -> str:
    """Extract a string value from nested dicts using a list of keys."""
    wp = doc.get("wizard_payload") or {}
    if not isinstance(wp, dict):
        wp = {}
    for key in keys:
        val = doc.get(key)
        if val and isinstance(val, str) and val.strip():
            return val.strip()
        val = wp.get(key)
        if val and isinstance(val, str) and val.strip():
            return val.strip()
        ctx = wp.get("context") or {}
        if isinstance(ctx, dict):
            val = ctx.get(key)
            if val and isinstance(val, str) and val.strip():
                return val.strip()
        loc = wp.get("location") or {}
        if isinstance(loc, dict):
            val = loc.get(key)
            if val and isinstance(val, str) and val.strip():
                return val.strip()
    return ""


def _extract_name_from_id(doc: dict, field: str) -> str:
    """Extract the 'name' from a nested {id, name} object in wizard_payload."""
    wp = doc.get("wizard_payload") or {}
    if not isinstance(wp, dict):
        return ""
    entry = wp.get(field)
    if isinstance(entry, dict):
        name = str(entry.get("name") or "").strip()
        if name and not name.upper().startswith("CUSTOM_"):
            return name
    elif isinstance(entry, str) and entry.strip():
        if not entry.upper().startswith("CUSTOM_"):
            return entry.strip()
    return ""


def _extract_list_names(doc: dict, field: str) -> list[str]:
    """Extract list of names from a list of {id, name} objects in wizard_payload."""
    wp = doc.get("wizard_payload") or {}
    if not isinstance(wp, dict):
        return []
    entries = wp.get(field)
    if not isinstance(entries, list):
        return []
    names = []
    for entry in entries:
        if isinstance(entry, dict):
            name = str(entry.get("name") or "").strip()
            if name and not name.upper().startswith("CUSTOM_"):
                names.append(name)
        elif isinstance(entry, str) and entry.strip():
            if not entry.upper().startswith("CUSTOM_"):
                names.append(entry.strip())
    return names


def _get_user_name(client, user_id: str) -> str:
    """Resolve a user ID to a display name."""
    if not user_id:
        return ""
    snap = client.collection("users").document(user_id).get()
    if snap.exists:
        u = snap.to_dict() or {}
        return _safe_str(
            u.get("full_name") or u.get("fullName") or u.get("display_name") or u.get("name") or u.get("email")
        )
    return user_id


def _get_front_name(client, front_id: str) -> str:
    """Resolve a front ID to a name."""
    if not front_id:
        return ""
    snap = client.collection("fronts").document(front_id).get()
    if snap.exists:
        return _safe_str((snap.to_dict() or {}).get("name"))
    return front_id


def _get_evidence_list(client, activity_uuid: str) -> list[dict]:
    """Get evidence details for an activity."""
    evidences = []
    for doc in client.collection("evidences").where("activity_id", "==", activity_uuid).stream():
        ev = doc.to_dict() or {}
        gcs_path = str(ev.get("gcs_path") or ev.get("storage_path") or ev.get("object_path") or "").strip()
        if gcs_path:
            evidences.append({
                "id": doc.id,
                "type": str(ev.get("evidence_type") or ev.get("type") or "PHOTO"),
                "description": str(ev.get("description") or ev.get("caption") or ""),
                "gcs_path": gcs_path,
                "uploaded_at": _fmt_date(ev.get("uploaded_at") or ev.get("created_at")),
            })
    return evidences


class ActivityReportPDF(FPDF):
    """PDF report generator for SAO activities."""

    def header(self):
        if self.page_no() == 1:
            return
        self.set_font("Helvetica", "B", 8)
        self.set_text_color(100, 100, 100)
        self.cell(0, 6, "SAO - Sistema de Administracion Operativa", align="L")
        self.ln(1)
        self.set_draw_color(200, 200, 200)
        self.line(10, self.get_y(), 200, self.get_y())
        self.ln(4)

    def footer(self):
        self.set_y(-20)
        self.set_font("Helvetica", "I", 7)
        self.set_text_color(150, 150, 150)
        self.cell(0, 10, f"Pagina {self.page_no()}/{{nb}}", align="C")

    def section_title(self, title: str):
        self.set_font("Helvetica", "B", 11)
        self.set_text_color(30, 60, 120)
        self.set_fill_color(240, 245, 255)
        self.cell(0, 8, f"  {title}", fill=True, ln=True)
        self.ln(2)

    def field_row(self, label: str, value: str):
        if not value:
            return
        self.set_font("Helvetica", "B", 9)
        self.set_text_color(60, 60, 60)
        label_w = self.get_string_width(f"{label}: ") + 2
        self.cell(label_w, 6, f"{label}: ")
        self.set_font("Helvetica", "", 9)
        self.set_text_color(30, 30, 30)
        remaining_w = 190 - label_w
        if self.get_string_width(value) > remaining_w:
            self.cell(label_w, 6, "")
            self.set_x(10 + label_w)
            self.multi_cell(remaining_w, 5, value)
        else:
            self.cell(0, 6, value, ln=True)

    def multi_field(self, label: str, value: str):
        if not value:
            return
        self.set_font("Helvetica", "B", 9)
        self.set_text_color(60, 60, 60)
        self.cell(0, 6, f"{label}:", ln=True)
        self.set_font("Helvetica", "", 9)
        self.set_text_color(30, 30, 30)
        self.set_x(15)
        self.multi_cell(175, 5, value)
        self.ln(1)


def generate_activity_pdf(activity: dict, client) -> bytes:
    """Generate a professional PDF report for a single activity."""
    pdf = ActivityReportPDF()
    pdf.alias_nb_pages()

    wp = activity.get("wizard_payload") or {}
    if not isinstance(wp, dict):
        wp = {}

    # ── Extract fields ──────────────────────────────────────────────────────
    activity_uuid = _safe_str(activity.get("uuid"))
    project_id = _safe_str(activity.get("project_id"))
    title = _safe_str(activity.get("title")) or _safe_str(activity.get("activity_type_code"))
    activity_type = _safe_str(activity.get("activity_type_code"))

    if activity_type.upper().startswith("CUSTOM_"):
        wp_act = wp.get("activity") if isinstance(wp, dict) else None
        if isinstance(wp_act, dict):
            activity_type = _safe_str(wp_act.get("name")) or activity_type

    front_id = _safe_str(activity.get("front_id"))
    front_name = _get_front_name(client, front_id)
    if not front_name:
        front_name = _extract_nested(activity, ["front_name", "front", "frente"])

    assigned_user_id = _safe_str(activity.get("assigned_to_user_id"))
    assigned_name = _get_user_name(client, assigned_user_id)

    created_by_id = _safe_str(activity.get("created_by_user_id"))
    created_by_name = _get_user_name(client, created_by_id)

    municipality = _extract_nested(activity, ["municipio", "municipality"])
    state = _extract_nested(activity, ["estado", "state"])
    colony = _extract_nested(activity, ["colony", "colonia"])

    pk_start = activity.get("pk_start")
    pk_end = activity.get("pk_end")
    pk_label = ""
    if pk_start is not None:
        try:
            n = int(pk_start)
            pk_label = f"{n // 1000}+{n % 1000:03d}"
        except (TypeError, ValueError):
            pk_label = str(pk_start)
    if pk_end is not None and pk_end != pk_start:
        try:
            n = int(pk_end)
            pk_label += f" - {n // 1000}+{n % 1000:03d}"
        except (TypeError, ValueError):
            pk_label += f" - {pk_end}"

    lat = activity.get("latitude")
    lon = activity.get("longitude")
    gps_str = ""
    if lat and lon:
        try:
            lat_f = float(lat)
            lon_f = float(lon)
            gps_str = f"{lat_f:.6f}, {lon_f:.6f}"
        except (TypeError, ValueError):
            gps_str = f"{lat}, {lon}"

    created_at = _fmt_date(activity.get("created_at"))
    completed_at = _fmt_date(activity.get("completed_at") or activity.get("last_reviewed_at"))
    start_time = _extract_nested(activity, ["start_time", "hora_inicio", "started_at"])
    end_time = _extract_nested(activity, ["end_time", "hora_fin", "finished_at"])

    subcategory = _extract_name_from_id(activity, "subcategory")
    purpose = _extract_name_from_id(activity, "purpose")
    result = _extract_name_from_id(activity, "result")
    topics = _extract_list_names(activity, "topics")
    attendees = _extract_list_names(activity, "attendees")

    detail = _extract_nested(activity, ["detail", "description", "descripcion", "minuta", "notes"])
    agreements = _extract_nested(activity, ["agreements", "acuerdos", "commitments"])

    evidences = _get_evidence_list(client, activity_uuid)

    # ── Build PDF ───────────────────────────────────────────────────────────
    pdf.add_page()

    # Title bar
    pdf.set_fill_color(30, 60, 120)
    pdf.rect(0, 0, 210, 40, "F")
    pdf.set_y(8)
    pdf.set_font("Helvetica", "B", 18)
    pdf.set_text_color(255, 255, 255)
    pdf.cell(0, 10, "REPORTE OPERATIVO", align="C", ln=True)
    pdf.set_font("Helvetica", "", 11)
    pdf.cell(0, 8, f"Proyecto: {project_id}", align="C", ln=True)
    pdf.set_font("Helvetica", "I", 9)
    pdf.cell(0, 6, f"Generado: {_fmt_date(_utc_now())}", align="C", ln=True)

    pdf.ln(10)

    # Activity info box
    pdf.set_fill_color(245, 247, 250)
    pdf.set_draw_color(200, 210, 230)
    y_start = pdf.get_y()
    pdf.rect(10, y_start, 190, 55, "DF")

    pdf.set_xy(15, y_start + 4)
    pdf.set_font("Helvetica", "B", 14)
    pdf.set_text_color(30, 60, 120)
    pdf.cell(0, 8, title, ln=True)

    pdf.set_x(15)
    pdf.field_row("Tipo de Actividad", activity_type)
    pdf.set_x(15)
    pdf.field_row("Folio", activity_uuid[:13] if len(activity_uuid) > 13 else activity_uuid)
    pdf.set_x(15)
    pdf.field_row("Frente", front_name)
    pdf.set_x(15)
    pdf.field_row("Responsable", assigned_name)
    pdf.set_x(15)
    pdf.field_row("PK", pk_label)

    pdf.ln(8)

    # Section: Datos de la Actividad
    pdf.section_title("Datos de la Actividad")
    pdf.field_row("Fecha de Creacion", created_at)
    pdf.field_row("Fecha de Finalizacion", completed_at)
    if start_time:
        pdf.field_row("Hora de Inicio", start_time)
    if end_time:
        pdf.field_row("Hora de Fin", end_time)
    pdf.field_row("Creado por", created_by_name)
    if municipality:
        pdf.field_row("Municipio", municipality)
    if state:
        pdf.field_row("Estado", state)
    if colony:
        pdf.field_row("Colonia", colony)
    if gps_str:
        pdf.field_row("Coordenadas GPS", gps_str)
    pdf.ln(2)

    # Section: Clasificacion
    pdf.section_title("Clasificacion")
    if subcategory:
        pdf.field_row("Subcategoria", subcategory)
    if purpose:
        pdf.multi_field("Proposito", purpose)
    if topics:
        pdf.field_row("Temas Tratados", ", ".join(topics))
    if attendees:
        pdf.field_row("Asistentes / Involucrados", ", ".join(attendees))
    if result:
        pdf.field_row("Resultado", result)
    pdf.ln(2)

    # Section: Desarrollo / Notas
    pdf.section_title("Desarrollo / Notas")
    if detail:
        pdf.multi_field("", detail)
    else:
        pdf.set_font("Helvetica", "I", 9)
        pdf.set_text_color(150, 150, 150)
        pdf.cell(0, 6, "Sin descripcion registrada.", ln=True)
    pdf.ln(2)

    # Section: Acuerdos
    if agreements:
        pdf.section_title("Acuerdos / Compromisos")
        pdf.multi_field("", agreements)
        pdf.ln(2)

    # Section: Evidencias
    if evidences:
        pdf.section_title(f"Evidencias ({len(evidences)})")
        for i, ev in enumerate(evidences, 1):
            pdf.set_font("Helvetica", "", 8)
            pdf.set_text_color(60, 60, 60)
            ev_type = "PDF" if ev["type"].upper() in ("PDF", "DOCUMENT") else ev["type"]
            desc = ev["description"][:80] if ev["description"] else "Sin descripcion"
            pdf.cell(0, 5, f"  {i}. [{ev_type}] {desc}", ln=True)
            pdf.set_x(15)
            pdf.set_font("Helvetica", "I", 7)
            pdf.set_text_color(120, 120, 120)
            pdf.cell(0, 4, f"     Subido: {ev['uploaded_at']}", ln=True)
        pdf.ln(2)

    # Section: Firma / Validacion
    pdf.ln(5)
    pdf.set_draw_color(180, 180, 180)
    y_line = pdf.get_y()
    pdf.line(30, y_line, 90, y_line)
    pdf.line(120, y_line, 180, y_line)
    pdf.ln(2)
    pdf.set_font("Helvetica", "", 8)
    pdf.set_text_color(100, 100, 100)
    pdf.cell(0, 5, "Elaboro", align="C", ln=True)
    pdf.ln(8)
    pdf.cell(0, 5, "Reviso / Aprobo", align="C", ln=True)

    # Footer note
    pdf.ln(10)
    pdf.set_font("Helvetica", "I", 7)
    pdf.set_text_color(150, 150, 150)
    pdf.cell(0, 4, f"Reporte generado automaticamente por SAO - {_fmt_date(_utc_now())}", align="C", ln=True)
    pdf.cell(0, 4, f"UUID: {activity_uuid}", align="C", ln=True)

    # Return bytes (fpdf2 returns bytearray, convert to bytes)
    result = pdf.output()
    if isinstance(result, bytearray):
        return bytes(result)
    return result


def upload_to_gcs(storage_client, bucket_name: str, blob_path: str, pdf_bytes: bytes) -> str:
    """Upload PDF bytes to GCS and return the gsutil path."""
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(blob_path)
    blob.upload_from_string(pdf_bytes, content_type="application/pdf")
    logger.info(f"  -> Uploaded to gs://{bucket_name}/{blob_path}")
    return f"gs://{bucket_name}/{blob_path}"


def mark_report_generated(client, activity_uuid: str, doc_id: str):
    """Mark the activity as having its report generated."""
    now = _utc_now()
    ref = client.collection("activities").document(doc_id)
    ref.set({
        "report_generated_at": now,
        "updated_at": now,
        "sync_version": firestore.Increment(1),
    }, merge=True)
    logger.info(f"  -> Marked report_generated_at on {activity_uuid[:8]}")


def create_evidence_record(client, activity_uuid: str, gcs_path: str, pdf_bytes: bytes):
    """Create an evidence record in Firestore for the generated PDF."""
    now = _utc_now()
    evidence_id = str(uuid4())
    client.collection("evidences").document(evidence_id).set({
        "activity_id": activity_uuid,
        "evidence_type": "PDF",
        "type": "PDF",
        "mime_type": "application/pdf",
        "gcs_path": gcs_path,
        "storage_path": gcs_path,
        "object_path": gcs_path,
        "original_file_name": f"reporte_{activity_uuid[:8]}.pdf",
        "file_size": len(pdf_bytes),
        "description": "Reporte operativo generado automaticamente",
        "caption": "Reporte PDF",
        "uploaded_at": now,
        "created_at": now,
        "uploaded_by": "batch-script",
        "created_by_user_id": "batch-script",
        "uploader_name": "Sistema SAO",
    })
    logger.info(f"  -> Created evidence record {evidence_id[:8]} for {activity_uuid[:8]}")
    return evidence_id


def main():
    global DRY_RUN, PROJECT_FILTER, OUTPUT_DIR

    parser = argparse.ArgumentParser(description="Batch generate PDF reports for approved activities")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done without making changes")
    parser.add_argument("--project", type=str, default=None, help="Only process a specific project (e.g., TQI)")
    parser.add_argument("--output-dir", type=str, default="generated_reports", help="Directory to save PDFs locally")
    args = parser.parse_args()

    DRY_RUN = args.dry_run
    PROJECT_FILTER = args.project.strip().upper() if args.project else None
    OUTPUT_DIR = args.output_dir

    if DRY_RUN:
        logger.info("RUNNING IN DRY-RUN MODE - No changes will be made")

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    client = get_client()
    storage_client = get_storage_client() if not DRY_RUN else None

    # Step 1: Find approved activities missing reports
    logger.info("=" * 60)
    logger.info("STEP 1: Finding approved activities missing PDF reports")
    logger.info("=" * 60)

    missing = []
    total_approved = 0
    total_with_report = 0

    for doc in client.collection("activities").stream():
        d = doc.to_dict() or {}
        if d.get("deleted_at"):
            continue

        decision = str(d.get("review_decision") or "").upper()
        if decision not in ("APPROVE", "APPROVE_EXCEPTION"):
            continue

        project_id = str(d.get("project_id") or "").strip().upper()
        if PROJECT_FILTER and project_id != PROJECT_FILTER:
            continue

        total_approved += 1

        if d.get("report_generated_at"):
            total_with_report += 1
            continue

        activity_uuid = str(d.get("uuid") or doc.id)
        missing.append({
            "uuid": activity_uuid,
            "doc_id": doc.id,
            "project_id": project_id,
            "title": str(d.get("title") or "(sin titulo)"),
            "activity_type": str(d.get("activity_type_code") or ""),
            "created_at": d.get("created_at"),
            "payload": d,
        })

    logger.info(f"Total approved activities: {total_approved}")
    logger.info(f"  With report already: {total_with_report}")
    logger.info(f"  Missing report: {len(missing)}")

    if not missing:
        logger.info("No activities need PDF reports. All done!")
        return

    by_project = {}
    for act in missing:
        pid = act["project_id"]
        if pid not in by_project:
            by_project[pid] = []
        by_project[pid].append(act)

    for pid, acts in sorted(by_project.items()):
        logger.info(f"  {pid}: {len(acts)} activities missing reports")
        for a in acts:
            logger.info(f"    [{a['uuid'][:8]}] {a['title'][:50]} | type={a['activity_type']}")

    # Step 2: Generate PDFs
    logger.info("")
    logger.info("=" * 60)
    logger.info("STEP 2: Generating PDF reports")
    logger.info("=" * 60)

    generated = 0
    errors = 0
    uploaded = 0
    marked = 0

    for act in missing:
        activity_uuid = act["uuid"]
        project_id = act["project_id"]
        title = act["title"]
        doc_id = act["doc_id"]
        payload = act["payload"]

        logger.info(f"  Generating PDF for [{activity_uuid[:8]}] {title[:40]}...")

        try:
            pdf_bytes = generate_activity_pdf(payload, client)
            file_size_kb = len(pdf_bytes) / 1024
            logger.info(f"    PDF generated: {file_size_kb:.1f} KB")

            safe_title = "".join(c if c.isalnum() or c in " _-" else "_" for c in title)[:40]
            filename = f"{project_id}_{activity_uuid[:8]}_{safe_title}.pdf"
            local_path = os.path.join(OUTPUT_DIR, filename)

            if not DRY_RUN:
                with open(local_path, "wb") as f:
                    f.write(pdf_bytes)
                logger.info(f"    Saved to: {local_path}")

                blob_path = f"reports/{project_id}/{activity_uuid[:8]}/{filename}"
                gcs_path = upload_to_gcs(storage_client, GCS_BUCKET, blob_path, pdf_bytes)
                uploaded += 1

                create_evidence_record(client, activity_uuid, gcs_path, pdf_bytes)

                mark_report_generated(client, activity_uuid, doc_id)
                marked += 1
            else:
                logger.info(f"    WOULD save to: {os.path.join(OUTPUT_DIR, filename)}")
                logger.info(f"    WOULD upload to GCS and create evidence")

            generated += 1

        except Exception as e:
            logger.error(f"    ERROR generating PDF for [{activity_uuid[:8]}]: {e}")
            errors += 1

    # Summary
    logger.info("")
    logger.info("=" * 60)
    logger.info("SUMMARY")
    logger.info("=" * 60)
    logger.info(f"  Total missing reports: {len(missing)}")
    logger.info(f"  PDFs generated: {generated}")
    logger.info(f"  Uploaded to GCS: {uploaded}")
    logger.info(f"  Marked in Firestore: {marked}")
    logger.info(f"  Errors: {errors}")

    if DRY_RUN:
        logger.info("  (Dry run - no changes made)")

    print()
    print("=" * 58)
    print("  REPORTE DE GENERACION DE PDFs")
    print("=" * 58)
    if DRY_RUN:
        print("  MODO: DRY RUN")
    print(f"  Actividades sin reporte:  {len(missing):3d}")
    print(f"  PDFs generados:           {generated:3d}")
    print(f"  Subidos a GCS:            {uploaded:3d}")
    print(f"  Marcados en Firestore:    {marked:3d}")
    print(f"  Errores:                  {errors:3d}")
    print("=" * 58)
    print()


if __name__ == "__main__":
    main()
