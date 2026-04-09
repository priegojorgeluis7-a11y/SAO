"""Catalog API endpoints"""

import hashlib
import json
import logging
from datetime import datetime, timezone
from typing import Any, Optional
from uuid import NAMESPACE_URL, UUID, uuid5

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.deps import get_current_user, user_has_permission, verify_project_access
from app.core.config import settings
from app.core.firestore import get_firestore_client
from app.core.enums import CatalogStatus
from app.schemas.catalog import (
    CatalogVersionDigest,
    CatalogPackage,
    CatalogVersionPublish,
    CatalogVersionResponse,
)
from app.schemas.effective_catalog import (
    CurrentCatalogVersionResponse,
    DiffResponse,
    EffectiveCatalogResponse,
)
from app.schemas.catalog_editor import (
    ActivityCreateRequest,
    ActivityUpdateRequest,
    AttendeeCreateRequest,
    AttendeeUpdateRequest,
    CatalogEditorResponse,
    PurposeCreateRequest,
    PurposeUpdateRequest,
    RelActivityTopicUpsertRequest,
    ReorderEntityRequest,
    ResultCreateRequest,
    ResultUpdateRequest,
    SubcategoryCreateRequest,
    SubcategoryUpdateRequest,
    TopicCreateRequest,
    TopicUpdateRequest,
)
from app.schemas.catalog_bundle import (
    CatalogOp,
    CatalogPublishResponse,
    CatalogRollbackRequest,
    CatalogRollbackResponse,
    CatalogValidationResponse,
    ProjectOpsRequest,
)
from app.services.push_notification_service import notify_catalog_update

logger = logging.getLogger(__name__)


router = APIRouter(prefix="/catalog", tags=["catalog"])


def _enforce_catalog_permission(
    current_user: Any,
    permission_code: str,
    project_id: str | None = None,
) -> None:
    normalized_project_id = str(project_id or "").strip().upper() or None
    if normalized_project_id is not None:
        verify_project_access(current_user, normalized_project_id, None)
        allowed = user_has_permission(
            current_user,
            permission_code,
            None,
            project_id=normalized_project_id,
        )
        if allowed:
            return
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Missing permission: {permission_code} for project: {normalized_project_id}",
        )

    if user_has_permission(current_user, permission_code, None):
        return
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail=f"Missing permission: {permission_code}",
    )


def _as_uuid_or_none(value: Any) -> UUID | None:
    raw = str(value or "").strip()
    if not raw:
        return None
    try:
        return UUID(raw)
    except ValueError:
        return None


def _resolve_current_version_id_firestore(project_id: str | None = None) -> str:
    """Resolve current catalog version from Firestore for firestore-only mode."""
    client = get_firestore_client()
    normalized_project = (project_id or "").strip().upper()

    # Project-specific resolution: choose the freshest published/current payload.
    # This avoids serving stale versions when catalog_current wasn't updated
    # but a newer published row already exists in catalog_versions.
    if normalized_project:
        latest_payload = _latest_catalog_doc_firestore(normalized_project)
        if latest_payload:
            version_id = (
                str(latest_payload.get("version_id") or "").strip()
                or str(latest_payload.get("id") or "").strip()
            )
            if version_id:
                return version_id

    # Legacy global fallback when no project_id is provided.
    docs = (
        client.collection("catalog_versions")
        .where("is_current", "==", True)
        .limit(1)
        .stream()
    )
    for doc in docs:
        payload = doc.to_dict() or {}
        version_id = (
            (payload.get("version_id") or "").strip()
            or (payload.get("id") or "").strip()
            or doc.id
        )
        if version_id:
            return version_id

    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=(
            "No published catalog found in Firestore. "
            "Seed catalog_current/catalog_versions for this project."
        ),
    )


def _latest_catalog_doc_firestore(project_id: str) -> dict[str, Any] | None:
    """Return latest catalog version payload from Firestore for a project."""
    client = get_firestore_client()
    normalized_project = project_id.strip().upper()
    candidates: list[dict[str, Any]] = []

    # Candidate 1: explicit current pointer with embedded metadata.
    current_snap = client.collection("catalog_current").document(normalized_project).get()
    if current_snap.exists:
        payload = current_snap.to_dict() or {}
        if payload:
            payload.setdefault("project_id", normalized_project)
            payload.setdefault("_source_priority", 3)
            candidates.append(payload)

    # Candidate 2: is_current row in catalog_versions.
    try:
        docs = (
            client.collection("catalog_versions")
            .where("project_id", "==", normalized_project)
            .where("is_current", "==", True)
            .limit(1)
            .stream()
        )
        for doc in docs:
            payload = doc.to_dict() or {}
            payload.setdefault("id", doc.id)
            payload.setdefault("project_id", normalized_project)
            payload.setdefault("_source_priority", 2)
            candidates.append(payload)
    except Exception:
        logger.exception("Failed querying current catalog_versions for project_id=%s", normalized_project)

    # Candidate 3: latest published_at row.
    try:
        docs = (
            client.collection("catalog_versions")
            .where("project_id", "==", normalized_project)
            .order_by("published_at", direction="DESCENDING")
            .limit(1)
            .stream()
        )
        for doc in docs:
            payload = doc.to_dict() or {}
            payload.setdefault("id", doc.id)
            payload.setdefault("project_id", normalized_project)
            payload.setdefault("_source_priority", 1)
            candidates.append(payload)
    except Exception:
        logger.exception("Failed querying latest catalog_versions for project_id=%s", normalized_project)

    if not candidates:
        return None

    candidates.sort(
        key=lambda row: (
            _as_utc_datetime(row.get("published_at")) if row.get("published_at") else datetime.min.replace(tzinfo=timezone.utc),
            int(row.get("_source_priority") or 0),
        ),
        reverse=True,
    )
    best = dict(candidates[0])
    best.pop("_source_priority", None)
    return best


def _catalog_digest_firestore(project_id: str) -> CatalogVersionDigest:
    payload = _latest_catalog_doc_firestore(project_id)
    if not payload:
        return CatalogVersionDigest(
            version_id=None,
            version_number=None,
            hash=None,
            published_at=None,
        )

    raw_version_id = payload.get("version_id") or payload.get("id")
    published_at = _as_utc_datetime(payload.get("published_at")) if payload.get("published_at") else None
    # Apply the same UUID5 normalization used in _catalog_versions_firestore so that
    # semantic version strings like "tmq-v1.0.0" are returned as deterministic UUIDs.
    version_uuid = _as_uuid_or_none(raw_version_id)
    if version_uuid is None and raw_version_id:
        normalized_project = project_id.strip().upper()
        version_uuid = uuid5(NAMESPACE_URL, f"catalog-version:{normalized_project}:{raw_version_id}")
    return CatalogVersionDigest(
        version_id=version_uuid,
        version_number=(payload.get("version_number") or str(raw_version_id or "") or None),
        hash=(payload.get("hash") or payload.get("catalog_hash")),
        published_at=published_at,
    )


