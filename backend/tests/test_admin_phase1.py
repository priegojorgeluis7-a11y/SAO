from datetime import date, datetime
from uuid import uuid4

from app.core.security import get_password_hash
from app.models.catalog import CATActivityType, CatalogStatus, CatalogVersion
from app.models.front import Front
from app.models.project import Project, ProjectStatus
from app.models.role import Role
from app.models.user import User, UserStatus
from app.models.user_role_scope import UserRoleScope


def _create_user_with_role(db, *, email: str, role_name: str, password: str = "testpass123"):
    role = db.query(Role).filter(Role.name == role_name).first()
    if role is None:
        role = Role(name=role_name, description=f"{role_name} role")
        db.add(role)
        db.flush()

    user = User(
        id=uuid4(),
        email=email,
        password_hash=get_password_hash(password),
        full_name=f"{role_name.title()} User",
        status=UserStatus.ACTIVE,
    )
    db.add(user)
    db.flush()

    scope = UserRoleScope(
        user_id=user.id,
        role_id=role.id,
        project_id=None,
        front_id=None,
        location_id=None,
        assigned_by_id=None,
    )
    db.add(scope)
    db.commit()
    return user


def _login(client, email: str, password: str = "testpass123"):
    response = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert response.status_code == 200
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_non_admin_cannot_create_project(client, db):
    operative = _create_user_with_role(db, email="operative@example.com", role_name="OPERATIVO")
    headers = _login(client, operative.email)

    response = client.post(
        "/api/v1/projects",
        headers=headers,
        json={
            "id": "PRJ001",
            "name": "Proyecto Prueba",
            "status": "active",
            "start_date": "2026-01-01",
            "end_date": None,
        },
    )

    assert response.status_code == 403


def test_admin_can_create_project_and_read_audit(client, db):
    admin = _create_user_with_role(db, email="admin@example.com", role_name="ADMIN")
    headers = _login(client, admin.email)

    create_response = client.post(
        "/api/v1/projects",
        headers=headers,
        json={
            "id": "PRJ002",
            "name": "Proyecto Admin",
            "status": "active",
            "start_date": str(date(2026, 2, 1)),
            "end_date": None,
        },
    )
    assert create_response.status_code == 201
    body = create_response.json()
    assert body["id"] == "PRJ002"

    audit_response = client.get("/api/v1/audit", headers=headers)
    assert audit_response.status_code == 200
    assert any(item["action"] == "PROJECT_CREATED" for item in audit_response.json())


def test_admin_can_create_user(client, db):
    admin = _create_user_with_role(db, email="admin2@example.com", role_name="ADMIN")
    _create_user_with_role(db, email="supervisor-role@example.com", role_name="SUPERVISOR")
    headers = _login(client, admin.email)

    response = client.post(
        "/api/v1/users/admin",
        headers=headers,
        json={
            "email": "new.supervisor@example.com",
            "full_name": "New Supervisor",
            "password": "newpassword123",
            "role": "SUPERVISOR",
            "project_id": None,
        },
    )

    assert response.status_code == 201
    created = response.json()
    assert created["email"] == "new.supervisor@example.com"
    assert created["role_name"] == "SUPERVISOR"


def test_admin_can_create_project_with_catalog_bootstrap_from_tmq(client, db):
    admin = _create_user_with_role(db, email="admin-bootstrap@example.com", role_name="ADMIN")
    headers = _login(client, admin.email)

    base_project = db.query(Project).filter(Project.id == "TMQ").first()
    if base_project is None:
        base_project = Project(
            id="TMQ",
            name="Base TMQ",
            status=ProjectStatus.ACTIVE,
            start_date=date(2026, 1, 1),
            end_date=None,
        )
        db.add(base_project)
        db.flush()

    base_version = CatalogVersion(
        id=uuid4(),
        project_id="TMQ",
        version_number="1.0.0",
        status=CatalogStatus.PUBLISHED,
        hash="tmq-hash",
        published_by_id=admin.id,
    )
    db.add(base_version)
    db.flush()

    db.add(
        CATActivityType(
            id=uuid4(),
            version_id=base_version.id,
            code="INSP_CIVIL",
            name="Inspección Civil",
            description="Base",
            icon="engineering",
            color="#1976D2",
            sort_order=1,
            is_active=True,
            requires_approval=False,
        )
    )
    db.commit()

    create_response = client.post(
        "/api/v1/projects",
        headers=headers,
        json={
            "id": "TAP",
            "name": "Proyecto TAP",
            "status": "active",
            "start_date": "2026-03-01",
            "end_date": None,
            "bootstrap_from_tmq": True,
            "base_catalog_version": "1.0.0",
        },
    )

    assert create_response.status_code == 201

    tap_version = (
        db.query(CatalogVersion)
        .filter(CatalogVersion.project_id == "TAP", CatalogVersion.version_number == "1.0.0")
        .first()
    )
    assert tap_version is not None

    tap_activities = db.query(CATActivityType).filter(CATActivityType.version_id == tap_version.id).all()
    assert len(tap_activities) == 1
    assert tap_activities[0].code == "INSP_CIVIL"


