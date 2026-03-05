from __future__ import annotations

from datetime import date
from uuid import UUID

from sqlalchemy import inspect, text
from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.models.catalog import CatalogStatus, CatalogVersion
from app.models.front import Front
from app.models.location import Location
from app.models.project import Project, ProjectStatus
from app.models.project_location_scope import ProjectLocationScope
from app.services.project_catalog_bootstrap_service import bootstrap_project_catalog_from_base


TMQ_FRONTS = [
    {"code": f"F{i}", "name": f"Frente {i}", "pk_start": None, "pk_end": None}
    for i in range(1, 13)
]

TAP_FRONTS = [
    {"code": f"F{i}", "name": f"Frente {i}", "pk_start": None, "pk_end": None}
    for i in range(1, 7)
]

TMQ_SCOPE = [
    ("Ciudad de México", "Cuauhtémoc"),
    ("Ciudad de México", "Azcapotzalco"),
    ("Ciudad de México", "Gustavo A. Madero"),
    ("Estado de México", "Tlalnepantla de Baz"),
    ("Estado de México", "Cuautitlán Izcalli"),
    ("Estado de México", "Tepotzotlán"),
    ("Estado de México", "Huehuetoca"),
    ("Querétaro", "San Juan del Río"),
    ("Querétaro", "Pedro Escobedo"),
    ("Querétaro", "El Marqués"),
    ("Querétaro", "Querétaro"),
]

TAP_SCOPE = [
    ("Estado de México", "Zumpango"),
    ("Estado de México", "Tecámac"),
    ("Estado de México", "Nextlalpan"),
    ("Hidalgo", "Tizayuca"),
    ("Hidalgo", "Tolcayuca"),
    ("Hidalgo", "Zapotlán de Juárez"),
    ("Hidalgo", "Pachuca de Soto"),
]


def _ensure_project(db: Session, code: str, name: str, start_date: date) -> Project:
    project = db.query(Project).filter(Project.id == code).first()
    if project is None:
        project = Project(
            id=code,
            name=name,
            status=ProjectStatus.ACTIVE,
            start_date=start_date,
            end_date=None,
        )
        db.add(project)
        db.flush()
        print(f"[OK] Created project {code}")
    else:
        project.name = name
        project.status = ProjectStatus.ACTIVE
        if project.start_date is None:
            project.start_date = start_date
        print(f"[OK] Project {code} already exists (updated metadata)")
    return project


def _ensure_fronts(db: Session, project_id: str, fronts: list[dict]) -> None:
    existing_by_code = {
        row.code: row for row in db.query(Front).filter(Front.project_id == project_id).all()
    }
    for front_data in fronts:
        code = front_data["code"].strip().upper()
        name = front_data["name"].strip()
        row = existing_by_code.get(code)
        if row is None:
            db.add(
                Front(
                    project_id=project_id,
                    code=code,
                    name=name,
                    pk_start=front_data.get("pk_start"),
                    pk_end=front_data.get("pk_end"),
                )
            )
            print(f"[OK] Added front {project_id}:{code}")
        else:
            row.name = name
            row.pk_start = front_data.get("pk_start")
            row.pk_end = front_data.get("pk_end")


def _ensure_scope(db: Session, project_id: str, pairs: list[tuple[str, str]]) -> None:
    for estado, municipio in pairs:
        location = (
            db.query(Location)
            .filter(Location.estado == estado, Location.municipio == municipio)
            .first()
        )
        if location is None:
            location = Location(estado=estado, municipio=municipio)
            db.add(location)
            db.flush()
            print(f"[OK] Added location {estado} / {municipio}")

        exists = (
            db.query(ProjectLocationScope)
            .filter(
                ProjectLocationScope.project_id == project_id,
                ProjectLocationScope.location_id == location.id,
            )
            .first()
        )
        if exists is None:
            db.add(
                ProjectLocationScope(
                    project_id=project_id,
                    location_id=location.id,
                    is_active=True,
                )
            )
            print(f"[OK] Added scope {project_id}: {estado} / {municipio}")