def _catalog_versions_firestore(
    project_id: str,
    status_filter: Optional[CatalogStatus],
    limit: int,
) -> list[CatalogVersionResponse]:
    """Return detailed catalog versions list from Firestore for one project."""
    client = get_firestore_client()
    normalized_project = project_id.strip().upper()

    docs = (
        client.collection("catalog_versions")
        .where("project_id", "==", normalized_project)
        .limit(max(limit, 1))
        .stream()
    )

    rows: list[CatalogVersionResponse] = []
    for doc in docs:
        payload = doc.to_dict() or {}

        raw_version_id = payload.get("version_id") or payload.get("id") or doc.id
        version_id = _as_uuid_or_none(raw_version_id)
        if version_id is None:
            # Keep compatibility with UUID response model using deterministic UUID.
            version_id = uuid5(NAMESPACE_URL, f"catalog-version:{normalized_project}:{raw_version_id}")

        status_raw = str(payload.get("status") or "published").strip().lower()
        if status_raw not in {s.value for s in CatalogStatus}:
            status_raw = CatalogStatus.PUBLISHED.value
        status_value = CatalogStatus(status_raw)

        if status_filter and status_value != status_filter:
            continue

        created_at = _as_utc_datetime(payload.get("created_at"))
        updated_at = _as_utc_datetime(payload.get("updated_at"))
        published_at_raw = payload.get("published_at")
        published_at = _as_utc_datetime(published_at_raw) if published_at_raw else None
        published_by_id = _as_uuid_or_none(payload.get("published_by_id"))

        rows.append(
            CatalogVersionResponse(
                id=version_id,
                project_id=normalized_project,
                version_number=str(payload.get("version_number") or raw_version_id),
                status=status_value,
                hash=payload.get("hash") or payload.get("catalog_hash"),
                notes=payload.get("notes"),
                published_by_id=published_by_id,
                published_at=published_at,
                created_at=created_at,
                updated_at=updated_at,
            )
        )

    rows.sort(key=lambda item: item.created_at, reverse=True)
    return rows[:limit]


def _as_utc_datetime(value: Any) -> datetime:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
            return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    return datetime.now(timezone.utc)


def _effective_from_bundle_payload(bundle: dict, project_id: str, version_id: str) -> dict:
    effective = (bundle.get("effective") or {}) if isinstance(bundle, dict) else {}
    entities = (effective.get("entities") or {}) if isinstance(effective, dict) else {}
    relations = (effective.get("relations") or {}) if isinstance(effective, dict) else {}
    meta = (bundle.get("meta") or {}) if isinstance(bundle, dict) else {}

    def _enabled(row: dict) -> bool:
        return bool(row.get("active", True))

    def _name_effective(row: dict) -> str:
        return str(row.get("name_effective") or row.get("name") or row.get("label") or row.get("id") or "")

    activities = [
        {
            "id": str(row.get("id") or ""),
            "name_effective": _name_effective(row),
            "description": row.get("description"),
            "is_enabled_effective": _enabled(row),
            "sort_order_effective": int(row.get("order") or 0),
            "color_effective": row.get("color"),
        }
        for row in (entities.get("activities") or [])
        if isinstance(row, dict) and str(row.get("id") or "").strip()
    ]

    subcategories = [
        {
            "id": str(row.get("id") or ""),
            "activity_id": str(row.get("activity_id") or ""),
            "name_effective": _name_effective(row),
            "description": row.get("description"),
            "is_enabled_effective": _enabled(row),
            "sort_order_effective": int(row.get("order") or 0),
            "color_effective": row.get("color"),
        }
        for row in (entities.get("subcategories") or [])
        if isinstance(row, dict)
        and str(row.get("id") or "").strip()
        and str(row.get("activity_id") or "").strip()
    ]

    purposes = [
        {
            "id": str(row.get("id") or ""),
            "activity_id": str(row.get("activity_id") or ""),
            "subcategory_id": row.get("subcategory_id"),
            "name_effective": _name_effective(row),
            "is_enabled_effective": _enabled(row),
            "sort_order_effective": int(row.get("order") or 0),
            "color_effective": row.get("color"),
        }
        for row in (entities.get("purposes") or [])
        if isinstance(row, dict)
        and str(row.get("id") or "").strip()
        and str(row.get("activity_id") or "").strip()
    ]

    topics = [
        {
            "id": str(row.get("id") or ""),
            "type": row.get("type"),
            "description": row.get("description"),
            "name_effective": _name_effective(row),
            "is_enabled_effective": _enabled(row),
            "sort_order_effective": int(row.get("order") or 0),
            "color_effective": row.get("color"),
        }
        for row in (entities.get("topics") or [])
        if isinstance(row, dict) and str(row.get("id") or "").strip()
    ]

    rel_activity_topics = [
        {
            "activity_id": str(row.get("activity_id") or ""),
            "topic_id": str(row.get("topic_id") or ""),
            "is_enabled_effective": bool(row.get("active", True)),
        }
        for row in (relations.get("activity_to_topics_suggested") or [])
        if isinstance(row, dict)
        and str(row.get("activity_id") or "").strip()
        and str(row.get("topic_id") or "").strip()
    ]

    results = [
        {
            "id": str(row.get("id") or ""),
            "name_effective": _name_effective(row),
            "category": str(row.get("category") or "General"),
            "severity_effective": row.get("severity"),
            "is_enabled_effective": _enabled(row),
            "sort_order_effective": int(row.get("order") or 0),
            "color_effective": row.get("color"),
        }
        for row in (entities.get("results") or [])
        if isinstance(row, dict) and str(row.get("id") or "").strip()
    ]

    attendees = [
        {
            "id": str(row.get("id") or ""),
            "type": str(row.get("type") or "General"),
            "description": row.get("description"),
            "name_effective": _name_effective(row),
            "is_enabled_effective": _enabled(row),
            "sort_order_effective": int(row.get("order") or 0),
            "color_effective": row.get("color"),
        }
        for row in (entities.get("assistants") or [])
        if isinstance(row, dict) and str(row.get("id") or "").strip()
    ]

    return {
        "meta": {
            "project_id": str(meta.get("project_id") or project_id),
            "version_id": str(meta.get("version_id") or version_id),
            "generated_at": _as_utc_datetime(meta.get("generated_at")),
        },
        "activities": activities,
        "subcategories": subcategories,
        "purposes": purposes,
        "topics": topics,
        "rel_activity_topics": rel_activity_topics,
        "results": results,
        "attendees": attendees,
    }


def _resolve_effective_catalog_firestore(project_id: str, version_id: str | None = None) -> dict:
    client = get_firestore_client()
    normalized_project = project_id.strip().upper()
    resolved_version = version_id or _resolve_current_version_id_firestore(project_id=normalized_project)

    candidate_snapshots = [
        client.collection("catalog_effective").document(f"{normalized_project}:{resolved_version}").get(),
        client.collection("catalog_effective").document(normalized_project).collection("versions").document(resolved_version).get(),
        client.collection("catalog_effective").document(normalized_project).get(),
        client.collection("catalog_bundles").document(f"{normalized_project}:{resolved_version}").get(),
        client.collection("catalog_bundles").document(normalized_project).get(),
        client.collection("catalog_versions").document(resolved_version).get(),
    ]

    for snap in candidate_snapshots:
        if not snap.exists:
            continue
        payload = snap.to_dict() or {}
        if "meta" in payload and "activities" in payload and "subcategories" in payload:
            payload.setdefault("meta", {})
            payload["meta"].setdefault("project_id", normalized_project)
            payload["meta"].setdefault("version_id", resolved_version)
            payload["meta"]["generated_at"] = _as_utc_datetime(payload["meta"].get("generated_at"))
            return payload
        if "schema" in payload and "effective" in payload:
            return _effective_from_bundle_payload(payload, normalized_project, resolved_version)

    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=(
            "No effective catalog found in Firestore for project/version. "
            "Seed catalog_effective or catalog_bundles documents."
        ),
    )


