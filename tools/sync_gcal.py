#!/usr/bin/env python3.11
"""
sync_gcal.py — Sincroniza actividades SAO → Google Calendar (por proyecto)

PREREQUISITO — Compartir calendarios con el Service Account:
  Email: sao-gcal-sync@sao-prod-488416.iam.gserviceaccount.com

  Para cada calendario Google:
  1. Abre el calendario en Google Calendar → ⋮ → "Configuración y uso compartido"
  2. En "Compartir con personas específicas" → Agregar personas
  3. Escribe el email del service account
  4. Elige permiso: "Realizar cambios en eventos"
  5. Guardar

  Calendarios:
    TSNL  → a339918f...@group.calendar.google.com
    TAP   → ad8f7ce5...@group.calendar.google.com
    TMQ   → 4bf1ac86...@group.calendar.google.com
    TQI   → 1c11b5ad...@group.calendar.google.com
    TQSL  → c571f348...@group.calendar.google.com
    TSLS  → 09ab7c62...@group.calendar.google.com

USO:
  cd /Users/jorgeluispriegocruz/Projects/SAO-clean
  /opt/homebrew/bin/python3.11 tools/sync_gcal.py

OPCIONES:
  --project TSNL     # solo sincroniza un proyecto
  --dry-run          # imprime eventos sin crearlos
  --clear            # borra todos los eventos SAO del calendario antes de insertar
"""

import argparse
import os
import sys
import json
import re
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

# ── Rutas ───────────────────────────────────────────────────────────────────
HERE = Path(__file__).parent
REPO = HERE.parent
BACKEND = REPO / "backend"
SA_KEY_FILE = HERE / "service_account_gcal.json"

sys.path.insert(0, str(BACKEND))
FIRESTORE_PROJECT = "sao-prod-488416"

# ── Calendarios por proyecto ─────────────────────────────────────────────────
CALENDAR_IDS: dict[str, str] = {
    "TSNL": "a339918f641bddf9a699709bbaf29a2bfa3dff0ee949e183ab87f3f3a966762c@group.calendar.google.com",
    "TAP":  "ad8f7ce51023bc661188eaaa86e5c23c1cb1dd9a14ef614b910dbcce7d810356@group.calendar.google.com",
    "TMQ":  "4bf1ac8600a9185c2ca60e2984a2499d02048769791c9372161876c2df47d291@group.calendar.google.com",
    "TQI":  "1c11b5ad4b6a4f73e9429d702750274c411e5e4e0ebacf5730579836e1d7e37b@group.calendar.google.com",
    "TQSL": "c571f348c3cc15ed07195ce4541df8b636ef44a61c889d6f882bf11097c14baa@group.calendar.google.com",
    "TSLS": "09ab7c6285b7d0d437c4528e5ce658d8f26bc42115c62e0e584bfda92d6da949@group.calendar.google.com",
}

ACTIVITY_LABELS: dict[str, str] = {
    "CAM": "Caminata",
    "REU": "Reunión",
    "ASP": "Aspecto",
    "CIN": "Cinta",
    "SOC": "Socio",
    "AIN": "Acción de Inspección",
}

STATE_EMOJI: dict[str, str] = {
    "COMPLETADA": "🟢",
    "EN_CURSO":   "🟡",
    "CANCELED":   "🔴",
    "PENDIENTE":  "🔵",
}

REVIEW_LABEL: dict[str, str] = {
    "APPROVE": "✅ Aprobada",
    "REJECT":  "❌ Rechazada",
    "PENDING": "⏳ En revisión",
}