def _ensure_scope_table_exists(db: Session) -> None:
    inspector = inspect(db.bind)
    if inspector.has_table("project_location_scopes"):
        return

    db.execute(
        text(
            """
            CREATE TABLE IF NOT EXISTS project_location_scopes (
                id UUID PRIMARY KEY,
                project_id VARCHAR(10) NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
                location_id UUID NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
                is_active BOOLEAN NOT NULL DEFAULT TRUE,
                created_at TIMESTAMPTZ NOT NULL,
                updated_at TIMESTAMPTZ NOT NULL,
                CONSTRAINT uq_project_location_scope UNIQUE (project_id, location_id)
            )
            """
        )
    )
    db.execute(
        text(
            "CREATE INDEX IF NOT EXISTS idx_project_location_scope_project "
            "ON project_location_scopes(project_id)"
        )
    )
    db.execute(
        text(
            "CREATE INDEX IF NOT EXISTS idx_project_location_scope_location "
            "ON project_location_scopes(location_id)"
        )
    )
    db.flush()
    print("[OK] Created missing table project_location_scopes")


def _published_catalog(db: Session, project_id: str) -> CatalogVersion | None:
    return (
        db.query(CatalogVersion)
        .filter(
            CatalogVersion.project_id == project_id,
            CatalogVersion.status == CatalogStatus.PUBLISHED,
        )
        .order_by(CatalogVersion.published_at.desc(), CatalogVersion.created_at.desc())
        .first()
    )


def _any_published_catalog(db: Session) -> CatalogVersion | None:
    return (
        db.query(CatalogVersion)
        .filter(CatalogVersion.status == CatalogStatus.PUBLISHED)
        .order_by(CatalogVersion.published_at.desc(), CatalogVersion.created_at.desc())
        .first()
    )


def _ensure_catalog_for_project(
    db: Session,
    *,
    target_project_id: str,
    source_project_id: str,
    source_version_number: str | None = None,
) -> None:
    existing = _published_catalog(db, target_project_id)
    if existing is not None:
        print(
            f"[OK] Catalog already exists for {target_project_id}: "
            f"{existing.version_number} ({existing.status.value})"
        )
        return

    bootstrap_project_catalog_from_base(
        db,
        target_project_id=target_project_id,
        source_project_id=source_project_id,
        source_version_number=source_version_number,
        target_version_number="1.0.0",
        published_by_id=None,
    )
    print(
        f"[OK] Bootstrapped catalog for {target_project_id} "
        f"from {source_project_id} v{source_version_number or '(latest)'}"
    )


def _ensure_tmq_and_tap(db: Session) -> None:
    _ensure_scope_table_exists(db)

    _ensure_project(db, "TMQ", "Tren México-Querétaro", date(2024, 1, 1))
    _ensure_project(db, "TAP", "Tren AIFA-Pachuca", date(2024, 1, 1))

    _ensure_fronts(db, "TMQ", TMQ_FRONTS)
    _ensure_fronts(db, "TAP", TAP_FRONTS)

    _ensure_scope(db, "TMQ", TMQ_SCOPE)
    _ensure_scope(db, "TAP", TAP_SCOPE)

    tmq_catalog = _published_catalog(db, "TMQ")
    if tmq_catalog is None:
        fallback = _any_published_catalog(db)
        if fallback is None:
            raise RuntimeError(
                "No published catalog exists in DB. "
                "Run migrations/seeds before creating project catalogs."
            )
        _ensure_catalog_for_project(
            db,
            target_project_id="TMQ",
            source_project_id=fallback.project_id,
            source_version_number=fallback.version_number,
        )
        tmq_catalog = _published_catalog(db, "TMQ")

    _ensure_catalog_for_project(
        db,
        target_project_id="TAP",
        source_project_id="TMQ",
        source_version_number=tmq_catalog.version_number if tmq_catalog else None,
    )


def main() -> None:
    db = SessionLocal()
    try:
        _ensure_tmq_and_tap(db)
        db.commit()

        tmq_fronts = db.query(Front).filter(Front.project_id == "TMQ").count()
        tap_fronts = db.query(Front).filter(Front.project_id == "TAP").count()
        tmq_scope = db.query(ProjectLocationScope).filter(ProjectLocationScope.project_id == "TMQ").count()
        tap_scope = db.query(ProjectLocationScope).filter(ProjectLocationScope.project_id == "TAP").count()
        tmq_catalog = _published_catalog(db, "TMQ")
        tap_catalog = _published_catalog(db, "TAP")

        print("\n=== SUMMARY ===")
        print(f"TMQ fronts: {tmq_fronts}")
        print(f"TAP fronts: {tap_fronts}")
        print(f"TMQ location scope rows: {tmq_scope}")
        print(f"TAP location scope rows: {tap_scope}")
        print(
            "TMQ catalog: "
            f"{tmq_catalog.version_number if tmq_catalog else 'NONE'}"
        )
        print(
            "TAP catalog: "
            f"{tap_catalog.version_number if tap_catalog else 'NONE'}"
        )
        print("[OK] TMQ/TAP setup completed")
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()
