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
from app.services.audit_service import canonicalize_role_name, write_firestore_audit_log
from app.services.firestore_identity_service import get_firestore_user_by_id, list_firestore_users
from app.core.utils import parse_firestore_dt
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
    result = parse_firestore_dt(value)
    return result if result is not None else datetime.now(timezone.utc)


def _assignment_window(payload: dict[str, Any]) -> tuple[datetime, datetime]:
    start_at = _to_dt(
        payload.get("assignment_start_at")
        or payload.get("start_at")
        or payload.get("created_at")
    )
    end_at = _to_dt(
        payload.get("assignment_end_at")
        or payload.get("end_at")
        or payload.get("updated_at")
    )
    if end_at <= start_at:
        end_at = start_at + timedelta(hours=1)
    return start_at, end_at


def _next_project_sync_version(client: Any, project_id: str) -> int:
    normalized_project_id = str(project_id or "").strip().upper()
    if not normalized_project_id:
        return 1

    base_query = client.collection("activities").where("project_id", "==", normalized_project_id)

    try:
        docs = list(
            base_query
            .order_by("sync_version", direction="DESCENDING")
            .limit(1)
            .stream()
        )
        if docs:
            payload = docs[0].to_dict() or {}
            try:
                return int(payload.get("sync_version") or 0) + 1
            except (TypeError, ValueError):
                return 1
    except Exception as exc:
        logger.warning(
            "Falling back to project scan for sync_version on assignments project=%s: %s",
            normalized_project_id,
            exc,
        )

    max_sync_version = 0
    try:
        for doc in base_query.stream():
            payload = doc.to_dict() or {}
            try:
                sync_version = int(payload.get("sync_version") or 0)
            except (TypeError, ValueError):
                sync_version = 0
            if sync_version > max_sync_version:
                max_sync_version = sync_version
    except Exception as exc:
        logger.warning(
            "Unable to scan sync_version values for assignments project=%s: %s",
            normalized_project_id,
            exc,
        )
        return 1

    return max_sync_version + 1


def _is_privileged_assignment_manager(current_user: Any) -> bool:
    return user_has_any_role(
        current_user,
        ["ADMIN", "COORD", "SUPERVISOR", "DESARROLLADOR", "DEVELOPER", "DEV"],
        None,
    )


def _principal_role_name(principal: Any | None) -> str | None:
    if principal is None:
        return None
    roles = getattr(principal, "roles", []) or []
    if isinstance(roles, str):
        roles = [roles]
    for role in roles:
        normalized = canonicalize_role_name(role)
        if normalized:
            return normalized
    return None


def _assignment_assignee_projection(
    assignee_user_id: str | None,
    assignee_principal: Any | None,
) -> dict[str, Any]:
    normalized_assignee_user_id = _safe_uuid_str(assignee_user_id)
    full_name = getattr(assignee_principal, "full_name", None) if assignee_principal else None
    email = getattr(assignee_principal, "email", None) if assignee_principal else None
    return {
        "assigned_to_user_id": normalized_assignee_user_id or None,
        "assigned_to_user_name": full_name,
        "assigned_to_user_email": email,
        "assigned_to_name": full_name,
        "assigned_to_role": _principal_role_name(assignee_principal),
    }


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

    allowed_roles = {"OPERATIVO", "SUPERVISOR", "COORD", "ADMIN"}
    principal_roles = {
        canonicalize_role_name(role) or ""
        for role in assignee_principal.roles
        if str(role).strip()
    }
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
    start_at, end_at = _assignment_window(payload)
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
        activity_id=str(payload.get("uuid") or doc_id),
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

        start_at, end_at = _assignment_window(payload)
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
                activity_id=str(payload.get("uuid") or doc.id),
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
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
):
    _assignable_roles = {"OPERATIVO", "SUPERVISOR", "COORD", "ADMIN"}

    # If user is OPERATIVO ONLY (no ADMIN/COORD/SUPERVISOR), only return self
    has_privileged_role = user_has_any_role(current_user, ["ADMIN", "COORD", "SUPERVISOR"], None)
    is_only_operativo = user_has_any_role(current_user, ["OPERATIVO"], None) and not has_privileged_role
    
    if is_only_operativo:
        principal = current_user
        if principal.status == UserStatus.ACTIVE:
            return [
                AssignmentAssigneeOption(
                    user_id=principal.id,
                    full_name=principal.full_name,
                    email=principal.email,
                    role_name=_principal_role_name(principal) or "",
                )
            ]
        return []

    principals = list_firestore_users()
    options: list[AssignmentAssigneeOption] = []
    for p in principals:
        if p.status != UserStatus.ACTIVE:
            continue
        principal_roles = {
            canonicalize_role_name(role) or ""
            for role in (p.roles or [])
            if str(role).strip()
        }
        if not principal_roles.intersection(_assignable_roles):
            continue
        if p.project_ids and project_id.strip().upper() not in p.project_ids:
            continue
        options.append(
            AssignmentAssigneeOption(
                user_id=p.id,
                full_name=p.full_name,
                email=p.email,
                role_name=_principal_role_name(p) or "",
            )
        )
    options.sort(key=lambda item: (item.full_name.lower(), item.email.lower()))
    return options


