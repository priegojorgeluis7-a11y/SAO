import copy
import hashlib
import json
import logging
from collections import defaultdict
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status

from typing import Any
from app.api.deps import require_any_role
from app.core.enums import ProjectStatus
from app.core.config import settings
from app.core.firestore import get_firestore_client
from app.services.audit_service import write_firestore_audit_log
from app.schemas.project import (
    ProjectCreate,
    ProjectFrontLocationSummary,
    ProjectFrontSummary,
    ProjectLocationSummary,
    ProjectOut,
    ProjectStateSummary,
    ProjectUpdate,
)

router = APIRouter(prefix="/projects", tags=["projects"])
logger = logging.getLogger(__name__)

_EPOCH = datetime(2020, 1, 1, tzinfo=timezone.utc)
_HIDDEN_TEMPLATE_PROJECT_IDS = {"PROJECT_0", "P0"}

def _is_hidden_template_project(project_id: str | None) -> bool:
    return (project_id or "").strip().upper() in _HIDDEN_TEMPLATE_PROJECT_IDS

def _compute_bundle_etag(bundle: dict) -> str:
    effective_payload = bundle.get("effective") or {}
    encoded = json.dumps(effective_payload, sort_keys=True, default=str).encode("utf-8")
    return "sha256:" + hashlib.sha256(encoded).hexdigest()