def _resolve_catalog_bundle_firestore(
    project_id: str,
    version_id: str | None = None,
    include_editor: bool = False,
) -> dict:
    client = get_firestore_client()
    normalized_project = project_id.strip().upper()
    resolved_version = version_id or _resolve_current_version_id_firestore(project_id=normalized_project)

    current_project_snapshot = client.collection("catalog_bundles").document(normalized_project).get()
    version_snapshots = [
        client.collection("catalog_bundles").document(f"{normalized_project}:{resolved_version}").get(),
        client.collection("catalog_bundles").document(normalized_project).collection("versions").document(resolved_version).get(),
    ]

    snapshots = [current_project_snapshot, *version_snapshots] if include_editor else [*version_snapshots, current_project_snapshot]

    for snap in snapshots:
        if not snap.exists:
            continue
        payload = snap.to_dict() or {}
        if not isinstance(payload, dict):
            continue
        if payload.get("schema") and isinstance(payload.get("effective"), dict):
            payload_meta = payload.get("meta") if isinstance(payload.get("meta"), dict) else {}
            payload_version = str(payload_meta.get("version_id") or "").strip()
            if include_editor and snap.reference.id == normalized_project and payload_version and payload_version != resolved_version:
                continue
            payload.setdefault("meta", {})
            payload["meta"].setdefault("project_id", normalized_project)
            payload["meta"].setdefault("version_id", resolved_version)
            payload["meta"]["generated_at"] = _as_utc_datetime(payload["meta"].get("generated_at"))
            if include_editor:
                payload.setdefault("editor", {})
                return payload
            return {
                "schema": payload.get("schema"),
                "meta": payload.get("meta", {}),
                "effective": payload.get("effective", {}),
            }

    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=(
            "No catalog bundle found in Firestore for project/version. "
            "Seed catalog_bundles documents."
        ),
    )


def _catalog_bundle_doc_ref(project_id: str):
    client = get_firestore_client()
    normalized_project = project_id.strip().upper()
    return client.collection("catalog_bundles").document(normalized_project)


def _write_current_bundle_firestore(project_id: str, bundle: dict) -> None:
    doc = _catalog_bundle_doc_ref(project_id)
    doc.set(bundle)


def _entity_collection_name(entity: str) -> str:
    mapping = {
        "activities": "activities",
        "subcategories": "subcategories",
        "purposes": "purposes",
        "topics": "topics",
        "results": "results",
        "assistants": "assistants",
        "attendees": "assistants",
    }
    return mapping.get(entity, entity)


def _default_entity_row(entity: str, entity_id: str, data: dict) -> dict:
    base = {"id": entity_id, "active": True, "order": int(data.get("order") or 0)}
    if entity == "activities":
        base.update({"name": data.get("name") or entity_id, "description": data.get("description")})
    elif entity == "subcategories":
        base.update(
            {
                "activity_id": data.get("activity_id") or "",
                "name": data.get("name") or entity_id,
                "description": data.get("description"),
            }
        )
    elif entity == "purposes":
        base.update(
            {
                "activity_id": data.get("activity_id") or "",
                "subcategory_id": data.get("subcategory_id"),
                "name": data.get("name") or entity_id,
            }
        )
    elif entity == "topics":
        base.update(
            {
                "type": data.get("type"),
                "name": data.get("name") or entity_id,
                "description": data.get("description"),
            }
        )
    elif entity == "results":
        base.update(
            {
                "category": data.get("category") or "General",
                "name": data.get("name") or entity_id,
                "description": data.get("description"),
            }
        )
    elif entity in {"assistants", "attendees"}:
        base.update(
            {
                "type": data.get("type") or "General",
                "name": data.get("name") or entity_id,
                "description": data.get("description"),
            }
        )
    return base


def _apply_project_ops_firestore(bundle: dict, ops: list[CatalogOp]) -> dict:
    effective = bundle.setdefault("effective", {})
    entities = effective.setdefault("entities", {})
    relations = effective.setdefault("relations", {})

    rel_rows = relations.setdefault("activity_to_topics_suggested", [])

    for op in ops:
        data = op.data or {}
        if op.entity == "activity_to_topics_suggested":
            activity_id = str(data.get("activity_id") or "").strip()
            topic_id = str(data.get("topic_id") or "").strip()
            if not activity_id or not topic_id:
                continue

            idx = next(
                (
                    i
                    for i, row in enumerate(rel_rows)
                    if isinstance(row, dict)
                    and str(row.get("activity_id") or "") == activity_id
                    and str(row.get("topic_id") or "") == topic_id
                ),
                None,
            )
            if op.op == "delete":
                if idx is not None:
                    rel_rows.pop(idx)
                continue

            if op.op in {"rel_deactivate", "deactivate"}:
                if idx is not None:
                    rel_rows[idx]["active"] = False
                continue

            row = {"activity_id": activity_id, "topic_id": topic_id, "active": bool(data.get("active", True))}
            if idx is None:
                rel_rows.append(row)
            else:
                rel_rows[idx].update(row)
            continue

        entity_name = _entity_collection_name(op.entity)
        rows = entities.setdefault(entity_name, [])
        idx = next(
            (
                i
                for i, row in enumerate(rows)
                if isinstance(row, dict) and str(row.get("id") or "") == op.id
            ),
            None,
        )

        if op.op == "delete":
            if idx is not None:
                rows.pop(idx)
            continue

        if op.op == "deactivate":
            if idx is not None:
                rows[idx]["active"] = False
            continue

        if op.op == "activate":
            if idx is not None:
                rows[idx]["active"] = True
            continue

        if op.op == "reorder":
            if idx is not None:
                rows[idx]["order"] = int(data.get("order") or data.get("sort_order") or rows[idx].get("order") or 0)
            continue

        # upsert / patch
        if idx is None:
            rows.append(_default_entity_row(op.entity, op.id, data))
            idx = len(rows) - 1

        updates = {}
        if "name" in data:
            updates["name"] = data.get("name")
        if "description" in data:
            updates["description"] = data.get("description")
        if "active" in data:
            updates["active"] = bool(data.get("active"))
        if "order" in data or "sort_order" in data:
            updates["order"] = int(data.get("order") or data.get("sort_order") or 0)
        for key in ("activity_id", "subcategory_id", "type", "category"):
            if key in data:
                updates[key] = data.get(key)
        rows[idx].update(updates)

    return bundle


def _resolve_editor_project_firestore(project_id: str | None, version_id: str | None) -> str:
    normalized_project = (project_id or "").strip().upper()
    if normalized_project:
        return normalized_project
    if not version_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="project_id is required when version_id is not provided",
        )
    snap = get_firestore_client().collection("catalog_versions").document(version_id).get()
    if not snap.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Catalog version not found")
    payload = snap.to_dict() or {}
    resolved = str(payload.get("project_id") or "").strip().upper()
    if not resolved:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not resolve project_id from version",
        )
    return resolved


def _firestore_apply_editor_op(project_id: str, version_id: str | None, op: CatalogOp) -> None:
    resolved_version = version_id or _resolve_current_version_id_firestore(project_id)
    bundle = _resolve_catalog_bundle_firestore(project_id=project_id, version_id=resolved_version, include_editor=True)
    bundle = _apply_project_ops_firestore(bundle, [op])
    bundle.setdefault("meta", {})
    bundle["meta"]["project_id"] = project_id
    bundle["meta"]["version_id"] = resolved_version
    bundle["meta"]["generated_at"] = datetime.now(timezone.utc)
    _write_current_bundle_firestore(project_id, bundle)


