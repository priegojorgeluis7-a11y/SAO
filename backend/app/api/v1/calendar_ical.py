"""
GET /api/v1/assignments/ical

Genera un feed iCalendar (.ics) con las actividades asignadas al usuario
autenticado. Compatible con Google Calendar, Apple Calendar y Outlook mediante
"Suscribirse por URL".

Autenticación: el JWT access token se pasa como query parameter `token` porque
los clientes de calendario no admiten headers HTTP personalizados.

Uso:
    GET /api/v1/assignments/ical?token=<access_token>
    GET /api/v1/assignments/ical?token=<access_token>&project_id=TSNL
"""

import logging
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Query
from fastapi.responses import Response
from icalendar import Calendar, Event, vText

from app.core.config import settings
from app.core.firestore import get_firestore_client
from app.core.security import verify_token
from app.core.utils import parse_firestore_dt
from app.services.firestore_identity_service import get_firestore_user_by_id

router = APIRouter(prefix="/assignments", tags=["assignments"])
logger = logging.getLogger(__name__)

_ACTIVITY_TYPE_LABELS: dict[str, str] = {
    "CAM": "Caminamiento",
    "REU": "Reunión",
    "ASP": "Asamblea Protocolizada",
    "CIN": "Consulta Indígena",
    "SOC": "Socialización",
    "AIN": "Acompañamiento Institucional",
}



def _label_for_type(code: str) -> str:
    return _ACTIVITY_TYPE_LABELS.get(code.upper(), code)


def _safe_dt(value: Any) -> datetime | None:
    return parse_firestore_dt(value)


def _build_calendar(activities: list[dict[str, Any]], owner_name: str) -> bytes:
    cal = Calendar()
    cal.add("prodid", f"-//SAO Sistema//SAO Actividades//ES")
    cal.add("version", "2.0")
    cal.add("calscale", "GREGORIAN")
    cal.add("method", "PUBLISH")
    cal.add("x-wr-calname", vText(f"SAO – {owner_name}"))
    cal.add("x-wr-caldesc", vText("Actividades asignadas en SAO"))
    cal.add("x-wr-timezone", vText("UTC"))

    for doc in activities:
        uid = str(doc.get("uuid") or doc.get("_id") or "")
        if not uid:
            continue

        activity_type = str(doc.get("activity_type_code") or "").upper()
        project_id = str(doc.get("project_id") or "")
        front_id = str(doc.get("front_id") or "")
        title = str(doc.get("title") or "").strip()
        description = str(doc.get("description") or "").strip()
        execution_state = str(doc.get("execution_state") or "PENDIENTE")
        pk_start = doc.get("pk_start")
        pk_end = doc.get("pk_end")

        # Construir summary
        type_label = _label_for_type(activity_type)
        summary_parts = [type_label]
        if project_id:
            summary_parts.append(project_id)
        if front_id:
            summary_parts.append(f"Frente {front_id}")
        if title:
            summary_parts.append(title)
        summary = " · ".join(summary_parts)

        # Construir description
        desc_parts = []
        if description:
            desc_parts.append(description)
        desc_parts.append(f"Estado: {execution_state}")
        if pk_start is not None:
            km = pk_start // 1000
            m = pk_start % 1000
            desc_parts.append(f"PK inicio: {km}+{m:03d}")
        if pk_end is not None:
            km = pk_end // 1000
            m = pk_end % 1000
            desc_parts.append(f"PK fin: {km}+{m:03d}")
        desc_parts.append(f"Proyecto: {project_id}")

        # Fechas
        start_dt = _safe_dt(doc.get("assignment_start_at")) or _safe_dt(doc.get("created_at"))
        end_dt = _safe_dt(doc.get("assignment_end_at"))
        if start_dt is None:
            continue
        if end_dt is None or end_dt <= start_dt:
            end_dt = start_dt + timedelta(hours=1)

        # Ubicación (GPS si disponible)
        lat = doc.get("latitude")
        lng = doc.get("longitude")
        location = ""
        if lat and lng:
            location = f"{lat},{lng}"
        elif front_id:
            location = f"Frente {front_id}, {project_id}"

        event = Event()
        event.add("uid", vText(f"{uid}@sao.sistemas"))
        event.add("summary", vText(summary))
        event.add("description", vText("\n".join(desc_parts)))
        event.add("dtstart", start_dt)
        event.add("dtend", end_dt)
        event.add("dtstamp", datetime.now(timezone.utc))
        if location:
            event.add("location", vText(location))

        # Estado → VEVENT status
        if execution_state == "COMPLETADA":
            event.add("status", vText("CONFIRMED"))
        elif execution_state in ("PENDIENTE", "EN_CURSO"):
            event.add("status", vText("TENTATIVE"))
        else:
            event.add("status", vText("TENTATIVE"))

        updated = _safe_dt(doc.get("updated_at"))
        if updated:
            event.add("last-modified", updated)

        cal.add_component(event)

    return cal.to_ical()