def test_admin_can_create_project_with_fronts_and_location_scope(client, db):
    admin = _create_user_with_role(db, email="admin-territory@example.com", role_name="ADMIN")
    headers = _login(client, admin.email)

    response = client.post(
        "/api/v1/projects",
        headers=headers,
        json={
            "id": "TMX",
            "name": "Proyecto Territorio",
            "status": "active",
            "start_date": "2026-03-04",
            "fronts": [
                {"code": "F1", "name": "Frente 1"},
                {"code": "F2", "name": "Frente 2"},
            ],
            "location_scope": [
                {"estado": "Ciudad de México", "municipio": "Cuauhtémoc"},
                {"estado": "Querétaro", "municipio": "Querétaro"},
            ],
        },
    )

    assert response.status_code == 201

    fronts_response = client.get("/api/v1/fronts", headers=headers, params={"project_id": "TMX"})
    assert fronts_response.status_code == 200
    fronts = fronts_response.json()
    assert len(fronts) == 2
    assert fronts[0]["project_id"] == "TMX"

    states_response = client.get(
        "/api/v1/locations/states",
        headers=headers,
        params={"project_id": "TMX"},
    )
    assert states_response.status_code == 200
    states = states_response.json()
    assert any(item["estado"] == "Ciudad de México" for item in states)
    assert any(item["estado"] == "Querétaro" for item in states)


def test_locations_endpoint_can_resolve_project_by_front_id(client, db):
    admin = _create_user_with_role(db, email="admin-front-filter@example.com", role_name="ADMIN")
    headers = _login(client, admin.email)

    project = Project(
        id="TQ1",
        name="Proyecto Q1",
        status=ProjectStatus.ACTIVE,
        start_date=date(2026, 3, 1),
        end_date=None,
    )
    db.add(project)
    db.flush()

    front = Front(
        id=uuid4(),
        project_id="TQ1",
        code="F1",
        name="Frente 1",
        pk_start=0,
        pk_end=100,
    )
    db.add(front)
    db.commit()

    client.post(
        "/api/v1/projects/TQ1/locations",
        headers=headers,
        json=[
            {"estado": "Querétaro", "municipio": "Querétaro"},
            {"estado": "Querétaro", "municipio": "San Juan del Río"},
        ],
    )

    response = client.get(
        "/api/v1/locations",
        headers=headers,
        params={"front_id": str(front.id), "estado": "Querétaro"},
    )
    assert response.status_code == 200
    payload = response.json()
    assert len(payload) == 2
    assert all(item["estado"] == "Querétaro" for item in payload)


def test_assignments_assignees_and_create_flow(client, db):
    admin = _create_user_with_role(db, email="admin-assign@example.com", role_name="ADMIN")
    operative = _create_user_with_role(db, email="oper-assign@example.com", role_name="OPERATIVO")
    headers = _login(client, admin.email)

    project = Project(
        id="TPA",
        name="Proyecto Asignaciones",
        status=ProjectStatus.ACTIVE,
        start_date=date(2026, 3, 1),
        end_date=None,
    )
    db.add(project)
    db.flush()

    front = Front(
        id=uuid4(),
        project_id="TPA",
        code="F1",
        name="Frente 1",
        pk_start=0,
        pk_end=100,
    )
    db.add(front)

    role_oper = db.query(Role).filter(Role.name == "OPERATIVO").first()
    db.add(
        UserRoleScope(
            user_id=operative.id,
            role_id=role_oper.id,
            project_id="TPA",
            front_id=None,
            location_id=None,
            assigned_by_id=admin.id,
        )
    )

    catalog = CatalogVersion(
        id=uuid4(),
        project_id="TPA",
        version_number="1.0.0",
        status=CatalogStatus.PUBLISHED,
        hash="tpa-hash",
        published_by_id=admin.id,
    )
    db.add(catalog)
    db.flush()

    db.add(
        CATActivityType(
            id=uuid4(),
            version_id=catalog.id,
            code="INSP_CIVIL",
            name="Inspección Civil",
            description="Base",
            icon="engineering",
            color="#1976D2",
            sort_order=1,
            is_active=True,
            requires_approval=False,
        )
    )
    db.commit()

    assignees_response = client.get(
        "/api/v1/assignments/assignees",
        headers=headers,
        params={"project_id": "TPA"},
    )
    assert assignees_response.status_code == 200
    assignees = assignees_response.json()
    assert any(item["email"] == operative.email for item in assignees)

    create_response = client.post(
        "/api/v1/assignments",
        headers=headers,
        json={
            "project_id": "TPA",
            "assignee_user_id": str(operative.id),
            "activity_type_code": "INSP_CIVIL",
            "title": "Inspección turno mañana",
            "front_id": str(front.id),
            "pk": 25,
            "start_at": "2026-03-05T08:00:00Z",
            "end_at": "2026-03-05T09:00:00Z",
            "risk": "bajo",
        },
    )
    assert create_response.status_code == 201
    created = create_response.json()
    assert created["project_id"] == "TPA"
    assert created["assignee_user_id"] == str(operative.id)
    assert created["activity_id"] == "INSP_CIVIL"
    assert created["status"] == "PROGRAMADA"

    list_response = client.get(
        "/api/v1/assignments",
        headers=headers,
        params={
            "project_id": "TPA",
            "from": datetime(2026, 3, 5, 0, 0, 0).isoformat(),
            "to": datetime(2026, 3, 5, 0, 0, 0).isoformat(),
        },
    )
    assert list_response.status_code == 200
    rows = list_response.json()
    assert any(item["assignee_user_id"] == str(operative.id) for item in rows)