def _editor_response_from_firestore(project_id: str, version_id: str | None = None) -> dict:
    bundle = _resolve_catalog_bundle_firestore(project_id=project_id, version_id=version_id, include_editor=True)
    effective = (bundle.get("effective") or {}) if isinstance(bundle, dict) else {}
    entities = (effective.get("entities") or {}) if isinstance(effective, dict) else {}
    relations = (effective.get("relations") or {}) if isinstance(effective, dict) else {}
    meta = (bundle.get("meta") or {}) if isinstance(bundle, dict) else {}

    def _name(row: dict) -> str:
        return str(row.get("name") or row.get("label") or row.get("id") or "")

    return {
        "meta": {
            "project_id": str(meta.get("project_id") or project_id),
            "version_id": str(meta.get("version_id") or (version_id or _resolve_current_version_id_firestore(project_id))),
            "generated_at": _as_utc_datetime(meta.get("generated_at")),
        },
        "activities": [
            {
                "id": str(row.get("id") or ""),
                "name": _name(row),
                "description": row.get("description"),
                "is_active": bool(row.get("active", True)),
                "sort_order": int(row.get("order") or 0),
            }
            for row in (entities.get("activities") or [])
            if isinstance(row, dict) and str(row.get("id") or "").strip()
        ],
        "subcategories": [
            {
                "id": str(row.get("id") or ""),
                "activity_id": str(row.get("activity_id") or ""),
                "name": _name(row),
                "description": row.get("description"),
                "is_active": bool(row.get("active", True)),
                "sort_order": int(row.get("order") or 0),
            }
            for row in (entities.get("subcategories") or [])
            if isinstance(row, dict) and str(row.get("id") or "").strip() and str(row.get("activity_id") or "").strip()
        ],
        "purposes": [
            {
                "id": str(row.get("id") or ""),
                "activity_id": str(row.get("activity_id") or ""),
                "subcategory_id": row.get("subcategory_id"),
                "name": _name(row),
                "is_active": bool(row.get("active", True)),
                "sort_order": int(row.get("order") or 0),
            }
            for row in (entities.get("purposes") or [])
            if isinstance(row, dict) and str(row.get("id") or "").strip() and str(row.get("activity_id") or "").strip()
        ],
        "topics": [
            {
                "id": str(row.get("id") or ""),
                "type": row.get("type"),
                "name": _name(row),
                "description": row.get("description"),
                "is_active": bool(row.get("active", True)),
                "sort_order": int(row.get("order") or 0),
            }
            for row in (entities.get("topics") or [])
            if isinstance(row, dict) and str(row.get("id") or "").strip()
        ],
        "rel_activity_topics": [
            {
                "activity_id": str(row.get("activity_id") or ""),
                "topic_id": str(row.get("topic_id") or ""),
                "is_active": bool(row.get("active", True)),
            }
            for row in (relations.get("activity_to_topics_suggested") or [])
            if isinstance(row, dict) and str(row.get("activity_id") or "").strip() and str(row.get("topic_id") or "").strip()
        ],
        "results": [
            {
                "id": str(row.get("id") or ""),
                "category": str(row.get("category") or "General"),
                "name": _name(row),
                "description": row.get("description"),
                "is_active": bool(row.get("active", True)),
                "sort_order": int(row.get("order") or 0),
            }
            for row in (entities.get("results") or [])
            if isinstance(row, dict) and str(row.get("id") or "").strip()
        ],
        "attendees": [
            {
                "id": str(row.get("id") or ""),
                "type": str(row.get("type") or "General"),
                "name": _name(row),
                "description": row.get("description"),
                "is_active": bool(row.get("active", True)),
                "sort_order": int(row.get("order") or 0),
            }
            for row in (entities.get("assistants") or [])
            if isinstance(row, dict) and str(row.get("id") or "").strip()
        ],
    }


def _catalog_package_from_firestore(project_id: str, version_id: str | None = None) -> dict:
    normalized_project = project_id.strip().upper()
    resolved_version = version_id or _resolve_current_version_id_firestore(normalized_project)
    bundle = _resolve_catalog_bundle_firestore(project_id=normalized_project, version_id=resolved_version, include_editor=False)
    effective = (bundle.get("effective") or {}) if isinstance(bundle, dict) else {}
    entities = (effective.get("entities") or {}) if isinstance(effective, dict) else {}
    meta = (bundle.get("meta") or {}) if isinstance(bundle, dict) else {}
    latest = _latest_catalog_doc_firestore(normalized_project) or {}

    resolved_version_uuid = _as_uuid_or_none(resolved_version) or uuid5(
        NAMESPACE_URL,
        f"catalog-version:{normalized_project}:{resolved_version}",
    )
    published_at = _as_utc_datetime(latest.get("published_at") or meta.get("generated_at"))
    version_hash = str(latest.get("hash") or latest.get("catalog_hash") or meta.get("etag") or "") or f"{normalized_project}:{resolved_version}"

    activity_types = [
        {
            "id": _as_uuid_or_none(row.get("id")) or uuid5(NAMESPACE_URL, f"activity-type:{normalized_project}:{resolved_version}:{row.get('id')}") ,
            "version_id": resolved_version_uuid,
            "code": str(row.get("id") or ""),
            "name": str(row.get("name") or row.get("label") or row.get("id") or ""),
            "description": row.get("description"),
            "icon": row.get("icon"),
            "color": row.get("color") if isinstance(row.get("color"), str) and str(row.get("color")).startswith("#") else None,
            "sort_order": int(row.get("order") or 0),
            "is_active": bool(row.get("active", True)),
            "requires_approval": False,
            "max_duration_minutes": None,
            "notification_email": None,
            "created_at": published_at,
            "updated_at": published_at,
        }
        for row in (entities.get("activities") or [])
        if isinstance(row, dict) and str(row.get("id") or "").strip()
    ]

    return {
        "version_id": resolved_version_uuid,
        "version_number": str(latest.get("version_number") or resolved_version),
        "project_id": normalized_project,
        "hash": version_hash,
        "published_at": published_at,
        "activity_types": activity_types,
        "event_types": [],
        "form_fields": [],
        "workflow_states": [],
        "workflow_transitions": [],
        "evidence_rules": [],
        "checklist_templates": [],
    }


def _catalog_version_response_from_firestore(project_id: str, version_id: str) -> CatalogVersionResponse:
    normalized_project = project_id.strip().upper()
    doc = _latest_catalog_doc_firestore(normalized_project) or {}
    raw_status = str(doc.get("status") or "published").strip().lower()
    status_value = CatalogStatus(raw_status) if raw_status in {s.value for s in CatalogStatus} else CatalogStatus.PUBLISHED
    response_id = _as_uuid_or_none(version_id) or uuid5(NAMESPACE_URL, f"catalog-version:{normalized_project}:{version_id}")
    now = datetime.now(timezone.utc)
    return CatalogVersionResponse(
        id=response_id,
        project_id=normalized_project,
        version_number=str(doc.get("version_number") or version_id),
        status=status_value,
        hash=str(doc.get("hash") or doc.get("catalog_hash") or "") or None,
        notes=doc.get("notes"),
        published_by_id=_as_uuid_or_none(doc.get("published_by_id")),
        published_at=_as_utc_datetime(doc.get("published_at")) if doc.get("published_at") else None,
        created_at=_as_utc_datetime(doc.get("created_at") or now),
        updated_at=_as_utc_datetime(doc.get("updated_at") or now),
    )


