import logging
import re
from datetime import datetime, timedelta, timezone
from uuid import UUID
from uuid import uuid4

from fastapi import APIRouter, Depends, Query, status
from app.core.api_errors import api_error

from app.api.deps import get_current_user, require_any_role, user_has_any_role
from app.core.config import settings
from app.core.firestore import get_firestore_client
from typing import Any
from app.core.enums import UserStatus
from app.services.audit_service import write_firestore_audit_log
from app.services.firestore_identity_service import get_firestore_user_by_id, list_firestore_users
from app.schemas.assignment import (
    AssignmentAssigneeOption,
    AssignmentCancelRequest,
    AssignmentCancelResponse,
    AssignmentCreate,
    AssignmentListItem,
    AssignmentTransferRequest,
)

router = APIRouter(prefix="/assignments", tags=["assignments"])
logger = logging.getLogger(__name__)


def _safe_float(v: object) -> float | None:
    if v is None:
        return None
    try:
        return float(v)
    except (ValueError, TypeError):
        return None


def _extract_scope_from_text(*values: str | None) -> tuple[str, str]:
    merged = " | ".join([(value or "").strip() for value in values if (value or "").strip()])
    if not merged:
        return "", ""
    estado_match = re.search(r"estado\s*:\s*([^|Â·;,]+)", merged, flags=re.IGNORECASE)
    municipio_match = re.search(r"municipio\s*:\s*([^|Â·;,]+)", merged, flags=re.IGNORECASE)
    estado = (estado_match.group(1) if estado_match else "").strip()
    municipio = (municipio_match.group(1) if municipio_match else "").strip()
    return estado, municipio


def _safe_uuid_str(value: object) -> str:
    raw = str(value or "").strip()
    if not raw:
        return ""
    try:
        return str(UUID(raw))
    except (ValueError, TypeError):
        return ""


def _to_dt(value: object) -> datetime:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if isinstance(value, str):
        raw = value.strip()
        if raw.endswith("Z"):
            raw = raw[:-1] + "+00:00"
        try:
            dt = datetime.fromisoformat(raw)
            return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    return datetime.now(timezone.utc)


def _next_project_sync_version(client: Any, project_id: str) -> int:
    max_sync_version = 0
    docs = client.collection("activities").where("project_id", "==", project_id).stream()
    for doc in docs:
        payload = doc.to_dict() or {}
        try:
            max_sync_version = max(max_sync_version, int(payload.get("sync_version") or 0))
        except (TypeError, ValueError):
            continue
    return max_sync_version + 1


def _is_privileged_assignment_manager(current_user: Any) -> bool:
    return user_has_any_role(
        current_user,
        ["ADMIN", "COORD", "SUPERVISOR", "DESARROLLADOR", "DEVELOPER", "DEV"],
        None,
    )


def _validate_transfer_target(
    *,
    project_id: str,
    assignee_user_id: str,
) -> Any:
    assignee_principal = get_firestore_user_by_id(assignee_user_id)
    if assignee_principal is None or assignee_principal.status != UserStatus.ACTIVE:
        raise api_error(
            status_code=status.HTTP_404_NOT_FOUND,
            code="ASSIGNMENT_ASSIGNEE_NOT_FOUND",
            message="Assignee not found or inactive",
        )

    allowed_roles = {"OPERATIVO", "OPERARIO", "TECNICO", "TÉCNICO", "SUPERVISOR", "COORD", "ADMIN"}
    principal_roles = {role.strip().upper() for role in assignee_principal.roles if role.strip()}
    if not principal_roles.intersection(allowed_roles):
        raise api_error(
            status_code=status.HTTP_400_BAD_REQUEST,
            code="ASSIGNMENT_ASSIGNEE_INVALID_ROLE",
            message="Assignee role is not allowed for assignments",
        )

    project_ids = {project.strip().upper() for project in assignee_principal.project_ids if project.strip()}
    if project_ids and project_id not in project_ids:
        raise api_error(
            status_code=status.HTTP_400_BAD_REQUEST,
            code="ASSIGNMENT_ASSIGNEE_PROJECT_MISMATCH",
            message="Assignee does not belong to the requested project",
        )
    return assignee_principal


