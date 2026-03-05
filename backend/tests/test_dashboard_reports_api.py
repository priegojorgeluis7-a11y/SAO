from uuid import uuid4

from app.core.security import get_password_hash
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


def test_dashboard_kpis_endpoint_returns_payload(client, db):
    supervisor = _create_user_with_role(db, email="dashboard-supervisor@example.com", role_name="SUPERVISOR")
    headers = _login(client, supervisor.email)

    response = client.get("/api/v1/dashboard/kpis", headers=headers)
    assert response.status_code == 200

    body = response.json()
    assert "kpis" in body
    assert "recent_items" in body


def test_reports_activities_endpoint_returns_payload(client, db):
    supervisor = _create_user_with_role(db, email="reports-supervisor@example.com", role_name="SUPERVISOR")
    headers = _login(client, supervisor.email)

    response = client.get("/api/v1/reports/activities", headers=headers)
    assert response.status_code == 200

    body = response.json()
    assert "meta" in body
    assert "items" in body