def _catalog_hash_firestore(payload: dict) -> str:
    def _normalize(value: Any):
        if isinstance(value, datetime):
            return value.isoformat()
        if isinstance(value, list):
            return [_normalize(item) for item in value]
        if isinstance(value, dict):
            return {k: _normalize(v) for k, v in value.items()}
        return value

    normalized = _normalize(payload)
    raw = json.dumps(normalized, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _diff_effective_catalog_firestore(project_id: str, from_version_id: str, to_version_id: str) -> dict:
    effective_from = _resolve_effective_catalog_firestore(project_id=project_id, version_id=from_version_id)
    effective_to = _resolve_effective_catalog_firestore(project_id=project_id, version_id=to_version_id)

    def _sort_by_id(items: list[dict], key: str = "id") -> list[dict]:
        return sorted(items, key=lambda item: item.get(key) or "")

    def _sort_rel(items: list[dict]) -> list[dict]:
        return sorted(items, key=lambda item: (item.get("activity_id") or "", item.get("topic_id") or ""))

    def _build_changes(
        items_from: list[dict],
        items_to: list[dict],
        key_fn,
        sort_fn,
    ) -> dict:
        from_map = {key_fn(item): item for item in items_from}
        to_map = {key_fn(item): item for item in items_to}

        upserts = [item for key, item in to_map.items() if key not in from_map or item != from_map[key]]
        deletes = sorted([key for key in from_map.keys() if key not in to_map])
        return {"upserts": sort_fn(upserts), "deletes": deletes}

    changes = {
        "activities": _build_changes(
            effective_from.get("activities", []),
            effective_to.get("activities", []),
            lambda item: item["id"],
            lambda items: _sort_by_id(items),
        ),
        "subcategories": _build_changes(
            effective_from.get("subcategories", []),
            effective_to.get("subcategories", []),
            lambda item: item["id"],
            lambda items: _sort_by_id(items),
        ),
        "purposes": _build_changes(
            effective_from.get("purposes", []),
            effective_to.get("purposes", []),
            lambda item: item["id"],
            lambda items: _sort_by_id(items),
        ),
        "topics": _build_changes(
            effective_from.get("topics", []),
            effective_to.get("topics", []),
            lambda item: item["id"],
            lambda items: _sort_by_id(items),
        ),
        "rel_activity_topics": _build_changes(
            effective_from.get("rel_activity_topics", []),
            effective_to.get("rel_activity_topics", []),
            lambda item: f"{item.get('activity_id') or ''}|{item.get('topic_id') or ''}",
            lambda items: _sort_rel(items),
        ),
        "results": _build_changes(
            effective_from.get("results", []),
            effective_to.get("results", []),
            lambda item: item["id"],
            lambda items: _sort_by_id(items),
        ),
        "attendees": _build_changes(
            effective_from.get("attendees", []),
            effective_to.get("attendees", []),
            lambda item: item["id"],
            lambda items: _sort_by_id(items),
        ),
        # Firestore effective payload does not persist SQL override rows explicitly.
        "overrides": {"upserts": [], "deletes": []},
    }

    catalog_hash = _catalog_hash_firestore(
        {
            "meta": {"project_id": project_id, "version_id": to_version_id},
            "activities": effective_to.get("activities", []),
            "subcategories": effective_to.get("subcategories", []),
            "purposes": effective_to.get("purposes", []),
            "topics": effective_to.get("topics", []),
            "rel_activity_topics": effective_to.get("rel_activity_topics", []),
            "results": effective_to.get("results", []),
            "attendees": effective_to.get("attendees", []),
        }
    )

    return {
        "meta": {
            "project_id": project_id,
            "from_version_id": from_version_id,
            "to_version_id": to_version_id,
            "generated_at": datetime.now(timezone.utc),
            "catalog_hash": catalog_hash,
        },
        "changes": changes,
    }


def _validate_bundle_firestore(bundle: dict) -> dict:
    effective = (bundle.get("effective") or {}) if isinstance(bundle, dict) else {}
    entities = (effective.get("entities") or {}) if isinstance(effective, dict) else {}
    relations = (effective.get("relations") or {}) if isinstance(effective, dict) else {}

    activities = [x for x in (entities.get("activities") or []) if isinstance(x, dict)]
    subcategories = [x for x in (entities.get("subcategories") or []) if isinstance(x, dict)]
    purposes = [x for x in (entities.get("purposes") or []) if isinstance(x, dict)]
    topics = [x for x in (entities.get("topics") or []) if isinstance(x, dict)]
    rels = [x for x in (relations.get("activity_to_topics_suggested") or []) if isinstance(x, dict)]

    activity_ids = {str(x.get("id") or "") for x in activities}
    subcategory_ids = {str(x.get("id") or "") for x in subcategories}
    topic_ids = {str(x.get("id") or "") for x in topics}

    issues: list[dict[str, Any]] = []

    for s in subcategories:
        aid = str(s.get("activity_id") or "")
        if aid and aid not in activity_ids:
            issues.append(
                {
                    "code": "BROKEN_FK",
                    "severity": "error",
                    "message": f"Subcategory '{s.get('id')}' references unknown activity '{aid}'",
                    "entity_id": s.get("id"),
                }
            )

    for p in purposes:
        aid = str(p.get("activity_id") or "")
        sid = str(p.get("subcategory_id") or "") if p.get("subcategory_id") is not None else ""
        if aid and aid not in activity_ids:
            issues.append(
                {
                    "code": "BROKEN_FK",
                    "severity": "error",
                    "message": f"Purpose '{p.get('id')}' references unknown activity '{aid}'",
                    "entity_id": p.get("id"),
                }
            )
        if sid and sid not in subcategory_ids:
            issues.append(
                {
                    "code": "BROKEN_FK",
                    "severity": "error",
                    "message": f"Purpose '{p.get('id')}' references unknown subcategory '{sid}'",
                    "entity_id": p.get("id"),
                }
            )

    for r in rels:
        aid = str(r.get("activity_id") or "")
        tid = str(r.get("topic_id") or "")
        if aid and aid not in activity_ids:
            issues.append(
                {
                    "code": "BROKEN_FK",
                    "severity": "error",
                    "message": f"Relation activity_id='{aid}' does not exist",
                    "entity_id": aid,
                }
            )
        if tid and tid not in topic_ids:
            issues.append(
                {
                    "code": "BROKEN_FK",
                    "severity": "error",
                    "message": f"Relation topic_id='{tid}' does not exist",
                    "entity_id": tid,
                }
            )

    status_value = "error" if any(i["severity"] == "error" for i in issues) else "ok"
    return {"status": status_value, "issues": issues}


def _publish_bundle_firestore(project_id: str) -> dict:
    project = project_id.strip().upper()
    now = datetime.now(timezone.utc)
    version_id = f"{project}@{now.strftime('%Y-%m-%dT%H:%M:%SZ')}"

    bundle = _resolve_catalog_bundle_firestore(project_id=project, include_editor=True)
    bundle.setdefault("meta", {})
    bundle["meta"]["project_id"] = project
    bundle["meta"]["version_id"] = version_id
    bundle["meta"]["generated_at"] = now
    versions = bundle["meta"].setdefault("versions", {})
    versions["effective"] = version_id
    versions["status"] = "published"

    # Persist current bundle
    _write_current_bundle_firestore(project, bundle)

    # Persist immutable snapshot
    client = get_firestore_client()
    client.collection("catalog_bundles").document(project).collection("versions").document(version_id).set(bundle)

    # Update current pointer and versions index
    current_ref = client.collection("catalog_current").document(project)
    current_ref.set(
        {
            "project_id": project,
            "version_id": version_id,
            "version_number": version_id,
            "published_at": now,
            "is_current": True,
            "hash": (bundle.get("meta") or {}).get("etag"),
        },
        merge=True,
    )

    # Demote existing current rows for project
    for doc in (
        client.collection("catalog_versions")
        .where("project_id", "==", project)
        .where("is_current", "==", True)
        .stream()
    ):
        doc.reference.set({"is_current": False}, merge=True)

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

    try:
        notify_catalog_update(project_id=project, version_id=version_id)
    except Exception:
        logger.exception(
            "Failed sending catalog update push project_id=%s version_id=%s",
            project,
            version_id,
        )

    return {"version_id": version_id, "published_at": now, "status": "published"}


def _rollback_bundle_firestore(project_id: str, to_version: str) -> dict:
    project = project_id.strip().upper()
    now = datetime.now(timezone.utc)

    bundle = _resolve_catalog_bundle_firestore(project_id=project, version_id=to_version, include_editor=True)
    bundle.setdefault("meta", {})
    bundle["meta"]["project_id"] = project
    bundle["meta"]["version_id"] = to_version
    bundle["meta"]["generated_at"] = now
    versions = bundle["meta"].setdefault("versions", {})
    versions["effective"] = to_version
    versions["status"] = "published"

    _write_current_bundle_firestore(project, bundle)

    client = get_firestore_client()
    for doc in (
        client.collection("catalog_versions")
        .where("project_id", "==", project)
        .where("is_current", "==", True)
        .stream()
    ):
        doc.reference.set({"is_current": False}, merge=True)

    client.collection("catalog_versions").document(to_version).set(
        {
            "id": to_version,
            "version_id": to_version,
            "version_number": to_version,
            "project_id": project,
            "status": "published",
            "updated_at": now,
            "is_current": True,
        },
        merge=True,
    )

    client.collection("catalog_current").document(project).set(
        {
            "project_id": project,
            "version_id": to_version,
            "version_number": to_version,
            "published_at": now,
            "is_current": True,
            "hash": (bundle.get("meta") or {}).get("etag"),
        },
        merge=True,
    )

    try:
        notify_catalog_update(project_id=project, version_id=to_version)
    except Exception:
        logger.exception(
            "Failed sending catalog rollback push project_id=%s version_id=%s",
            project,
            to_version,
        )

    return {"version_id": to_version, "restored_at": now}


@router.get("/latest", response_model=CatalogPackage)
def get_latest_catalog(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    current_user: Any = Depends(get_current_user),
):
    """
    Descarga el catálogo PUBLISHED más reciente para un proyecto.

    Usado por la app móvil para obtener el catálogo completo.
    En modo Firestore usa GET /catalog/bundle (formato sao.catalog.bundle.v1).
    """
    _enforce_catalog_permission(current_user, "catalog.view", project_id)
    return _catalog_package_from_firestore(project_id=project_id)


@router.get("/check-updates")
def check_catalog_updates(
    project_id: str = Query(..., description="Project ID"),
    # Bug fix: current_hash es Optional — en el primer sync la app no tiene hash.
    # Con Query(...) el backend devolvía 422 antes de verificar el token,
    # rompiendo silenciosamente el primer sync.
    # Si es None → siempre retorna update_available=True (fuerza descarga inicial).
    current_hash: Optional[str] = Query(None, description="Current catalog hash"),
    current_user: Any = Depends(get_current_user),
):
    """
    Verifica si hay actualizaciones disponibles del catálogo.

    Compara el hash local con el hash del catálogo publicado más reciente.
    Si current_hash es None (primer sync), siempre retorna update_available=True.
    """
    _enforce_catalog_permission(current_user, "catalog.view", project_id)
    latest = _latest_catalog_doc_firestore(project_id)
    if not latest:
        return {"update_available": False, "message": "No published catalog found"}

    latest_hash = latest.get("hash") or latest.get("catalog_hash")
    version_id = latest.get("version_id") or latest.get("id")
    version_number = latest.get("version_number") or str(version_id or "")
    published_at = _as_utc_datetime(latest.get("published_at"))

    if current_hash is None or latest_hash != current_hash:
        return {
            "update_available": True,
            "new_version": version_number,
            "new_hash": latest_hash,
            "published_at": published_at.isoformat(),
        }
    return {"update_available": False, "message": "Catalog is up to date"}


@router.get("/versions", response_model=list[CatalogVersionResponse] | dict[str, CatalogVersionDigest])
def list_catalog_versions(
    project_id: Optional[str] = Query(None, description="Project ID"),
    project_ids: Optional[str] = Query(
        None,
        description="Comma-separated project IDs for lightweight latest-version check",
    ),
    status_filter: Optional[CatalogStatus] = Query(None, alias="status", description="Filter by status"),
    limit: int = Query(20, ge=1, le=100),
    current_user: Any = Depends(get_current_user),
):
    """
    Lista todas las versiones de catálogo para un proyecto o retorna digest ligero multiproyecto.
    
    Útil para el admin desktop para ver historial de versiones.
    """
    if project_ids:
        requested_project_ids = [item.strip() for item in project_ids.split(",") if item.strip()]
        if not requested_project_ids:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="project_ids must include at least one project",
            )
        for requested_project_id in requested_project_ids:
            _enforce_catalog_permission(current_user, "catalog.view", requested_project_id)
        return {pid: _catalog_digest_firestore(pid) for pid in requested_project_ids}

    if not project_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either project_id or project_ids must be provided",
        )
    _enforce_catalog_permission(current_user, "catalog.view", project_id)
    return _catalog_versions_firestore(project_id, status_filter, limit)