ESTADO_ABBR: dict[str, str] = {
    "Aguascalientes": "Ags.", "Baja California": "B.C.", "Baja California Sur": "B.C.S.",
    "Campeche": "Camp.", "Chiapas": "Chis.", "Chihuahua": "Chih.",
    "Ciudad de México": "CDMX", "Coahuila de Zaragoza": "Coah.", "Colima": "Col.",
    "Durango": "Dgo.", "Guanajuato": "Gto.", "Guerrero": "Gro.", "Hidalgo": "Hgo.",
    "Jalisco": "Jal.", "México": "Méx.", "Estado de México": "Méx.",
    "Michoacán de Ocampo": "Mich.", "Morelos": "Mor.", "Nayarit": "Nay.",
    "Nuevo León": "N.L.", "Oaxaca": "Oax.", "Puebla": "Pue.", "Querétaro": "Qro.",
    "Quintana Roo": "Q.R.", "San Luis Potosí": "S.L.P.", "Sinaloa": "Sin.",
    "Sonora": "Son.", "Tabasco": "Tab.", "Tamaulipas": "Tamps.", "Tlaxcala": "Tlax.",
    "Veracruz de Ignacio de la Llave": "Ver.", "Veracruz": "Ver.",
    "Yucatán": "Yuc.", "Zacatecas": "Zac.",
}


def _parse_pipe_description(raw: str) -> dict[str, str]:
    """Parsea 'Actividad: X | Subcategoría: Y | Propósito: Z | Temas: A, B'"""
    result: dict[str, str] = {}
    for part in raw.split("|"):
        part = part.strip()
        if ":" in part:
            key, _, value = part.partition(":")
            result[key.strip().lower()] = value.strip()
    return result

SCOPES = ["https://www.googleapis.com/auth/calendar"]

# ── Auth (Service Account) ───────────────────────────────────────────────────

def get_credentials():
    from google.oauth2 import service_account as _sa

    if not SA_KEY_FILE.exists():
        print(f"\n❌ No se encontró {SA_KEY_FILE}")
        print("   Ejecuta:")
        print("   gcloud iam service-accounts keys create tools/service_account_gcal.json \\")
        print("     --iam-account=sao-gcal-sync@sao-prod-488416.iam.gserviceaccount.com")
        sys.exit(1)

    creds = _sa.Credentials.from_service_account_file(str(SA_KEY_FILE), scopes=SCOPES)
    print("✅ Usando Service Account (sao-gcal-sync@sao-prod-488416.iam.gserviceaccount.com).")
    return creds


# ── Firestore ────────────────────────────────────────────────────────────────

def fetch_activities(project_id: str) -> list[dict]:
    from google.cloud import firestore as _fs
    client = _fs.Client(project=FIRESTORE_PROJECT)

    docs = client.collection("activities") \
        .where(filter=_fs.FieldFilter("project_id", "==", project_id)) \
        .stream()

    raw: list[dict] = []
    for snap in docs:
        doc = snap.to_dict() or {}
        doc["_id"] = snap.id
        if doc.get("deleted_at") is not None:
            continue
        raw.append(doc)

    # ── Deduplicar actividades multi-responsable por activity_group_id ────────
    grouped: dict[str, list[dict]] = {}
    singles: list[dict] = []
    for doc in raw:
        gid = str(doc.get("activity_group_id") or "").strip()
        if gid:
            grouped.setdefault(gid, []).append(doc)
        else:
            singles.append(doc)

    activities: list[dict] = []
    for gid, group_docs in grouped.items():
        # Tomar el documento más actualizado como primario
        primary = dict(sorted(group_docs,
                              key=lambda d: d.get("sync_version") or 0,
                              reverse=True)[0])
        # Fusionar todos los participantes del grupo
        seen_names: set[str] = set()
        all_participants: list[str] = []
        for d in group_docs:
            for name in (d.get("participant_user_names") or []):
                if name and name not in seen_names:
                    seen_names.add(name)
                    all_participants.append(name)
        if all_participants:
            primary["_merged_participants"] = all_participants
        # Usar group_id como identificador estable del evento
        primary["uuid"] = gid
        activities.append(primary)

    activities.extend(singles)
    return activities