def _resolve_current_firestore_version_id(client, project_id: str) -> str | None:
    normalized_project = project_id.strip().upper()
    current_snap = client.collection("catalog_current").document(normalized_project).get()
    if current_snap.exists:
        payload = current_snap.to_dict() or {}
        version_id = str(payload.get("version_id") or "").strip()
        if version_id:
            return version_id

    docs = (
        client.collection("catalog_versions")
        .where("project_id", "==", normalized_project)
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

def _load_firestore_bundle(client, project_id: str, version_id: str | None) -> dict | None:
    normalized_project = project_id.strip().upper()
    snapshots = []
    if version_id:
        snapshots.append(client.collection("catalog_bundles").document(f"{normalized_project}:{version_id}").get())
        snapshots.append(
            client.collection("catalog_bundles")
            .document(normalized_project)
            .collection("versions")
            .document(version_id)
            .get()
        )
    snapshots.append(client.collection("catalog_bundles").document(normalized_project).get())

    for snap in snapshots:
        if not snap.exists:
            continue
        payload = snap.to_dict() or {}
        if isinstance(payload, dict) and payload.get("schema") and isinstance(payload.get("effective"), dict):
            return payload
    return None

def _normalize_bundle_for_project(source_bundle: dict, project_id: str, version_id: str, now: datetime) -> dict:
    normalized_project = project_id.strip().upper()
    bundle = copy.deepcopy(source_bundle)
    bundle.setdefault("schema", "sao.catalog.bundle.v1")
    bundle.setdefault("effective", {})
    bundle.setdefault("meta", {})

    meta = bundle["meta"]
    meta["project_id"] = normalized_project
    meta["version_id"] = version_id
    meta["generated_at"] = now

    versions = meta.setdefault("versions", {})
    versions["effective"] = version_id
    versions["status"] = "published"
    meta["etag"] = _compute_bundle_etag(bundle)
    return bundle

def _write_firestore_catalog_version(client, project_id: str, version_id: str, bundle: dict, now: datetime) -> None:
    normalized_project = project_id.strip().upper()

    client.collection("catalog_bundles").document(normalized_project).set(bundle)
    client.collection("catalog_bundles").document(f"{normalized_project}:{version_id}").set(bundle)
    client.collection("catalog_bundles").document(normalized_project).collection("versions").document(version_id).set(bundle)

    client.collection("catalog_current").document(normalized_project).set(
        {
            "project_id": normalized_project,
            "version_id": version_id,
            "version_number": version_id,
            "published_at": now,
            "is_current": True,
            "hash": (bundle.get("meta") or {}).get("etag"),
            "updated_at": now,
        },
        merge=True,
    )

    for doc in (
        client.collection("catalog_versions")
        .where("project_id", "==", normalized_project)
        .where("is_current", "==", True)
        .stream()
    ):
        doc.reference.set({"is_current": False, "updated_at": now}, merge=True)

    client.collection("catalog_versions").document(version_id).set(
        {
            "id": version_id,
            "version_id": version_id,
            "version_number": version_id,
            "project_id": normalized_project,
            "status": "published",
            "hash": (bundle.get("meta") or {}).get("etag"),
            "published_at": now,
            "created_at": now,
            "updated_at": now,
            "is_current": True,
        },
        merge=True,
    )

def _normalize_front_entries(fronts_payload) -> list[dict]:
    normalized: list[dict] = []
    seen_codes: set[str] = set()

    for index, item in enumerate(fronts_payload, start=1):
        if isinstance(item, dict):
            raw_code = item.get("code")
            raw_name = item.get("name")
            pk_start = item.get("pk_start")
            pk_end = item.get("pk_end")
        else:
            raw_code = getattr(item, "code", None)
            raw_name = getattr(item, "name", None)
            pk_start = getattr(item, "pk_start", None)
            pk_end = getattr(item, "pk_end", None)

        cleaned_name = str(raw_name or "").strip()
        if not cleaned_name:
            continue

        cleaned_code = str(raw_code or "").strip().upper() or f"F{index}"
        if cleaned_code in seen_codes:
            continue

        normalized.append(
            {
                "code": cleaned_code,
                "name": cleaned_name,
                "pk_start": pk_start,
                "pk_end": pk_end,
            }
        )
        seen_codes.add(cleaned_code)

    return normalized

def _normalize_location_entries(location_payload) -> list[dict]:
    normalized: list[dict] = []
    seen_locations: set[tuple[str, str]] = set()

    for item in location_payload:
        if isinstance(item, dict):
            estado = str(item.get("estado") or "").strip()
            municipio = str(item.get("municipio") or "").strip()
        else:
            estado = str(getattr(item, "estado", "") or "").strip()
            municipio = str(getattr(item, "municipio", "") or "").strip()
        if not estado or not municipio:
            continue

        key = (estado, municipio)
        if key in seen_locations:
            continue

        normalized.append({"estado": estado, "municipio": municipio})
        seen_locations.add(key)

    normalized.sort(key=lambda item: (item["estado"], item["municipio"]))
    return normalized

def _normalize_front_location_entries(
    front_location_payload,
    fronts_payload,
    location_payload,
) -> list[dict]:
    fronts = _normalize_front_entries(fronts_payload or [])
    locations = _normalize_location_entries(location_payload or [])

    valid_front_codes = {item["code"] for item in fronts}
    front_name_by_code = {item["code"]: item["name"] for item in fronts}
    valid_locations = {(item["estado"], item["municipio"]) for item in locations}

    normalized: list[dict] = []
    seen: set[tuple[str, str, str]] = set()
    raw_entries = front_location_payload or []

    for item in raw_entries:
        if isinstance(item, dict):
            front_code = str(item.get("front_code") or item.get("code") or "").strip().upper()
            estado = str(item.get("estado") or "").strip()
            municipio = str(item.get("municipio") or "").strip()
        else:
            front_code = str(getattr(item, "front_code", "") or getattr(item, "code", "")).strip().upper()
            estado = str(getattr(item, "estado", "") or "").strip()
            municipio = str(getattr(item, "municipio", "") or "").strip()

        if not front_code or not estado or not municipio:
            continue
        if front_code not in valid_front_codes:
            continue
        if (estado, municipio) not in valid_locations:
            continue

        key = (front_code, estado, municipio)
        if key in seen:
            continue
        seen.add(key)
        normalized.append(
            {
                "front_code": front_code,
                "front_name": front_name_by_code.get(front_code),
                "estado": estado,
                "municipio": municipio,
            }
        )

    if normalized:
        normalized.sort(key=lambda item: (item["front_code"], item["estado"], item["municipio"]))
        return normalized

    fallback: list[dict] = []
    for front in fronts:
        for location in locations:
            fallback.append(
                {
                    "front_code": front["code"],
                    "front_name": front["name"],
                    "estado": location["estado"],
                    "municipio": location["municipio"],
                }
            )
    return fallback

def _build_state_summaries(location_scope: list[ProjectLocationSummary]) -> list[ProjectStateSummary]:
    grouped: dict[str, set[str]] = defaultdict(set)
    for item in location_scope:
        grouped[item.estado].add(item.municipio)

    return [
        ProjectStateSummary(estado=estado, municipios_count=len(municipios))
        for estado, municipios in sorted(grouped.items())
    ]

def _build_project_out(
    *,
    project_id: str,
    name: str,
    status_value: ProjectStatus | str,
    start_date,
    end_date,
    created_at: datetime,
    updated_at: datetime,
    fronts: list[dict] | list[ProjectFrontSummary],
    location_scope: list[dict] | list[ProjectLocationSummary],
    front_location_scope: list[dict] | list[ProjectFrontLocationSummary] | None = None,
) -> ProjectOut:
    front_summaries = [
        item
        if isinstance(item, ProjectFrontSummary)
        else ProjectFrontSummary(
            code=str(item.get("code") or ""),
            name=str(item.get("name") or ""),
            pk_start=item.get("pk_start"),
            pk_end=item.get("pk_end"),
        )
        for item in fronts
    ]
    front_summaries.sort(key=lambda item: (item.code, item.name))

    location_summaries = [
        item
        if isinstance(item, ProjectLocationSummary)
        else ProjectLocationSummary(
            estado=str(item.get("estado") or ""),
            municipio=str(item.get("municipio") or ""),
        )
        for item in location_scope
    ]
    location_summaries.sort(key=lambda item: (item.estado, item.municipio))

    front_location_summaries = [
        item
        if isinstance(item, ProjectFrontLocationSummary)
        else ProjectFrontLocationSummary(
            front_code=str(item.get("front_code") or ""),
            front_name=(item.get("front_name") if isinstance(item, dict) else None),
            estado=str(item.get("estado") or ""),
            municipio=str(item.get("municipio") or ""),
        )
        for item in (front_location_scope or [])
    ]
    front_location_summaries.sort(
        key=lambda item: (item.front_code, item.estado, item.municipio)
    )

    state_summaries = _build_state_summaries(location_summaries)

    return ProjectOut(
        id=project_id,
        name=name,
        status=status_value if isinstance(status_value, ProjectStatus) else ProjectStatus(str(status_value)),
        start_date=start_date,
        end_date=end_date,
        fronts_count=len(front_summaries),
        municipalities_count=len(location_summaries),
        states_count=len(state_summaries),
        fronts=front_summaries,
        location_scope=location_summaries,
        front_location_scope=front_location_summaries,
        states=state_summaries,
        created_at=created_at,
        updated_at=updated_at,
    )

def _load_project_fronts_from_firestore(client, project_id: str) -> list[ProjectFrontSummary]:
    docs = client.collection("fronts").where("project_id", "==", project_id).stream()
    fronts = [
        ProjectFrontSummary(
            code=str((doc.to_dict() or {}).get("code") or ""),
            name=str((doc.to_dict() or {}).get("name") or ""),
            pk_start=(doc.to_dict() or {}).get("pk_start"),
            pk_end=(doc.to_dict() or {}).get("pk_end"),
        )
        for doc in docs
    ]
    fronts.sort(key=lambda item: (item.code, item.name))
    return fronts

def _load_project_locations_from_firestore(payload: dict) -> list[ProjectLocationSummary]:
    return [
        ProjectLocationSummary(
            estado=str(item.get("estado") or ""),
            municipio=str(item.get("municipio") or ""),
        )
        for item in _normalize_location_entries(payload.get("location_scope") or [])
    ]

def _load_project_front_location_scope_from_firestore(
    payload: dict,
) -> list[ProjectFrontLocationSummary]:
    seen: set[tuple[str, str, str]] = set()
    rows: list[ProjectFrontLocationSummary] = []
    for item in payload.get("front_location_scope") or []:
        if not isinstance(item, dict):
            continue
        front_code = str(item.get("front_code") or item.get("code") or "").strip().upper()
        estado = str(item.get("estado") or "").strip()
        municipio = str(item.get("municipio") or "").strip()
        if not front_code or not estado or not municipio:
            continue
        key = (front_code, estado, municipio)
        if key in seen:
            continue
        seen.add(key)
        front_name_raw = item.get("front_name") or item.get("name")
        rows.append(
            ProjectFrontLocationSummary(
                front_code=front_code,
                front_name=str(front_name_raw) if front_name_raw is not None else None,
                estado=estado,
                municipio=municipio,
            )
        )
    rows.sort(key=lambda row: (row.front_code, row.estado, row.municipio))
    return rows

def _apply_firestore_fronts_update(client, project_id: str, fronts_payload) -> list[dict]:
    desired_fronts = _normalize_front_entries(fronts_payload)
    existing_docs = list(client.collection("fronts").where("project_id", "==", project_id).stream())
    existing_by_code = {
        str((doc.to_dict() or {}).get("code") or "").strip().upper(): doc
        for doc in existing_docs
    }
    desired_codes = {item["code"] for item in desired_fronts}

    blocked_codes: list[str] = []
    for code, doc in existing_by_code.items():
        if code in desired_codes:
            continue
        front_id = str((doc.to_dict() or {}).get("id") or doc.id)
        has_activities = any(client.collection("activities").where("front_id", "==", front_id).limit(1).stream())
        if has_activities:
            blocked_codes.append(code)

    if blocked_codes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "No se pueden eliminar frentes con referencias activas: "
                + ", ".join(sorted(blocked_codes))
            ),
        )

    batch = client.batch()
    for item in desired_fronts:
        existing = existing_by_code.get(item["code"])
        if existing is None:
            front_id = str(uuid4())
            batch.set(
                client.collection("fronts").document(front_id),
                {
                    "id": front_id,
                    "project_id": project_id,
                    "code": item["code"],
                    "name": item["name"],
                    "pk_start": item.get("pk_start"),
                    "pk_end": item.get("pk_end"),
                    "created_at": datetime.now(timezone.utc),
                },
            )
            continue

        batch.update(
            existing.reference,
            {
                "code": item["code"],
                "name": item["name"],
                "pk_start": item.get("pk_start"),
                "pk_end": item.get("pk_end"),
            },
        )

    for code, doc in existing_by_code.items():
        if code not in desired_codes:
            batch.delete(doc.reference)

    batch.commit()
    return desired_fronts