@router.get("/versions/{version_id}", response_model=CatalogPackage)
def get_catalog_version(
    version_id: UUID,
    current_user: Any = Depends(get_current_user),
):
    """
    Obtiene una versión específica de catálogo por ID.

    Puede devolver DRAFT, PUBLISHED, o DEPRECATED.
    En modo Firestore usa GET /catalog/bundle?version_id={version_id}.
    """
    version_key = str(version_id)
    snap = get_firestore_client().collection("catalog_versions").document(version_key).get()
    if not snap.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Catalog version {version_id} not found in Firestore",
        )
    project_id = str((snap.to_dict() or {}).get("project_id") or "").strip().upper()
    if not project_id:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"Catalog version {version_id} is missing project_id",
        )
    _enforce_catalog_permission(current_user, "catalog.view", project_id)
    return _catalog_package_from_firestore(project_id=project_id, version_id=version_key)


@router.post("/versions/{version_id}/publish", response_model=CatalogVersionResponse)
def publish_catalog_version(
    version_id: UUID,
    publish_data: Optional[CatalogVersionPublish] = None,
    current_user: Any = Depends(get_current_user),
):
    """
    Publica un catálogo DRAFT a PUBLISHED usando persistencia Firestore.

    Compatibilidad: mantiene la firma legacy por `version_id`.
    """
    version_key = str(version_id)
    snap = get_firestore_client().collection("catalog_versions").document(version_key).get()
    if not snap.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Catalog version {version_id} not found in Firestore",
        )
    project_id = str((snap.to_dict() or {}).get("project_id") or "").strip().upper()
    if not project_id:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"Catalog version {version_id} is missing project_id",
        )
    _enforce_catalog_permission(current_user, "catalog.publish", project_id)
    _ = publish_data
    _ = current_user
    _publish_bundle_firestore(project_id)
    return _catalog_version_response_from_firestore(project_id=project_id, version_id=version_key)