@router.post("", response_model=AssignmentListItem, status_code=status.HTTP_201_CREATED)
def create_assignment(
    payload: AssignmentCreate,
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
):
    project_id = payload.project_id.strip().upper()

    # OPERATIVO can only create assignments for themselves.
    if user_has_any_role(current_user, ["OPERATIVO"], None) and not user_has_any_role(
        current_user, ["ADMIN", "COORD", "SUPERVISOR"], None
    ):
        if str(payload.assignee_user_id).strip() != str(current_user.id).strip():
            raise api_error(
                status_code=status.HTTP_403_FORBIDDEN,
                code="ASSIGNMENT_SELF_ONLY",
                message="Operativo users can only create assignments for themselves.",
            )

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
    assignee_principal = get_firestore_user_by_id(payload.assignee_user_id)
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
        **_assignment_assignee_projection(str(payload.assignee_user_id), assignee_principal),
        "created_by_user_id": str(current_user.id),
        "catalog_version_id": None,
        "activity_type_code": type_code,
        "title": title,
        "description": description_value,
        "gps_mismatch": False,
        "catalog_changed": False,
        "latitude": str(payload.latitude) if payload.latitude is not None else None,
        "longitude": str(payload.longitude) if payload.longitude is not None else None,
        "assignment_start_at": payload.start_at.isoformat(),
        "assignment_end_at": payload.end_at.isoformat(),
        "created_at": payload.start_at.isoformat(),
        "updated_at": payload.end_at.isoformat(),
        "deleted_at": None,
        "sync_version": _next_project_sync_version(client, project_id),
    }
    client.collection("activities").document(str(activity_uuid)).set(doc_payload)

    write_firestore_audit_log(
        action="ASSIGNMENT_CREATED",
        entity="activity",
        entity_id=str(activity_uuid),
        actor=current_user,
        details={
            "project_id": project_id,
            "title": title,
            "assigned_to_user_id": str(payload.assignee_user_id),
            "assigned_to_name": assignee_principal.full_name if assignee_principal else None,
            "assigned_to_role": _principal_role_name(assignee_principal),
            "start_at": payload.start_at.isoformat(),
            "end_at": payload.end_at.isoformat(),
            "risk": payload.risk,
        },
    )

    return AssignmentListItem(
        id=str(activity_uuid),
        project_id=project_id,
        assignee_user_id=payload.assignee_user_id,
        assignee_name=(assignee_principal.full_name if assignee_principal else "Sin responsable"),
        assignee_email=(assignee_principal.email if assignee_principal else None),
        activity_id=str(activity_uuid),
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
    current_assignee_user_id = _safe_uuid_str(doc.get("assigned_to_user_id"))
    current_assignee_principal = (
        get_firestore_user_by_id(current_assignee_user_id)
        if current_assignee_user_id
        else None
    )

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
            **_assignment_assignee_projection(None, None),
            "execution_state": "PENDIENTE",
            "deleted_at": canceled_at.isoformat(),
            "updated_at": canceled_at.isoformat(),
            "sync_version": _next_project_sync_version(client, str(doc.get("project_id") or "")),
        },
        merge=True,
    )
    write_firestore_audit_log(
        action="ASSIGNMENT_CANCELLED",
        entity="activity",
        entity_id=str(assignment_id),
        actor=current_user,
        details={
            "project_id": str(doc.get("project_id") or "").strip().upper() or None,
            "title": str(doc.get("title") or "").strip() or None,
            "previous_assignee_user_id": current_assignee_user_id or None,
            "previous_assignee_name": current_assignee_principal.full_name if current_assignee_principal else None,
            "previous_assignee_role": _principal_role_name(current_assignee_principal),
            "reason": cancel_reason,
        },
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
            **_assignment_assignee_projection(next_assignee_user_id, next_assignee_principal),
            "updated_at": transfer_at.isoformat(),
            "sync_version": next_sync_version,
        },
        merge=True,
    )

    updated_payload = dict(doc)
    updated_payload.update(
        _assignment_assignee_projection(next_assignee_user_id, next_assignee_principal)
    )
    updated_payload["updated_at"] = transfer_at.isoformat()
    updated_payload["sync_version"] = next_sync_version

    write_firestore_audit_log(
        action="ASSIGNMENT_TRANSFERRED",
        entity="activity",
        entity_id=str(assignment_id),
        actor=current_user,
        details={
            "project_id": project_id,
            "from_assignee_user_id": current_assignee_user_id,
            "from_assignee_name": previous_assignee_principal.full_name if previous_assignee_principal else None,
            "from_assignee_role": _principal_role_name(previous_assignee_principal),
            "to_assignee_user_id": next_assignee_user_id,
            "to_assignee_name": next_assignee_principal.full_name,
            "to_assignee_role": _principal_role_name(next_assignee_principal),
            "reason": payload.reason,
        },
    )

    return _build_assignment_list_item(
        doc_id=str(assignment_id),
        payload=updated_payload,
        project_id=project_id,
        assignee_principal=next_assignee_principal,
    )

