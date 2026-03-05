from __future__ import annotations

import argparse
from dataclasses import dataclass

from app.core.database import SessionLocal
from app.models.catalog_effective import (
    CatActivity,
    CatAttendee,
    CatProject,
    CatPurpose,
    CatResult,
    CatSubcategory,
    CatTopic,
    ProjCatalogOverride,
)
from app.services.effective_catalog_service import EffectiveCatalogService


@dataclass
class EntitySnapshot:
    project_id: str
    version_id: str | None
    effective_name: str | None
    effective_active: bool | None
    override_name: str | None
    override_active: bool | None


def _resolve_project_version(db, project_id: str) -> str | None:
    row = (
        db.query(CatProject)
        .filter(CatProject.project_id == project_id.upper(), CatProject.is_active.is_(True))
        .first()
    )
    return row.version_id if row else None


def _read_override(db, project_id: str, entity_type: str, entity_id: str):
    return (
        db.query(ProjCatalogOverride)
        .filter(
            ProjCatalogOverride.project_id == project_id.upper(),
            ProjCatalogOverride.entity_type == entity_type,
            ProjCatalogOverride.entity_id == entity_id,
            ProjCatalogOverride.is_active.is_(True),
        )
        .first()
    )


def _effective_lookup(project_id: str, entity_type: str, entity_id: str, service: EffectiveCatalogService):
    payload = service.get_effective_catalog(project_id=project_id)
    if entity_type == "activity":
        source = payload.get("activities", [])
    elif entity_type == "subcategory":
        source = payload.get("subcategories", [])
    elif entity_type == "purpose":
        source = payload.get("purposes", [])
    elif entity_type == "topic":
        source = payload.get("topics", [])
    elif entity_type == "result":
        source = payload.get("results", [])
    elif entity_type == "attendee":
        source = payload.get("attendees", [])
    else:
        raise ValueError(f"Unsupported entity_type: {entity_type}")

    row = next((item for item in source if item.get("id") == entity_id), None)
    if not row:
        return None, None

    return row.get("name_effective"), row.get("is_enabled_effective")


def _base_table_for(entity_type: str):
    mapping = {
        "activity": CatActivity,
        "subcategory": CatSubcategory,
        "purpose": CatPurpose,
        "topic": CatTopic,
        "result": CatResult,
        "attendee": CatAttendee,
    }
    return mapping[entity_type]


def _base_name_active(db, entity_type: str, entity_id: str, version_id: str | None):
    if not version_id:
        return None, None

    model = _base_table_for(entity_type)
    id_field = {
        "activity": "activity_id",
        "subcategory": "subcategory_id",
        "purpose": "purpose_id",
        "topic": "topic_id",
        "result": "result_id",
        "attendee": "attendee_id",
    }[entity_type]

    row = (
        db.query(model)
        .filter(getattr(model, id_field) == entity_id, model.version_id == version_id)
        .first()
    )
    if not row:
        return None, None
    return getattr(row, "name", None), getattr(row, "is_active", None)


def _snapshot(db, project_id: str, entity_type: str, entity_id: str, service: EffectiveCatalogService) -> EntitySnapshot:
    normalized_project = project_id.upper()
    version_id = _resolve_project_version(db, normalized_project)
    eff_name, eff_active = _effective_lookup(normalized_project, entity_type, entity_id, service)
    ov = _read_override(db, normalized_project, entity_type, entity_id)
    return EntitySnapshot(
        project_id=normalized_project,
        version_id=version_id,
        effective_name=eff_name,
        effective_active=eff_active,
        override_name=ov.display_name_override if ov else None,
        override_active=ov.is_enabled if ov else None,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Verify catalog isolation across projects")
    parser.add_argument("--project-a", default="TMQ")
    parser.add_argument("--project-b", default="TAP")
    parser.add_argument(
        "--entity-type",
        required=True,
        choices=["activity", "subcategory", "purpose", "topic", "result", "attendee"],
    )
    parser.add_argument("--entity-id", required=True)
    args = parser.parse_args()

    db = SessionLocal()
    try:
        service = EffectiveCatalogService(db)
        a = _snapshot(db, args.project_a, args.entity_type, args.entity_id, service)
        b = _snapshot(db, args.project_b, args.entity_type, args.entity_id, service)

        base_name, base_active = _base_name_active(db, args.entity_type, args.entity_id, a.version_id)

        print("=== Catalog Isolation Check ===")
        print(f"entity: {args.entity_type}:{args.entity_id}")
        print(f"base({a.version_id}) => name={base_name!r}, active={base_active}")
        print("-")
        print(
            f"{a.project_id} => version={a.version_id}, effective_name={a.effective_name!r}, "
            f"effective_active={a.effective_active}, override_name={a.override_name!r}, override_active={a.override_active}"
        )
        print(
            f"{b.project_id} => version={b.version_id}, effective_name={b.effective_name!r}, "
            f"effective_active={b.effective_active}, override_name={b.override_name!r}, override_active={b.override_active}"
        )

        if (a.override_name or a.override_active is not None) and not (b.override_name or b.override_active is not None):
            print("OK: override presente solo en project-a.")
        elif (b.override_name or b.override_active is not None) and not (a.override_name or a.override_active is not None):
            print("OK: override presente solo en project-b.")
        elif (a.override_name or a.override_active is not None) and (b.override_name or b.override_active is not None):
            print("INFO: ambos proyectos tienen override para esta entidad.")
        else:
            print("WARN: no hay overrides; si ambos se movieron juntos, el cambio está en base compartida.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