@router.get("/effective", response_model=EffectiveCatalogResponse)
def get_effective_catalog(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    current_user: Any = Depends(get_current_user),
):
    """
    Returns the effective catalog for a project (with overrides applied).

    Responses:
    - 200: catalog resolved successfully
    - 404: no published catalog version configured (app shows "Reintentar")
    - 503: DB error / migrations pending (contact admin)
    """
    _enforce_catalog_permission(current_user, "catalog.view", project_id)
    try:
        result = _resolve_effective_catalog_firestore(project_id=project_id, version_id=version_id)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "Unexpected error in GET /catalog/effective "
            "(user=%s, project_id=%s, version_id=%s): %s",
            current_user.email,
            project_id,
            version_id or "(auto)",
            exc,
            exc_info=True,
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Catalog service unavailable. Contact your administrator.",
        )
    logger.info(
        "Effective catalog resolved: project_id=%s version_id=%s user=%s "
        "activities=%d subcategories=%d",
        project_id,
        result["meta"]["version_id"],
        current_user.email,
        len(result.get("activities", [])),
        len(result.get("subcategories", [])),
    )
    return result


@router.get("/version/current", response_model=CurrentCatalogVersionResponse)
def get_current_catalog_version(
    project_id: Optional[str] = Query(None, description="Optional project id"),
    current_user: Any = Depends(get_current_user),
):
    """
    Devuelve el ID de la versión de catálogo marcada como is_current=true.

    Respuestas:
    - 200: versión encontrada
    - 404: no hay ninguna versión publicada (app muestra "Reintentar")
    - 503: fallo de base de datos (tabla inexistente / migraciones pendientes)
    """
    _enforce_catalog_permission(current_user, "catalog.view", project_id)
    try:
        version_id = _resolve_current_version_id_firestore(project_id=project_id)
    except HTTPException:
        # Re-lanza el 404 (sin catálogo) o 503 (DB error) tal cual.
        # Nunca debe convertirse en 500.
        raise
    except Exception as exc:
        logger.error(
            "Unexpected error in GET /catalog/version/current (user=%s): %s",
            current_user.email,
            exc,
            exc_info=True,
        )
        # Surface an actionable message instead of opaque 500s in runtime clients.
        # This endpoint is frequently used as preflight by sync/push flows.
        detail_hint = (
            "Catalog service unavailable. Verify Firestore catalog seed "
            f"(project_id={project_id or '(none)'})."
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=detail_hint,
        )
    logger.info(
        "Catalog version resolved: version_id=%s user=%s",
        version_id,
        current_user.email,
    )
    return {"version_id": version_id, "generated_at": datetime.now(timezone.utc)}


@router.get("/diff", response_model=DiffResponse)
def get_catalog_diff(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    from_version_id: str = Query(..., description="Source catalog version"),
    to_version_id: Optional[str] = Query(None, description="Target catalog version"),
    current_user: Any = Depends(get_current_user),
):
    _enforce_catalog_permission(current_user, "catalog.view", project_id)
    resolved_to_version = to_version_id or _resolve_current_version_id_firestore(project_id=project_id)
    return _diff_effective_catalog_firestore(
        project_id=project_id,
        from_version_id=from_version_id,
        to_version_id=resolved_to_version,
    )


# ── Bundle / project-ops / validate / publish / rollback ──────────────────────

@router.get("/bundle")
def get_catalog_bundle(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    version_id: Optional[str] = Query(
        None,
        description="Specific catalog version ID. Defaults to current active version.",
    ),
    include_editor: bool = Query(False, description="Include editor layer (admin only)"),
    current_user: Any = Depends(get_current_user),
):
    """
    Returns the full sao.catalog.bundle.v1 for a project.

    - Wizard (mobile/field): call without include_editor — returns only effective.
    - Desktop admin: call with include_editor=true — returns effective + editor layers.
    - Pass version_id to pin the bundle to a specific historical version.
    """
    required_permission = "catalog.edit" if include_editor else "catalog.view"
    _enforce_catalog_permission(current_user, required_permission, project_id)
    return _resolve_catalog_bundle_firestore(
        project_id=project_id,
        version_id=version_id,
        include_editor=include_editor,
    )


@router.get("/workflow")
def get_catalog_workflow(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    current_user: Any = Depends(get_current_user),
):
    """Returns only the workflow machine from effective.rules.workflow."""
    _enforce_catalog_permission(current_user, "catalog.view", project_id)
    bundle = _resolve_catalog_bundle_firestore(project_id=project_id, include_editor=False)
    effective = bundle.get("effective") if isinstance(bundle, dict) else {}
    rules = effective.get("rules") if isinstance(effective, dict) else {}
    workflow = rules.get("workflow") if isinstance(rules, dict) else {}
    return workflow if isinstance(workflow, dict) else {}


@router.patch("/project-ops")
def apply_project_ops(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    body: ProjectOpsRequest = ...,
    current_user: Any = Depends(get_current_user),
):
    """
    Apply a batch of catalog ops (upsert/patch/deactivate/activate/rel_*/reorder/delete).
    `delete` removes the row from the current editable bundle.
    and return the updated bundle with include_editor=true.
    """
    _enforce_catalog_permission(current_user, "catalog.edit", project_id)
    logger.info(
        "[project-ops] project_id=%s ops_count=%d ops=%s",
        project_id,
        len(body.ops),
        [{"op": o.op, "entity": o.entity, "id": o.id, "data_keys": list((o.data or {}).keys())} for o in body.ops],
    )
    resolved_project = project_id.strip().upper()
    resolved_version = _resolve_current_version_id_firestore(project_id=resolved_project)
    bundle = _resolve_catalog_bundle_firestore(
        project_id=resolved_project,
        version_id=resolved_version,
        include_editor=True,
    )
    bundle = _apply_project_ops_firestore(bundle, body.ops)
    bundle.setdefault("meta", {})
    bundle["meta"]["generated_at"] = datetime.now(timezone.utc)
    bundle["meta"]["project_id"] = resolved_project
    bundle["meta"]["version_id"] = resolved_version
    _write_current_bundle_firestore(resolved_project, bundle)
    return bundle


@router.post("/validate", response_model=CatalogValidationResponse)
def validate_catalog(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    current_user: Any = Depends(get_current_user),
):
    """Validate FK integrity of the current catalog and return any issues."""
    _enforce_catalog_permission(current_user, "catalog.edit", project_id)
    bundle = _resolve_catalog_bundle_firestore(project_id=project_id, include_editor=True)
    return _validate_bundle_firestore(bundle)


@router.post("/publish", response_model=CatalogPublishResponse)
def publish_catalog(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    current_user: Any = Depends(get_current_user),
):
    """Publish the current catalog state — creates a new version_id marked as is_current."""
    _enforce_catalog_permission(current_user, "catalog.publish", project_id)
    return _publish_bundle_firestore(project_id)


@router.post("/rollback", response_model=CatalogRollbackResponse)
def rollback_catalog(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    body: CatalogRollbackRequest = ...,
    current_user: Any = Depends(get_current_user),
):
    """Restore a previously published catalog version as the current one."""
    _enforce_catalog_permission(current_user, "catalog.publish", project_id)
    return _rollback_bundle_firestore(project_id, body.to_effective_version)


@router.get("/editor", response_model=CatalogEditorResponse)
def get_catalog_editor(
    project_id: str = Query(..., description="Project ID (e.g., TMQ)"),
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    current_user: Any = Depends(get_current_user),
):
    _enforce_catalog_permission(current_user, "catalog.edit", project_id)
    return _editor_response_from_firestore(project_id=project_id.strip().upper(), version_id=version_id)