def _bootstrap_firestore_catalog(
    client,
    *,
    target_project_id: str,
    requested_source_version: str | None,
) -> str:
    now = datetime.now(timezone.utc)
    normalized_target = target_project_id.strip().upper()

    source_candidates = ["PROJECT_0", "TMQ"]
    source_bundle = None
    source_label = None
    for source_project in source_candidates:
        source_version = requested_source_version or _resolve_current_firestore_version_id(client, source_project)
        source_bundle = _load_firestore_bundle(client, source_project, source_version)
        if source_bundle:
            source_label = f"{source_project}:{source_version or 'current'}"
            break

    if source_bundle is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "No se encontrÃ³ catÃ¡logo base en Firestore (PROJECT_0/TMQ). "
                "Inicializa catÃ¡logo base antes de crear proyectos con bootstrap."
            ),
        )

    target_version = f"{normalized_target.lower()}-v1.0.0"
    target_bundle = _normalize_bundle_for_project(source_bundle, normalized_target, target_version, now)
    _write_firestore_catalog_version(client, normalized_target, target_version, target_bundle, now)
    return source_label or "unknown"

@router.get("", response_model=list[ProjectOut])
def list_projects(
    _current_user: Any = Depends(require_any_role(["ADMIN", "SUPERVISOR"])),
):
    client = get_firestore_client()
    result: list[ProjectOut] = []
    for doc in client.collection("projects").stream():
        p = doc.to_dict() or {}
        project_id = str(p.get("id") or doc.id)
        if _is_hidden_template_project(project_id):
            continue
        try:
            raw_start = p.get("start_date")
            start_date = raw_start.date() if isinstance(raw_start, datetime) else _EPOCH.date()
            raw_end = p.get("end_date")
            end_date = raw_end.date() if isinstance(raw_end, datetime) else None
            fronts = _load_project_fronts_from_firestore(client, project_id)
            location_scope = _load_project_locations_from_firestore(p)
            front_location_scope = _load_project_front_location_scope_from_firestore(p)
            result.append(
                _build_project_out(
                    project_id=project_id,
                    name=str(p.get("name") or ""),
                    status_value=ProjectStatus(str(p.get("status") or "active")),
                    start_date=start_date,
                    end_date=end_date,
                    created_at=p.get("created_at") or _EPOCH,
                    updated_at=p.get("updated_at") or _EPOCH,
                    fronts=fronts,
                    location_scope=location_scope,
                    front_location_scope=front_location_scope,
                )
            )
        except Exception:
            pass
    result.sort(key=lambda proj: proj.id)
    return result

