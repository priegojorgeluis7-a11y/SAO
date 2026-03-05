from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import require_any_role
from app.core.database import get_db
from app.models.front import Front
from app.models.location import Location
from app.models.project_location_scope import ProjectLocationScope
from app.models.project import Project
from app.models.user import User
from app.schemas.project import ProjectCreate, ProjectOut, ProjectUpdate
from app.services.audit_service import write_audit_log
from app.services.project_catalog_bootstrap_service import bootstrap_project_catalog_from_base

router = APIRouter(prefix="/projects", tags=["projects"])


@router.get("", response_model=list[ProjectOut])
def list_projects(
    _current_user: User = Depends(require_any_role(["ADMIN", "SUPERVISOR"])),
    db: Session = Depends(get_db),
):
    return db.query(Project).order_by(Project.id.asc()).all()


@router.post("", response_model=ProjectOut, status_code=status.HTTP_201_CREATED)
def create_project(
    payload: ProjectCreate,
    current_user: User = Depends(require_any_role(["ADMIN"])),
    db: Session = Depends(get_db),
):
    code = payload.id.strip().upper()
    if len(code) > 10:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Project id max length is 10")

    existing = db.query(Project).filter(Project.id == code).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Project already exists")

    project = Project(
        id=code,
        name=payload.name.strip(),
        status=payload.status,
        start_date=payload.start_date,
        end_date=payload.end_date,
    )
    db.add(project)
    db.flush()

    front_payload = payload.fronts
    default_fronts = [
        {"code": f"F{i}", "name": f"Frente {i}", "pk_start": None, "pk_end": None}
        for i in range(1, 13)
    ]
    front_entries = [
        {
            "code": item.code,
            "name": item.name,
            "pk_start": item.pk_start,
            "pk_end": item.pk_end,
        }
        for item in front_payload
    ]
    if not front_entries and code == "TMQ":
        front_entries = default_fronts

    for index, front_input in enumerate(front_entries, start=1):
        cleaned_name = (front_input.get("name") or "").strip()
        if not cleaned_name:
            continue
        raw_code = (front_input.get("code") or "").strip().upper()
        cleaned_code = raw_code if raw_code else f"F{index}"

        existing_front = (
            db.query(Front)
            .filter(Front.project_id == code, Front.code == cleaned_code)
            .first()
        )
        if existing_front is not None:
            continue

        db.add(
            Front(
                project_id=code,
                code=cleaned_code,
                name=cleaned_name,
                pk_start=front_input.get("pk_start"),
                pk_end=front_input.get("pk_end"),
            )
        )

    location_scope = payload.location_scope
    default_scope = [
        {"estado": "Ciudad de México", "municipio": "Cuauhtémoc"},
        {"estado": "Estado de México", "municipio": "Tultitlán"},
        {"estado": "Querétaro", "municipio": "Querétaro"},
    ]
    location_entries = [{"estado": item.estado, "municipio": item.municipio} for item in location_scope]
    if not location_entries and code == "TMQ":
        location_entries = default_scope

    for entry in location_entries:
        estado = (entry.get("estado") or "").strip()
        municipio = (entry.get("municipio") or "").strip()
        if not estado or not municipio:
            continue

        location = (
            db.query(Location)
            .filter(Location.estado == estado, Location.municipio == municipio)
            .first()
        )
        if location is None:
            location = Location(estado=estado, municipio=municipio)
            db.add(location)
            db.flush()

        exists_scope = (
            db.query(ProjectLocationScope)
            .filter(
                ProjectLocationScope.project_id == code,
                ProjectLocationScope.location_id == location.id,
            )
            .first()
        )
        if exists_scope is None:
            db.add(
                ProjectLocationScope(
                    project_id=code,
                    location_id=location.id,
                    is_active=True,
                )
            )

    if payload.bootstrap_from_tmq:
        try:
            bootstrap_project_catalog_from_base(
                db,
                target_project_id=code,
                source_project_id="TMQ",
                source_version_number=payload.base_catalog_version,
                target_version_number="1.0.0",
                published_by_id=current_user.id,
            )
        except ValueError as error:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    write_audit_log(
        db,
        action="PROJECT_CREATED",
        entity="project",
        entity_id=code,
        actor=current_user,
        details={
            "name": project.name,
            "status": project.status.value,
            "bootstrap_from_tmq": payload.bootstrap_from_tmq,
            "base_catalog_version": payload.base_catalog_version,
            "fronts_count": len(front_entries),
            "location_scope_count": len(location_entries),
        },
    )
    db.commit()
    db.refresh(project)
    return project


@router.put("/{project_id}", response_model=ProjectOut)
def update_project(
    project_id: str,
    payload: ProjectUpdate,
    current_user: User = Depends(require_any_role(["ADMIN"])),
    db: Session = Depends(get_db),
):
    project = db.query(Project).filter(Project.id == project_id.upper()).first()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")

    if payload.name is not None:
        project.name = payload.name.strip()
    if payload.status is not None:
        project.status = payload.status
    if payload.start_date is not None:
        project.start_date = payload.start_date
    if payload.end_date is not None:
        project.end_date = payload.end_date

    write_audit_log(
        db,
        action="PROJECT_UPDATED",
        entity="project",
        entity_id=project.id,
        actor=current_user,
        details={
            "name": project.name,
            "status": project.status.value,
            "start_date": str(project.start_date),
            "end_date": str(project.end_date) if project.end_date else None,
        },
    )
    db.commit()
    db.refresh(project)
    return project


@router.delete("/{project_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_project(
    project_id: str,
    current_user: User = Depends(require_any_role(["ADMIN"])),
    db: Session = Depends(get_db),
):
    project = db.query(Project).filter(Project.id == project_id.upper()).first()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")

    write_audit_log(
        db,
        action="PROJECT_DELETED",
        entity="project",
        entity_id=project.id,
        actor=current_user,
        details={"name": project.name},
    )
    db.delete(project)
    db.commit()
    return None