def _format_wizard_payload(wp: dict, execution_state: str) -> list[str]:
    """Extrae el desarrollo/resultado de la actividad desde wizard_payload."""
    lines: list[str] = []
    if not wp:
        return lines

    if execution_state == "CANCELED":
        reason = str(wp.get("cancel_reason") or "").strip()
        if reason:
            lines.append(f"Motivo de cancelación: {reason}")
        return lines

    result_name = ((wp.get("result") or {}).get("name") or "").strip()
    if result_name:
        lines.append(f"Resultado: {result_name}")

    notes = str(wp.get("notes") or "").strip()
    if notes:
        lines.append(f"Notas: {notes}")

    risk = str(wp.get("risk_level") or "").strip()
    if risk:
        lines.append(f"Nivel de riesgo: {risk}")

    agreements = wp.get("agreements") or []
    ag_texts = []
    for ag in agreements:
        text = (ag.get("text") or ag.get("name") or "").strip() if isinstance(ag, dict) else str(ag).strip()
        if text:
            ag_texts.append(text)
    if ag_texts:
        lines.append(f"Acuerdos: {'; '.join(ag_texts)}")

    attendees = wp.get("attendees") or []
    att_names = []
    for at in attendees:
        if isinstance(at, dict):
            name = (at.get("representative_name") or at.get("name") or "").strip()
            if name:
                att_names.append(name)
    if att_names:
        lines.append(f"Asistentes: {', '.join(att_names)}")

    evidences = wp.get("evidences") or []
    ev_descs = []
    for ev in evidences:
        if isinstance(ev, dict):
            desc = str(ev.get("descripcion") or ev.get("description") or "").strip()
            if desc:
                ev_descs.append(f"  • {desc}")
    if ev_descs:
        lines.append("Evidencias:")
        lines.extend(ev_descs[:8])  # máx 8

    return lines


# ── Helpers de fecha ─────────────────────────────────────────────────────────

def _parse_dt(value) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value
    if isinstance(value, str):
        try:
            dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt
        except ValueError:
            return None
    return None


# ── Construcción del evento ───────────────────────────────────────────────────