def _build_assignment_list_item(
    *,
    doc_id: str,
    payload: dict[str, Any],
    project_id: str,
    assignee_principal: Any | None,
) -> AssignmentListItem:
    created_raw = payload.get("created_at")
    updated_raw = payload.get("updated_at")
    start_at = _to_dt(created_raw)
    end_at = _to_dt(updated_raw)
    if end_at <= start_at:
        end_at = start_at + timedelta(hours=1)
    state = str(payload.get("execution_state") or "PENDIENTE")
    raw_front = str(
        payload.get("frente")
        or payload.get("front_name")
        or payload.get("front")
        or ""
    ).strip()
    estado = str(payload.get("estado") or "").strip()
    municipio = str(payload.get("municipio") or "").strip()
    if not estado or not municipio:
        parsed_estado, parsed_municipio = _extract_scope_from_text(
            str(payload.get("title") or ""),
            str(payload.get("description") or ""),
        )
        estado = estado or parsed_estado
        municipio = municipio or parsed_municipio
    return AssignmentListItem(
        id=str(payload.get("uuid") or doc_id),
        project_id=str(payload.get("project_id") or project_id),
        assignee_user_id=UUID(str(payload.get("assigned_to_user_id"))),
        assignee_name=(assignee_principal.full_name if assignee_principal else "Sin responsable"),
        assignee_email=(assignee_principal.email if assignee_principal else None),
        activity_id=str(payload.get("activity_type_code") or ""),
        title=str(payload.get("title") or payload.get("activity_type_code") or ""),
        frente=raw_front,
        municipio=municipio,
        estado=estado,
        pk=payload.get("pk_start") or 0,
        start_at=start_at,
        end_at=end_at,
        risk="bajo",
        status=("PROGRAMADA" if state == "PENDIENTE" else state),
    )


@router.get("", response_model=list[AssignmentListItem])
def list_assignments(
    project_id: str = Query(..., description="Project filter"),
    from_dt: datetime = Query(..., alias="from", description="Range start (ISO-8601)"),
    to_dt: datetime = Query(..., alias="to", description="Range end (ISO-8601)"),
    include_all: bool = Query(False, description="If true, privileged roles can view all assignees"),
    current_user: Any = Depends(get_current_user),
):
    normalized_project_id = project_id.strip().upper()

    def _ensure_aware_utc(value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc)

    range_start = _ensure_aware_utc(from_dt)
    range_end = _ensure_aware_utc(to_dt)
    if range_end <= range_start:
        range_end = range_start + timedelta(days=1)

    can_view_all = include_all and user_has_any_role(
        current_user,
        [
            "ADMIN",
            "COORD",
            "SUPERVISOR",
            "OPERATIVO",
            "DESARROLLADOR",
            "DEVELOPER",
            "DEV",
        ],
        None,
    )
    current_user_id = str(getattr(current_user, "id", ""))

    client = get_firestore_client()
    principals = list_firestore_users()
    principal_by_id = {str(p.id): p for p in principals}
    docs = client.collection("activities").where("project_id", "==", normalized_project_id).stream()
    items: list[AssignmentListItem] = []
    for doc in docs:
        payload = doc.to_dict() or {}
        if payload.get("deleted_at") is not None:
            continue
        assignee_user_id = _safe_uuid_str(payload.get("assigned_to_user_id"))
        created_by_user_id = _safe_uuid_str(payload.get("created_by_user_id"))
        effective_assignee_user_id = assignee_user_id or created_by_user_id
        if not effective_assignee_user_id:
            continue
        if not can_view_all and current_user_id and effective_assignee_user_id != current_user_id:
            continue

        created_raw = payload.get("created_at")
        updated_raw = payload.get("updated_at")

        def _to_dt(v: object) -> datetime:
            if isinstance(v, datetime):
                return v if v.tzinfo else v.replace(tzinfo=timezone.utc)
            if isinstance(v, str):
                raw = v.strip()
                if raw.endswith("Z"):
                    raw = raw[:-1] + "+00:00"
                try:
                    dt = datetime.fromisoformat(raw)
                    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
                except ValueError:
                    pass
            return datetime.now(timezone.utc)

        start_at = _to_dt(created_raw)
        end_at = _to_dt(updated_raw)
        if end_at <= start_at:
            end_at = start_at + timedelta(hours=1)
        if end_at < range_start or start_at > range_end:
            continue
        state = str(payload.get("execution_state") or "PENDIENTE")
        raw_front = str(
            payload.get("frente")
            or payload.get("front_name")
            or payload.get("front")
            or ""
        ).strip()
        estado = str(payload.get("estado") or "").strip()
        municipio = str(payload.get("municipio") or "").strip()
        if not estado or not municipio:
            parsed_estado, parsed_municipio = _extract_scope_from_text(
                str(payload.get("title") or ""),
                str(payload.get("description") or ""),
            )
            estado = estado or parsed_estado
            municipio = municipio or parsed_municipio
        principal = principal_by_id.get(effective_assignee_user_id)
        items.append(
            AssignmentListItem(
                id=str(payload.get("uuid") or doc.id),
                project_id=str(payload.get("project_id") or normalized_project_id),
                assignee_user_id=effective_assignee_user_id,
                assignee_name=(principal.full_name if principal else "Sin responsable"),
                assignee_email=(principal.email if principal else None),
                activity_id=str(payload.get("activity_type_code") or ""),
                title=str(payload.get("title") or payload.get("activity_type_code") or ""),
                frente=raw_front,
                municipio=municipio,
                estado=estado,
                pk=payload.get("pk_start"),
                start_at=start_at,
                end_at=end_at,
                risk="bajo",
                status=("PROGRAMADA" if state == "PENDIENTE" else state),
                latitude=_safe_float(payload.get("latitude")),
                longitude=_safe_float(payload.get("longitude")),
            )
        )
    return items