@router.post("/editor/activities", status_code=status.HTTP_204_NO_CONTENT)
def create_activity_editor(
    payload: ActivityCreateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(
        project,
        version_id,
        CatalogOp(op="upsert", entity="activities", id=payload.id, data=payload.model_dump(exclude_none=True)),
    )
    return None


@router.patch("/editor/activities/{activity_id}", status_code=status.HTTP_204_NO_CONTENT)
def update_activity_editor(
    activity_id: str,
    payload: ActivityUpdateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(
        project,
        version_id,
        CatalogOp(op="patch", entity="activities", id=activity_id, data=payload.model_dump(exclude_none=True)),
    )
    return None


@router.delete("/editor/activities/{activity_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_activity_editor(
    activity_id: str,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(project, version_id, CatalogOp(op="delete", entity="activities", id=activity_id, data={}))
    return None


@router.post("/editor/subcategories", status_code=status.HTTP_204_NO_CONTENT)
def create_subcategory_editor(
    payload: SubcategoryCreateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(
        project,
        version_id,
        CatalogOp(op="upsert", entity="subcategories", id=payload.id, data=payload.model_dump(exclude_none=True)),
    )
    return None


@router.patch("/editor/subcategories/{subcategory_id}", status_code=status.HTTP_204_NO_CONTENT)
def update_subcategory_editor(
    subcategory_id: str,
    payload: SubcategoryUpdateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(
        project,
        version_id,
        CatalogOp(op="patch", entity="subcategories", id=subcategory_id, data=payload.model_dump(exclude_none=True)),
    )
    return None


@router.delete("/editor/subcategories/{subcategory_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_subcategory_editor(
    subcategory_id: str,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(project, version_id, CatalogOp(op="delete", entity="subcategories", id=subcategory_id, data={}))
    return None


@router.post("/editor/purposes", status_code=status.HTTP_204_NO_CONTENT)
def create_purpose_editor(
    payload: PurposeCreateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(
        project,
        version_id,
        CatalogOp(op="upsert", entity="purposes", id=payload.id, data=payload.model_dump(exclude_none=True)),
    )
    return None


@router.patch("/editor/purposes/{purpose_id}", status_code=status.HTTP_204_NO_CONTENT)
def update_purpose_editor(
    purpose_id: str,
    payload: PurposeUpdateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(
        project,
        version_id,
        CatalogOp(op="patch", entity="purposes", id=purpose_id, data=payload.model_dump(exclude_none=True)),
    )
    return None


@router.delete("/editor/purposes/{purpose_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_purpose_editor(
    purpose_id: str,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(project, version_id, CatalogOp(op="delete", entity="purposes", id=purpose_id, data={}))
    return None


@router.post("/editor/topics", status_code=status.HTTP_204_NO_CONTENT)
def create_topic_editor(
    payload: TopicCreateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(
        project,
        version_id,
        CatalogOp(op="upsert", entity="topics", id=payload.id, data=payload.model_dump(exclude_none=True)),
    )
    return None


@router.patch("/editor/topics/{topic_id}", status_code=status.HTTP_204_NO_CONTENT)
def update_topic_editor(
    topic_id: str,
    payload: TopicUpdateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(
        project,
        version_id,
        CatalogOp(op="patch", entity="topics", id=topic_id, data=payload.model_dump(exclude_none=True)),
    )
    return None


@router.delete("/editor/topics/{topic_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_topic_editor(
    topic_id: str,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(project, version_id, CatalogOp(op="delete", entity="topics", id=topic_id, data={}))
    return None


@router.post("/editor/results", status_code=status.HTTP_204_NO_CONTENT)
def create_result_editor(
    payload: ResultCreateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(
        project,
        version_id,
        CatalogOp(op="upsert", entity="results", id=payload.id, data=payload.model_dump(exclude_none=True)),
    )
    return None


@router.patch("/editor/results/{result_id}", status_code=status.HTTP_204_NO_CONTENT)
def update_result_editor(
    result_id: str,
    payload: ResultUpdateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(
        project,
        version_id,
        CatalogOp(op="patch", entity="results", id=result_id, data=payload.model_dump(exclude_none=True)),
    )
    return None


@router.delete("/editor/results/{result_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_result_editor(
    result_id: str,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(project, version_id, CatalogOp(op="delete", entity="results", id=result_id, data={}))
    return None


@router.post("/editor/attendees", status_code=status.HTTP_204_NO_CONTENT)
def create_attendee_editor(
    payload: AttendeeCreateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(
        project,
        version_id,
        CatalogOp(op="upsert", entity="assistants", id=payload.id, data=payload.model_dump(exclude_none=True)),
    )
    return None


@router.patch("/editor/attendees/{attendee_id}", status_code=status.HTTP_204_NO_CONTENT)
def update_attendee_editor(
    attendee_id: str,
    payload: AttendeeUpdateRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(
        project,
        version_id,
        CatalogOp(op="patch", entity="assistants", id=attendee_id, data=payload.model_dump(exclude_none=True)),
    )
    return None


@router.delete("/editor/attendees/{attendee_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_attendee_editor(
    attendee_id: str,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(project, version_id, CatalogOp(op="delete", entity="assistants", id=attendee_id, data={}))
    return None


@router.post("/editor/rel-activity-topics", status_code=status.HTTP_204_NO_CONTENT)
def upsert_rel_activity_topic_editor(
    payload: RelActivityTopicUpsertRequest,
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(
        project,
        version_id,
        CatalogOp(
            op="rel_upsert",
            entity="activity_to_topics_suggested",
            id=f"{payload.activity_id}|{payload.topic_id}",
            data={"activity_id": payload.activity_id, "topic_id": payload.topic_id},
        ),
    )
    return None


@router.delete("/editor/rel-activity-topics", status_code=status.HTTP_204_NO_CONTENT)
def delete_rel_activity_topic_editor(
    activity_id: str = Query(..., description="Activity ID"),
    topic_id: str = Query(..., description="Topic ID"),
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    project_id: Optional[str] = Query(None, description="Project ID"),
    current_user: Any = Depends(get_current_user),
):
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    _enforce_catalog_permission(current_user, "catalog.edit", project)
    _firestore_apply_editor_op(
        project,
        version_id,
        CatalogOp(
            op="rel_deactivate",
            entity="activity_to_topics_suggested",
            id=f"{activity_id}|{topic_id}",
            data={"activity_id": activity_id, "topic_id": topic_id},
        ),
    )
    return None


@router.post("/editor/reorder", status_code=status.HTTP_204_NO_CONTENT)
def reorder_catalog_editor(
    payload: ReorderEntityRequest,
    project_id: str = Query(..., description="Project ID"),
    version_id: Optional[str] = Query(None, description="Catalog version ID"),
    current_user: Any = Depends(get_current_user),
):
    entity_map = {
        "activity": "activities",
        "subcategory": "subcategories",
        "purpose": "purposes",
        "topic": "topics",
    }
    mapped = entity_map.get(payload.entity)
    if not mapped:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unsupported reorder entity")
    _enforce_catalog_permission(current_user, "catalog.edit", project_id)
    project = _resolve_editor_project_firestore(project_id=project_id, version_id=version_id)
    for index, entity_id in enumerate(payload.ids):
        _firestore_apply_editor_op(
            project,
            version_id,
            CatalogOp(op="reorder", entity=mapped, id=entity_id, data={"order": index, "sort_order": index}),
        )
    return None