def build_event(doc: dict) -> dict:
    uid            = str(doc.get("uuid") or doc.get("_id") or "")
    activity_type  = str(doc.get("activity_type_code") or "").upper()
    project_id     = str(doc.get("project_id") or "")
    front_id       = str(doc.get("front_id") or "").strip()
    frente         = str(doc.get("frente") or front_id or "").strip()
    title          = str(doc.get("title") or "").strip()
    raw_desc       = str(doc.get("description") or "").strip()
    execution_state = str(doc.get("execution_state") or "PENDIENTE").upper()
    review_decision = str(doc.get("review_decision") or "").strip().upper()
    pk_start       = doc.get("pk_start")
    pk_end         = doc.get("pk_end")
    assigned_to    = str(doc.get("assigned_to_user_name") or doc.get("assigned_to_name") or "").strip()
    municipio      = str(doc.get("municipio") or "").strip()
    estado_geo     = str(doc.get("estado") or "").strip()
    lat            = doc.get("latitude")
    lng            = doc.get("longitude")
    colonia        = str(doc.get("colonia") or "").strip()

    type_label = ACTIVITY_LABELS.get(activity_type, activity_type)
    estado_abbr = ESTADO_ABBR.get(estado_geo, estado_geo)
    merged_participants: list[str] = doc.get("_merged_participants") or []
    wizard_payload: dict = doc.get("wizard_payload") or {}

    # ── Summary (título del evento) ───────────────────────────────────────────
    # [TSNL] Caminata · Frente F3 · Bustamante, N.L.
    parts = [type_label]
    if frente:
        parts.append(f"Frente {frente}")
    if municipio and estado_abbr:
        parts.append(f"{municipio}, {estado_abbr}")
    elif municipio:
        parts.append(municipio)
    summary = f"[{project_id}] " + " · ".join(parts)

    # ── Parsear la descripción estructurada del backend ────────────────────────
    parsed = _parse_pipe_description(raw_desc)
    subcategoria = parsed.get("subcategoría") or parsed.get("subcategoria") or ""
    proposito    = parsed.get("propósito") or parsed.get("proposito") or ""
    temas        = parsed.get("temas") or ""

    # ── Descripción en bloques lógicos ────────────────────────────────────────
    lines: list[str] = []

    # Bloque 1 — Actividad
    if title and title.lower() != type_label.lower():
        lines.append(title)
    if subcategoria:
        lines.append(f"Subcategoría: {subcategoria}")
    if proposito:
        lines.append(f"Propósito: {proposito}")
    if temas:
        lines.append(f"Temas: {temas}")
    if colonia:
        lines.append(f"Lugar: {colonia}")

    lines.append("")

    # Bloque 2 — Estado / revisión
    estado_icon = STATE_EMOJI.get(execution_state, "⚪")
    estado_line = f"Estado: {estado_icon} {execution_state}"
    if review_decision and review_decision in REVIEW_LABEL:
        estado_line += f"  |  {REVIEW_LABEL[review_decision]}"
    lines.append(estado_line)
    # Participantes (fusionados si es multi-responsable)
    if merged_participants:
        lines.append("Participantes: " + ", ".join(merged_participants))
    elif assigned_to:
        lines.append(f"Asignado a: {assigned_to}")

    # Bloque 3 — Desarrollo (wizard_payload)
    desarrollo = _format_wizard_payload(wizard_payload, execution_state)
    if desarrollo:
        lines.append("")
        lines.extend(desarrollo)

    # Bloque 4 — Trazado / PK (solo si existe)
    if pk_start is not None:
        lines.append("")
        km, m = divmod(int(pk_start), 1000)
        lines.append(f"PK inicio: {km}+{m:03d}")
        if pk_end is not None:
            km2, m2 = divmod(int(pk_end), 1000)
            lines.append(f"PK fin:    {km2}+{m2:03d}")

    # Bloque 5 — Ubicación
    if frente or municipio or lat:
        lines.append("")
        if frente:
            lines.append(f"📍 Frente {frente}" + (f" · {municipio}, {estado_geo}" if municipio else ""))
        elif municipio:
            lines.append(f"📍 {municipio}, {estado_geo}")
        if lat and lng:
            lines.append(f"Coords: {float(lat):.6f}, {float(lng):.6f}")

    # Bloque 6 — Sistema (al final, datos de depuración)
    lines.append("")
    lines.append("─" * 32)
    lines.append(f"Proyecto: {project_id}")
    lines.append(f"\nSAO-ID:{uid}")  # tag idempotente — no mover ni eliminar

    # ── Fechas ────────────────────────────────────────────────────────────────
    start_dt = _parse_dt(doc.get("assignment_start_at")) or _parse_dt(doc.get("created_at"))
    end_dt   = _parse_dt(doc.get("assignment_end_at"))
    if start_dt is None:
        return None  # type: ignore
    if end_dt is None or end_dt <= start_dt:
        end_dt = start_dt + timedelta(hours=1)

    # ── Ubicación (campo location de GCal) ───────────────────────────────────
    # Prioridad: frente+municipio+estado > municipio+estado > coords
    if frente and municipio and estado_geo:
        location = f"Frente {frente}, {municipio}, {estado_geo}"
    elif frente and municipio:
        location = f"Frente {frente}, {municipio}"
    elif municipio and estado_geo:
        location = f"{municipio}, {estado_geo}"
    elif lat and lng:
        location = f"{float(lat):.6f},{float(lng):.6f}"
    else:
        location = None

    # ── Color por estado ─────────────────────────────────────────────────────
    color_id = {
        "COMPLETADA": "2",   # sage/verde
        "EN_CURSO":   "5",   # banana/amarillo
        "CANCELED":   "11",  # tomato/rojo
    }.get(execution_state, "9")  # blueberry/azul → PENDIENTE

    event: dict = {
        "summary":     summary,
        "description": "\n".join(lines),
        "start":       {"dateTime": start_dt.isoformat(), "timeZone": "UTC"},
        "end":         {"dateTime": end_dt.isoformat(),   "timeZone": "UTC"},
        "colorId":     color_id,
    }
    if location:
        event["location"] = location

    return event


# ── Sync principal ────────────────────────────────────────────────────────────