@router.post("", response_model=ProjectOut, status_code=status.HTTP_201_CREATED)
def create_project(
    payload: ProjectCreate,
    current_user: Any = Depends(require_any_role(["ADMIN"])),
):
    client = get_firestore_client()
    code = payload.id.strip().upper()
    if len(code) > 10:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Project id max length is 10")
    if client.collection("projects").document(code).get().exists:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Project already exists")

    now = datetime.now(timezone.utc)
    start_dt = datetime.combine(payload.start_date, datetime.min.time()).replace(tzinfo=timezone.utc)
    end_dt = (
        datetime.combine(payload.end_date, datetime.min.time()).replace(tzinfo=timezone.utc)
        if payload.end_date else None
    )
    front_entries = _normalize_front_entries(payload.fronts)
    default_scope = [
        {"estado": "Ciudad de MÃ©xico", "municipio": "CuauhtÃ©moc"},
        {"estado": "Estado de MÃ©xico", "municipio": "TultitlÃ¡n"},
        {"estado": "QuerÃ©taro", "municipio": "QuerÃ©taro"},
    ]
    location_entries = _normalize_location_entries(payload.location_scope)
    if not location_entries and code == "TMQ":
        location_entries = default_scope
    front_location_entries = _normalize_front_location_entries(
        payload.front_location_scope,
        front_entries,
        location_entries,
    )

    client.collection("projects").document(code).set({
        "id": code,
        "name": payload.name.strip(),
        "status": payload.status.value,
        "start_date": start_dt,
        "end_date": end_dt,
        "location_scope": location_entries,
        "front_location_scope": front_location_entries,
        "created_at": now,
        "updated_at": now,
    })

    batch = client.batch()
    for idx, fe in enumerate(front_entries, start=1):
        fid = str(uuid4())
        batch.set(client.collection("fronts").document(fid), {
            "id": fid,
            "project_id": code,
            "code": fe["code"] or f"F{idx}",
            "name": fe["name"],
            "pk_start": fe.get("pk_start"),
            "pk_end": fe.get("pk_end"),
            "created_at": now,
        })
    if front_entries:
        batch.commit()

    if payload.bootstrap_from_tmq:
        source_label = _bootstrap_firestore_catalog(
            client,
            target_project_id=code,
            requested_source_version=payload.base_catalog_version,
        )
        logger.info(
            "[projects] Firestore bootstrap completed target=%s source=%s",
            code,
            source_label,
        )

    write_firestore_audit_log(
        action="PROJECT_CREATED",
        entity="project",
        entity_id=code,
        actor=current_user,
        details={"name": payload.name.strip()},
    )
    return _build_project_out(
        project_id=code,
        name=payload.name.strip(),
        status_value=payload.status,
        start_date=payload.start_date,
        end_date=payload.end_date,
        created_at=now,
        updated_at=now,
        fronts=front_entries,
        location_scope=location_entries,
        front_location_scope=front_location_entries,
    )

