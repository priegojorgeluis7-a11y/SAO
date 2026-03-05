from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import require_any_role
from app.core.database import get_db
from app.models.front import Front
from app.models.location import Location
from app.models.project import Project
from app.models.project_location_scope import ProjectLocationScope
from app.models.user import User
from app.schemas.territory import FrontCreate, FrontOut, LocationOut, LocationScopeCreate, StateSummaryOut

router = APIRouter(tags=["territory"])


@router.get("/fronts", response_model=list[FrontOut])
def list_fronts(
    project_id: str = Query(..., min_length=1, max_length=10),
    _current_user: User = Depends(require_any_role(["ADMIN", "SUPERVISOR", "COORD", "OPERATIVO", "LECTOR"])),
    db: Session = Depends(get_db),
):
    code = project_id.strip().upper()
    rows = (
        db.query(Front)
        .filter(Front.project_id == code)
        .order_by(Front.code.asc(), Front.name.asc())
        .all()
    )
    return [
        FrontOut(
            id=str(item.id),
            project_id=item.project_id,
            code=item.code,
            name=item.name,
            pk_start=item.pk_start,
            pk_end=item.pk_end,
        )
        for item in rows
    ]


@router.post("/fronts", response_model=FrontOut, status_code=status.HTTP_201_CREATED)
def create_front(
    payload: FrontCreate,
    project_id: str = Query(..., min_length=1, max_length=10),
    _current_user: User = Depends(require_any_role(["ADMIN"])),
    db: Session = Depends(get_db),
):
    code = project_id.strip().upper()
    project = db.query(Project).filter(Project.id == code).first()
    if project is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")

    front_code = (payload.code.strip().upper() if payload.code else "").strip()
    if not front_code:
        total = db.query(Front).filter(Front.project_id == code).count()
        front_code = f"F{total + 1}"

    existing = (
        db.query(Front)
        .filter(Front.project_id == code, Front.code == front_code)
        .first()
    )
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Front code already exists in project")

    front = Front(
        id=uuid4(),
        project_id=code,
        code=front_code,
        name=payload.name.strip(),
        pk_start=payload.pk_start,
        pk_end=payload.pk_end,
    )
    db.add(front)
    db.commit()
    db.refresh(front)

    return FrontOut(
        id=str(front.id),
        project_id=front.project_id,
        code=front.code,
        name=front.name,
        pk_start=front.pk_start,
        pk_end=front.pk_end,
    )


@router.get("/locations/states", response_model=list[StateSummaryOut])
def list_project_states(
    project_id: str = Query(..., min_length=1, max_length=10),
    _current_user: User = Depends(require_any_role(["ADMIN", "SUPERVISOR", "COORD", "OPERATIVO", "LECTOR"])),
    db: Session = Depends(get_db),
):
    code = project_id.strip().upper()
    rows = (
        db.query(Location.estado)
        .join(ProjectLocationScope, ProjectLocationScope.location_id == Location.id)
        .filter(ProjectLocationScope.project_id == code, ProjectLocationScope.is_active.is_(True))
        .distinct()
        .all()
    )
    states = [r[0] for r in rows]
    output: list[StateSummaryOut] = []
    for estado in sorted(states):
        count = (
            db.query(Location)
            .join(ProjectLocationScope, ProjectLocationScope.location_id == Location.id)
            .filter(
                ProjectLocationScope.project_id == code,
                ProjectLocationScope.is_active.is_(True),
                Location.estado == estado,
            )
            .count()
        )
        output.append(StateSummaryOut(estado=estado, municipios_count=count))
    return output


@router.get("/locations", response_model=list[LocationOut])
def list_project_locations(
    project_id: str | None = Query(default=None, min_length=1, max_length=10),
    estado: str | None = Query(default=None),
    front_id: str | None = Query(default=None),
    _current_user: User = Depends(require_any_role(["ADMIN", "SUPERVISOR", "COORD", "OPERATIVO", "LECTOR"])),
    db: Session = Depends(get_db),
):
    resolved_project = project_id.strip().upper() if project_id else None
    if resolved_project is None and front_id:
        try:
            parsed_front_id = UUID(front_id)
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid front_id") from exc
        front = db.query(Front).filter(Front.id == parsed_front_id).first()
        if front is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Front not found")
        resolved_project = front.project_id

    query = db.query(Location)

    if resolved_project:
        query = (
            query.join(ProjectLocationScope, ProjectLocationScope.location_id == Location.id)
            .filter(
                ProjectLocationScope.project_id == resolved_project,
                ProjectLocationScope.is_active.is_(True),
            )
        )

    if estado and estado.strip():
        query = query.filter(Location.estado == estado.strip())

    rows = query.order_by(Location.estado.asc(), Location.municipio.asc()).all()
    return [LocationOut(id=str(item.id), estado=item.estado, municipio=item.municipio) for item in rows]


@router.post("/projects/{project_id}/locations", response_model=list[LocationOut])
def upsert_project_locations(
    project_id: str,
    payload: list[LocationScopeCreate],
    _current_user: User = Depends(require_any_role(["ADMIN"])),
    db: Session = Depends(get_db),
):
    code = project_id.strip().upper()
    project = db.query(Project).filter(Project.id == code).first()
    if project is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")

    for entry in payload:
        estado = entry.estado.strip()
        municipio = entry.municipio.strip()
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

        scoped = (
            db.query(ProjectLocationScope)
            .filter(
                ProjectLocationScope.project_id == code,
                ProjectLocationScope.location_id == location.id,
            )
            .first()
        )
        if scoped is None:
            db.add(
                ProjectLocationScope(
                    project_id=code,
                    location_id=location.id,
                    is_active=True,
                )
            )

    db.commit()

    rows = (
        db.query(Location)
        .join(ProjectLocationScope, ProjectLocationScope.location_id == Location.id)
        .filter(ProjectLocationScope.project_id == code, ProjectLocationScope.is_active.is_(True))
        .order_by(Location.estado.asc(), Location.municipio.asc())
        .all()
    )
    return [LocationOut(id=str(item.id), estado=item.estado, municipio=item.municipio) for item in rows]