@router.get("/assignees", response_model=list[AssignmentAssigneeOption])
def list_assignees(
    project_id: str = Query(..., description="Project filter"),
    _current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
):
    _assignable_roles = {"OPERATIVO", "SUPERVISOR", "COORD", "ADMIN"}

    principals = list_firestore_users()
    options: list[AssignmentAssigneeOption] = []
    for p in principals:
        if p.status != UserStatus.ACTIVE:
            continue
        if not any(r in _assignable_roles for r in p.roles):
            continue
        if p.project_ids and project_id.strip().upper() not in p.project_ids:
            continue
        options.append(
            AssignmentAssigneeOption(
                user_id=p.id,
                full_name=p.full_name,
                email=p.email,
                role_name=(p.roles[0] if p.roles else ""),
            )
        )
    options.sort(key=lambda item: (item.full_name.lower(), item.email.lower()))
    return options


@router.post("", response_model=AssignmentListItem, status_code=status.HTTP_201_CREATED)
def create_assignment(
    payload: AssignmentCreate,
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR"])),
):
    project_id = payload.project_id.strip().upper()
    if payload.end_at <= payload.start_at:
        raise api_error(status_code=status.HTTP_400_BAD_REQUEST, code="ASSIGNMENT_INVALID_DATE_RANGE", message="end_at must be greater than start_at")

    front_ref = (payload.front_ref or "").strip()
    estado = (payload.estado or "").strip()
    municipio = (payload.municipio or "").strip()
    description_parts = [f"planned:{payload.risk.strip().lower()}"]
    if estado:
        description_parts.append(f"estado={estado}")
    if municipio:
        description_parts.append(f"municipio={municipio}")
    description_value = ";".join(description_parts)

    client = get_firestore_client()
    activity_uuid = uuid4()
    type_code = payload.activity_type_code.strip().upper()
    title = payload.title.strip() if payload.title and payload.title.strip() else type_code
    doc_payload = {
        "uuid": str(activity_uuid),
        "server_id": None,
        "project_id": project_id,
        "front_id": str(payload.front_id) if payload.front_id else None,
        "frente": front_ref,
        "estado": estado or None,
        "municipio": municipio or None,
        "colonia": (payload.colonia or "").strip() or None,
        "pk_start": payload.pk,
        "pk_end": None,
        "execution_state": "PENDIENTE",
        "assigned_to_user_id": str(payload.assignee_user_id),
        "created_by_user_id": str(current_user.id),
        "catalog_version_id": None,
        "activity_type_code": type_code,
        "title": title,
        "description": description_value,
        "gps_mismatch": False,
        "catalog_changed": False,
        "latitude": str(payload.latitude) if payload.latitude is not None else None,
        "longitude": str(payload.longitude) if payload.longitude is not None else None,
        "created_at": payload.start_at.isoformat(),
        "updated_at": payload.end_at.isoformat(),
        "deleted_at": None,
        "sync_version": _next_project_sync_version(client, project_id),
    }
    client.collection("activities").document(str(activity_uuid)).set(doc_payload)
    assignee_principal = get_firestore_user_by_id(payload.assignee_user_id)
    return AssignmentListItem(
        id=str(activity_uuid),
        project_id=project_id,
        assignee_user_id=payload.assignee_user_id,
        assignee_name=(assignee_principal.full_name if assignee_principal else "Sin responsable"),
        assignee_email=(assignee_principal.email if assignee_principal else None),
        activity_id=type_code,
        title=title,
        frente=front_ref,
        municipio=municipio,
        estado=estado,
        pk=payload.pk,
        start_at=payload.start_at,
        end_at=payload.end_at,
        risk=payload.risk,
        status="PROGRAMADA",
        latitude=payload.latitude,
        longitude=payload.longitude,
    )


