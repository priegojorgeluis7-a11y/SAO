from uuid import uuid4

from fastapi import APIRouter, Depends, Query, status
from app.core.api_errors import api_error

from app.api.deps import require_any_role
from app.core.firestore import get_firestore_client
from typing import Any
from app.schemas.territory import FrontCreate, FrontOut, LocationOut, LocationScopeCreate, StateSummaryOut

router = APIRouter(tags=["territory"])


@router.get("/fronts", response_model=list[FrontOut])
def list_fronts(
    project_id: str = Query(..., min_length=1, max_length=10),
    _current_user: Any = Depends(require_any_role(["ADMIN", "SUPERVISOR", "COORD", "OPERATIVO", "LECTOR"])),
):
    code = project_id.strip().upper()

    client = get_firestore_client()
    docs = (
        client.collection("fronts")
        .where("project_id", "==", code)
        .stream()
    )
    result: list[FrontOut] = []
    for doc in docs:
        f = doc.to_dict() or {}
        result.append(
            FrontOut(
                id=str(f.get("id") or doc.id),
                project_id=str(f.get("project_id") or code),
                code=str(f.get("code") or ""),
                name=str(f.get("name") or ""),
                pk_start=f.get("pk_start"),
                pk_end=f.get("pk_end"),
            )
        )
    result.sort(key=lambda fr: (fr.code, fr.name))
    return result


@router.post("/fronts", response_model=FrontOut, status_code=status.HTTP_201_CREATED)
def create_front(
    payload: FrontCreate,
    project_id: str = Query(..., min_length=1, max_length=10),
    _current_user: Any = Depends(require_any_role(["ADMIN"])),
):
    client = get_firestore_client()
    code = project_id.strip().upper()
    project_ref = client.collection("projects").document(code)
    project_doc = project_ref.get()
    if not project_doc.exists:
        raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="TERRITORY_PROJECT_NOT_FOUND", message="Project not found")

    front_code = (payload.code.strip().upper() if payload.code else "").strip()
    docs = [d.to_dict() or {} for d in client.collection("fronts").where("project_id", "==", code).stream()]

    if not front_code:
        front_code = f"F{len(docs) + 1}"

    if any(str((d.get("code") or "")).strip().upper() == front_code for d in docs):
        raise api_error(status_code=status.HTTP_409_CONFLICT, code="TERRITORY_FRONT_CODE_CONFLICT", message="Front code already exists in project")

    front_id = str(uuid4())
    payload_doc = {
        "id": front_id,
        "project_id": code,
        "code": front_code,
        "name": payload.name.strip(),
        "pk_start": payload.pk_start,
        "pk_end": payload.pk_end,
    }
    client.collection("fronts").document(front_id).set(payload_doc)

    return FrontOut(
        id=front_id,
        project_id=code,
        code=front_code,
        name=payload.name.strip(),
        pk_start=payload.pk_start,
        pk_end=payload.pk_end,
    )


@router.get("/locations/states", response_model=list[StateSummaryOut])
def list_project_states(
    project_id: str = Query(..., min_length=1, max_length=10),
    _current_user: Any = Depends(require_any_role(["ADMIN", "SUPERVISOR", "COORD", "OPERATIVO", "LECTOR"])),
):
    client = get_firestore_client()
    code = project_id.strip().upper()
    project_doc = client.collection("projects").document(code).get()
    if not project_doc.exists:
        return []

    payload = project_doc.to_dict() or {}
    scope = payload.get("location_scope") or []
    counts: dict[str, set[str]] = {}
    for item in scope:
        if not isinstance(item, dict):
            continue
        estado_item = str(item.get("estado") or "").strip()
        municipio_item = str(item.get("municipio") or "").strip()
        if not estado_item or not municipio_item:
            continue
        counts.setdefault(estado_item, set()).add(municipio_item)

    return [
        StateSummaryOut(estado=estado, municipios_count=len(municipios))
        for estado, municipios in sorted(counts.items(), key=lambda row: row[0])
    ]


@router.get("/locations", response_model=list[LocationOut])
def list_project_locations(
    project_id: str | None = Query(default=None, min_length=1, max_length=10),
    estado: str | None = Query(default=None),
    front_id: str | None = Query(default=None),
    _current_user: Any = Depends(require_any_role(["ADMIN", "SUPERVISOR", "COORD", "OPERATIVO", "LECTOR"])),
):
    client = get_firestore_client()
    resolved_project = project_id.strip().upper() if project_id else None
    if resolved_project is None and front_id:
        front_doc = client.collection("fronts").document(front_id).get()
        if not front_doc.exists:
            raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="TERRITORY_FRONT_NOT_FOUND", message="Front not found")
        front_payload = front_doc.to_dict() or {}
        resolved_project = str(front_payload.get("project_id") or "").strip().upper() or None

    if not resolved_project:
        return []

    project_doc = client.collection("projects").document(resolved_project).get()
    if not project_doc.exists:
        return []
    payload = project_doc.to_dict() or {}
    scope = payload.get("location_scope") or []

    result: list[LocationOut] = []
    seen: set[tuple[str, str]] = set()
    for item in scope:
        if not isinstance(item, dict):
            continue
        estado_item = str(item.get("estado") or "").strip()
        municipio_item = str(item.get("municipio") or "").strip()
        if not estado_item or not municipio_item:
            continue
        if estado and estado.strip() and estado_item != estado.strip():
            continue
        key = (estado_item, municipio_item)
        if key in seen:
            continue
        seen.add(key)
        result.append(
            LocationOut(
                id=str(item.get("id") or f"{estado_item}:{municipio_item}"),
                estado=estado_item,
                municipio=municipio_item,
            )
        )

    result.sort(key=lambda row: (row.estado, row.municipio))
    return result


@router.post("/projects/{project_id}/locations", response_model=list[LocationOut])
def upsert_project_locations(
    project_id: str,
    payload: list[LocationScopeCreate],
    _current_user: Any = Depends(require_any_role(["ADMIN"])),
):
    client = get_firestore_client()
    code = project_id.strip().upper()
    project_ref = client.collection("projects").document(code)
    project_doc = project_ref.get()
    if not project_doc.exists:
        raise api_error(status_code=status.HTTP_404_NOT_FOUND, code="TERRITORY_PROJECT_NOT_FOUND", message="Project not found")

    existing = (project_doc.to_dict() or {}).get("location_scope") or []
    merged: dict[tuple[str, str], dict] = {}

    for item in existing:
        if not isinstance(item, dict):
            continue
        estado_item = str(item.get("estado") or "").strip()
        municipio_item = str(item.get("municipio") or "").strip()
        if not estado_item or not municipio_item:
            continue
        merged[(estado_item, municipio_item)] = {
            "estado": estado_item,
            "municipio": municipio_item,
        }

    for entry in payload:
        estado_item = entry.estado.strip()
        municipio_item = entry.municipio.strip()
        if not estado_item or not municipio_item:
            continue
        merged[(estado_item, municipio_item)] = {
            "estado": estado_item,
            "municipio": municipio_item,
        }

    merged_rows = sorted(
        merged.values(),
        key=lambda item: (item["estado"], item["municipio"]),
    )
    project_ref.update(
        {
            "location_scope": merged_rows,
        }
    )

    return [
        LocationOut(
            id=f"{item['estado']}:{item['municipio']}",
            estado=item["estado"],
            municipio=item["municipio"],
        )
        for item in merged_rows
    ]