def sync_project(service, project_id: str, calendar_id: str,
                 dry_run: bool, clear: bool):
    print(f"\n{'='*60}")
    print(f"  Proyecto: {project_id}")
    print(f"  Calendario: {calendar_id[:30]}...")

    activities = fetch_activities(project_id)
    print(f"  Actividades en Firestore: {len(activities)}")

    if not activities:
        print("  → Nada que sincronizar.")
        return

    # ── Limpiar si se solicitó ────────────────────────────────────────────────
    if clear and not dry_run:
        print("  🗑  Borrando eventos SAO existentes...")
        deleted = 0
        page_token = None
        while True:
            kwargs = {"calendarId": calendar_id, "maxResults": 2500,
                      "showDeleted": False}
            if page_token:
                kwargs["pageToken"] = page_token
            resp = service.events().list(**kwargs).execute()
            for e in resp.get("items", []):
                desc = e.get("description") or ""
                if "SAO-ID:" in desc:
                    service.events().delete(
                        calendarId=calendar_id, eventId=e["id"]).execute()
                    deleted += 1
            page_token = resp.get("nextPageToken")
            if not page_token:
                break
        print(f"  → {deleted} eventos borrados.")

    # ── Cargar eventos existentes (para upsert) ───────────────────────────────
    existing: dict[str, str] = {}  # sao_uuid → gcal_event_id
    if not clear and not dry_run:
        page_token = None
        while True:
            kwargs = {"calendarId": calendar_id, "maxResults": 2500,
                      "showDeleted": False}
            if page_token:
                kwargs["pageToken"] = page_token
            resp = service.events().list(**kwargs).execute()
            for e in resp.get("items", []):
                desc = e.get("description") or ""
                m = re.search(r"SAO-ID:(\S+)", desc)
                if m:
                    existing[m.group(1)] = e["id"]
            page_token = resp.get("nextPageToken")
            if not page_token:
                break
        print(f"  Eventos SAO ya en el calendario: {len(existing)}")

    # ── Insertar / actualizar ─────────────────────────────────────────────────
    inserted = updated = skipped = 0
    for doc in activities:
        event = build_event(doc)
        if event is None:
            skipped += 1
            continue

        uid = str(doc.get("uuid") or doc.get("_id") or "")

        if dry_run:
            action = "UPDATE" if uid in existing else "INSERT"
            print(f"    [{action}] {event['summary'][:60]}")
            inserted += 1
            continue

        try:
            if uid in existing:
                service.events().update(
                    calendarId=calendar_id,
                    eventId=existing[uid],
                    body=event,
                    sendUpdates="none",
                ).execute()
                updated += 1
            else:
                service.events().insert(
                    calendarId=calendar_id,
                    body=event,
                    sendUpdates="none",
                ).execute()
                inserted += 1
            time.sleep(0.25)
        except Exception as exc:
            print(f"    ⚠️  Error en {uid}: {exc}")
            skipped += 1

    if dry_run:
        print(f"  [DRY-RUN] {inserted} eventos a procesar, {skipped} sin fechas.")
    else:
        print(f"  ✅ Insertados: {inserted}  |  Actualizados: {updated}  |  Omitidos: {skipped}")


# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Sincroniza actividades SAO con Google Calendar")
    parser.add_argument("--project", help="Solo sincronizar este proyecto (ej: TSNL)")
    parser.add_argument("--dry-run", action="store_true", help="Simular sin crear eventos")
    parser.add_argument("--clear", action="store_true",
                        help="Borrar eventos SAO existentes antes de insertar")
    args = parser.parse_args()

    # Importar después de configurar sys.path
    from googleapiclient.discovery import build

    print("🔐 Autenticando con Google...")
    creds = get_credentials()
    service = build("calendar", "v3", credentials=creds)

    projects = {args.project: CALENDAR_IDS[args.project]} \
        if args.project and args.project in CALENDAR_IDS \
        else CALENDAR_IDS

    if args.project and args.project not in CALENDAR_IDS:
        print(f"❌ Proyecto '{args.project}' no reconocido. Opciones: {list(CALENDAR_IDS)}")
        sys.exit(1)

    total_inserted = 0
    for pid, cal_id in projects.items():
        sync_project(service, pid, cal_id, dry_run=args.dry_run, clear=args.clear)

    print(f"\n{'='*60}")
    print("🎉 Sincronización completada.")


if __name__ == "__main__":
    main()