@router.put("/{project_id}", response_model=ProjectOut)
def update_project(
    project_id: str,
    payload: ProjectUpdate,
    current_user: Any = Depends(require_any_role(["ADMIN"])),
):
    provided_fields = payload.model_fields_set
    client = get_firestore_client()
    code = project_id.strip().upper()
    doc_ref = client.collection("projects").document(code)
    snap = doc_ref.get()
    if not snap.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")

    now = datetime.now(timezone.utc)
    p = snap.to_dict() or {}
    updates: dict = {"updated_at": now}
    if "name" in provided_fields:
        updates["name"] = payload.name.strip()
    if "status" in provided_fields:
        updates["status"] = payload.status.value
    if "start_date" in provided_fields:
        updates["start_date"] = datetime.combine(
            payload.start_date, datetime.min.time()
        ).replace(tzinfo=timezone.utc)
    if "end_date" in provided_fields:
        updates["end_date"] = (
            datetime.combine(payload.end_date, datetime.min.time()).replace(tzinfo=timezone.utc)
            if payload.end_date is not None
            else None
        )
    if "location_scope" in provided_fields:
        updates["location_scope"] = _normalize_location_entries(payload.location_scope or [])

    fronts_summary = _load_project_fronts_from_firestore(client, code)
    if "fronts" in provided_fields:
        fronts_payload = _apply_firestore_fronts_update(client, code, payload.fronts or [])
        fronts_summary = [
            ProjectFrontSummary(
                code=item["code"],
                name=item["name"],
                pk_start=item.get("pk_start"),
                pk_end=item.get("pk_end"),
            )
            for item in fronts_payload
        ]

    merged_payload = dict(p)
    merged_payload.update(updates)

    front_dicts = [
        {
            "code": item.code,
            "name": item.name,
            "pk_start": item.pk_start,
            "pk_end": item.pk_end,
        }
        for item in fronts_summary
    ]
    location_dicts = _normalize_location_entries(merged_payload.get("location_scope") or [])

    raw_front_location_payload = (
        payload.front_location_scope
        if "front_location_scope" in provided_fields
        else merged_payload.get("front_location_scope") or []
    )
    front_location_entries = _normalize_front_location_entries(
        raw_front_location_payload,
        front_dicts,
        location_dicts,
    )
    if (
        "front_location_scope" in provided_fields
        or "fronts" in provided_fields
        or "location_scope" in provided_fields
    ):
        updates["front_location_scope"] = front_location_entries

    doc_ref.update(updates)

    merged_payload = dict(p)
    merged_payload.update(updates)
    raw_start = merged_payload.get("start_date")
    start_date = raw_start.date() if isinstance(raw_start, datetime) else _EPOCH.date()
    raw_end = merged_payload.get("end_date")
    end_date = raw_end.date() if isinstance(raw_end, datetime) else None
    location_scope = _load_project_locations_from_firestore(merged_payload)
    front_location_scope = _load_project_front_location_scope_from_firestore(merged_payload)

    write_firestore_audit_log(
        action="PROJECT_UPDATED",
        entity="project",
        entity_id=code,
        actor=current_user,
        details={"fields_changed": list(provided_fields)},
    )
    return _build_project_out(
        project_id=code,
        name=str(merged_payload.get("name") or ""),
        status_value=ProjectStatus(str(merged_payload.get("status") or "active")),
        start_date=start_date,
        end_date=end_date,
        created_at=p.get("created_at") or _EPOCH,
        updated_at=now,
        fronts=fronts_summary,
        location_scope=location_scope,
        front_location_scope=front_location_scope,
    )

@router.delete("/{project_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_project(
    project_id: str,
    current_user: Any = Depends(require_any_role(["ADMIN"])),
):
    client = get_firestore_client()
    code = project_id.strip().upper()
    doc_ref = client.collection("projects").document(code)
    if not doc_ref.get().exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    doc_ref.delete()
    write_firestore_audit_log(
        action="PROJECT_DELETED",
        entity="project",
        entity_id=code,
        actor=current_user,
    )
    return None

