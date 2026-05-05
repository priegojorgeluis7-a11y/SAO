"""Current-user scoped endpoints."""

from fastapi import APIRouter, Depends

from app.api.deps import get_current_user, resolve_user_project_access
from app.core.firestore import get_firestore_client
from typing import Any
from app.schemas.user import MyProjectItem
from app.services.audit_service import canonicalize_role_name

router = APIRouter(prefix="/me", tags=["me"])
_HIDDEN_TEMPLATE_PROJECT_IDS = {"PROJECT_0", "P0"}


def _is_hidden_template_project(project_id: str | None) -> bool:
    return (project_id or "").strip().upper() in _HIDDEN_TEMPLATE_PROJECT_IDS


def _normalize_project_id(project_id: str | None) -> str:
    return (project_id or "").strip().upper()


def _project_aliases(payload: dict[str, Any], doc_id: str) -> set[str]:
    aliases = {
        _normalize_project_id(doc_id),
        _normalize_project_id(payload.get("id")),
        _normalize_project_id(payload.get("code")),
        _normalize_project_id(payload.get("project_id")),
    }
    return {alias for alias in aliases if alias}


@router.get("/projects", response_model=list[MyProjectItem])
async def list_my_projects(
    current_user: Any = Depends(get_current_user),
):
    """Return projects the user can access, including assigned role names."""
    role_names = [
        canonicalize_role_name(role) or str(role).strip().upper()
        for role in (getattr(current_user, "roles", []) or [])
        if str(role).strip()
    ]
    has_global_scope, resolved_project_ids = resolve_user_project_access(current_user)
    allowed_project_ids = {
        project_id
        for project_id in resolved_project_ids
        if not _is_hidden_template_project(project_id)
    }

    client = get_firestore_client()
    firestore_projects: list[tuple[str, str]] = []
    matched_allowed_project_ids: set[str] = set()
    for doc in client.collection("projects").stream():
        payload = doc.to_dict() or {}
        aliases = _project_aliases(payload, doc.id)
        if not aliases:
            continue
        if all(_is_hidden_template_project(alias) for alias in aliases):
            continue
        if not has_global_scope and not aliases.intersection(allowed_project_ids):
            continue
        if not has_global_scope:
            matched_allowed_project_ids.update(aliases.intersection(allowed_project_ids))
        project_id = _normalize_project_id(
            payload.get("project_id") or payload.get("code") or payload.get("id") or doc.id
        )
        project_name = str(payload.get("name") or project_id).strip() or project_id
        firestore_projects.append((project_id, project_name))

    if firestore_projects or (not has_global_scope and allowed_project_ids):
        if not has_global_scope:
            # Preserve explicit user scope entries even when no projects document matches.
            # This avoids dropping allowed projects because of id/code alias mismatches.
            for unmatched_project_id in sorted(allowed_project_ids - matched_allowed_project_ids):
                if _is_hidden_template_project(unmatched_project_id):
                    continue
                firestore_projects.append((unmatched_project_id, unmatched_project_id))

        unique_rows: dict[str, str] = {}
        for project_id, project_name in firestore_projects:
            if project_id not in unique_rows:
                unique_rows[project_id] = project_name
        normalized_rows = sorted(unique_rows.items(), key=lambda item: item[0])
        return [
            MyProjectItem(
                project_id=project_id,
                project_name=project_name,
                role_names=sorted(set(role_names)) or ["OPERATIVO"],
            )
            for project_id, project_name in normalized_rows
        ]

    if has_global_scope:
        catalog_project_ids: list[str] = []
        for doc in client.collection("catalog_current").stream():
            project_id = _normalize_project_id(doc.id)
            if not project_id or _is_hidden_template_project(project_id):
                continue
            catalog_project_ids.append(project_id)

        if catalog_project_ids:
            unique_ids = sorted(set(catalog_project_ids))
            return [
                MyProjectItem(
                    project_id=project_id,
                    project_name=project_id,
                    role_names=sorted(set(role_names)) or ["OPERATIVO"],
                )
                for project_id in unique_ids
            ]

    return [
        MyProjectItem(
            project_id=project_id,
            project_name=project_id,
            role_names=sorted(set(role_names)) or ["OPERATIVO"],
        )
        for project_id in sorted(allowed_project_ids)
    ]