@router.post("/{assignment_id}/cancel", response_model=AssignmentCancelResponse)
def cancel_assignment(
    assignment_id: UUID,
    payload: AssignmentCancelRequest | None = None,
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR"])),
):
    client = get_firestore_client()
    ref = client.collection("activities").document(str(assignment_id))
    snap = ref.get()
    if not snap.exists:
        raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="ASSIGNMENT_NOT_FOUND", message="Assignment not found")
    doc = snap.to_dict() or {}
    cancel_reason = payload.reason.strip() if payload and payload.reason else None

    # If already soft-deleted, keep endpoint idempotent.
    if doc.get("deleted_at") is not None:
        return AssignmentCancelResponse(
            id=str(assignment_id),
            canceled=False,
            execution_state=str(doc.get("execution_state") or "PENDIENTE"),
            canceled_at=None,
            canceled_by_user_id=current_user.id,
            cancel_reason=cancel_reason,
        )

    canceled_at = datetime.now(timezone.utc)
    ref.set(
        {
            "assigned_to_user_id": None,
            "execution_state": "PENDIENTE",
            "deleted_at": canceled_at.isoformat(),
            "updated_at": canceled_at.isoformat(),
            "sync_version": _next_project_sync_version(client, str(doc.get("project_id") or "")),
        },
        merge=True,
    )
    return AssignmentCancelResponse(
        id=str(assignment_id),
        canceled=True,
        execution_state="PENDIENTE",
        canceled_at=canceled_at,
        canceled_by_user_id=current_user.id,
        cancel_reason=cancel_reason,
    )


@router.post("/{assignment_id}/transfer", response_model=AssignmentListItem)
def transfer_assignment(
    assignment_id: UUID,
    payload: AssignmentTransferRequest,
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
):
    client = get_firestore_client()
    ref = client.collection("activities").document(str(assignment_id))
    snap = ref.get()
    if not snap.exists:
        raise api_error(
            status_code=status.HTTP_404_NOT_FOUND,
            code="ASSIGNMENT_NOT_FOUND",
            message="Assignment not found",
        )

    doc = snap.to_dict() or {}
    project_id = str(doc.get("project_id") or "").strip().upper()
    if not project_id:
        raise api_error(
            status_code=status.HTTP_400_BAD_REQUEST,
            code="ASSIGNMENT_PROJECT_REQUIRED",
            message="Assignment project is missing",
        )

    current_assignee_user_id = _safe_uuid_str(doc.get("assigned_to_user_id"))
    if not current_assignee_user_id:
        raise api_error(
            status_code=status.HTTP_409_CONFLICT,
            code="ASSIGNMENT_NOT_ASSIGNED",
            message="Assignment has no current assignee",
        )

    actor_user_id = _safe_uuid_str(getattr(current_user, "id", None))
    if not _is_privileged_assignment_manager(current_user) and actor_user_id != current_assignee_user_id:
        raise api_error(
            status_code=status.HTTP_403_FORBIDDEN,
            code="ASSIGNMENT_TRANSFER_FORBIDDEN",
            message="Operative can only transfer activities currently assigned to them",
        )

    next_assignee_user_id = str(payload.assignee_user_id)
    if next_assignee_user_id == current_assignee_user_id:
        raise api_error(
            status_code=status.HTTP_409_CONFLICT,
            code="ASSIGNMENT_TRANSFER_SAME_ASSIGNEE",
            message="Assignment is already assigned to that user",
        )

    next_assignee_principal = _validate_transfer_target(
        project_id=project_id,
        assignee_user_id=next_assignee_user_id,
    )
    previous_assignee_principal = get_firestore_user_by_id(current_assignee_user_id)
    transfer_at = datetime.now(timezone.utc)
    next_sync_version = _next_project_sync_version(client, project_id)
    ref.set(
        {
            "assigned_to_user_id": next_assignee_user_id,
            "updated_at": transfer_at.isoformat(),
            "sync_version": next_sync_version,
        },
        merge=True,
    )

    updated_payload = dict(doc)
    updated_payload["assigned_to_user_id"] = next_assignee_user_id
    updated_payload["updated_at"] = transfer_at.isoformat()
    updated_payload["sync_version"] = next_sync_version

    write_firestore_audit_log(
        action="ASSIGNMENT_TRANSFERRED",
        entity="assignment",
        entity_id=str(assignment_id),
        actor=current_user,
        details={
            "project_id": project_id,
            "from_assignee_user_id": current_assignee_user_id,
            "from_assignee_name": previous_assignee_principal.full_name if previous_assignee_principal else None,
            "to_assignee_user_id": next_assignee_user_id,
            "to_assignee_name": next_assignee_principal.full_name,
            "reason": payload.reason,
        },
    )

    return _build_assignment_list_item(
        doc_id=str(assignment_id),
        payload=updated_payload,
        project_id=project_id,
        assignee_principal=next_assignee_principal,
    )