@router.get(
    "/ical",
    response_class=Response,
    summary="Feed iCalendar de actividades asignadas",
    description=(
        "Devuelve un archivo .ics con las actividades asignadas al usuario autenticado. "
        "Suscríbete en Google Calendar con 'Añadir por URL' para sincronización automática."
    ),
)
async def get_assignments_ical(
    token: str = Query(..., description="JWT access token del usuario"),
    project_id: str | None = Query(None, description="Filtrar por proyecto (ej: TSNL)"),
) -> Response:
    # Validar token manualmente (los clientes iCal no envían headers)
    try:
        payload = verify_token(token, expected_type="access")
    except ValueError:
        return Response(
            content="Token inválido o expirado.",
            status_code=401,
            media_type="text/plain",
        )

    user_id = str(payload.get("sub") or "").strip()
    if not user_id:
        return Response(
            content="Token sin sujeto (sub).",
            status_code=401,
            media_type="text/plain",
        )

    # Resolver nombre del usuario para el título del calendario
    owner_name = user_id
    try:
        client = get_firestore_client()
        user = get_firestore_user_by_id(client, user_id)
        if user:
            owner_name = str(getattr(user, "full_name", None) or user_id)
    except Exception as exc:
        logger.warning("No se pudo resolver nombre de usuario %s: %s", user_id, exc)

    # Consultar actividades en Firestore
    activities: list[dict[str, Any]] = []
    try:
        query = client.collection("activities").where(
            "participant_user_ids", "array_contains", user_id
        )
        if project_id:
            query = query.where("project_id", "==", project_id.strip().upper())

        for snap in query.stream():
            doc = snap.to_dict() or {}
            if doc.get("deleted_at") is not None:
                continue
            doc["_id"] = snap.id
            activities.append(doc)

        # Fallback: también buscar por assigned_to_user_id para actividades
        # legacy que no tienen participant_user_ids poblado
        seen_ids = {doc["_id"] for doc in activities}
        fallback_query = client.collection("activities").where(
            "assigned_to_user_id", "==", user_id
        )
        if project_id:
            fallback_query = fallback_query.where("project_id", "==", project_id.strip().upper())

        for snap in fallback_query.stream():
            if snap.id in seen_ids:
                continue
            doc = snap.to_dict() or {}
            if doc.get("deleted_at") is not None:
                continue
            doc["_id"] = snap.id
            activities.append(doc)

    except Exception as exc:
        logger.error("Error consultando actividades para iCal user=%s: %s", user_id, exc)
        return Response(
            content="Error interno al generar el calendario.",
            status_code=500,
            media_type="text/plain",
        )

    ical_bytes = _build_calendar(activities, owner_name)

    safe_name = owner_name.replace(" ", "_").replace("/", "-")
    filename = f"sao_{safe_name}.ics"

    return Response(
        content=ical_bytes,
        media_type="text/calendar; charset=utf-8",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Cache-Control": "no-cache",
        },
    )


@router.get(
    "/ical/{project_id}",
    response_class=Response,
    summary="Feed iCalendar de un proyecto específico",
    description=(
        "Atajo con project_id en la ruta para facilitar URLs legibles por proyecto. "
        "Equivalente a GET /ical?project_id=<id>&token=<token>."
    ),
)
async def get_project_ical(
    project_id: str,
    token: str = Query(..., description="JWT access token del usuario"),
) -> Response:
    """Delega al endpoint genérico con el project_id fijado en la ruta."""
    return await get_assignments_ical(
        token=token,
        project_id=project_id.strip().upper(),
    )
