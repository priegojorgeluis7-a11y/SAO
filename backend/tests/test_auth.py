"""Authentication endpoint tests."""

from datetime import datetime
from uuid import uuid4

from app.core.config import settings
from app.models.project import Project, ProjectStatus
from app.models.role import Role
from app.models.user_role_scope import UserRoleScope
from app.core.security import verify_password


def _ensure_role(db, role_name: str):
    role = db.query(Role).filter(Role.name == role_name).first()
    if role is None:
        role = Role(name=role_name, description=f"{role_name} role")
        db.add(role)
        db.commit()
        db.refresh(role)
    return role


def _login(client, email: str, password: str):
    """Execute login request and return the HTTP response."""
    return client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )


def test_login_success(client, test_user):
    """Test successful login"""
    response = _login(client, test_user.email, "testpass123")
    
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"


def test_login_invalid_credentials(client, test_user):
    """Test login with wrong password"""
    response = _login(client, test_user.email, "wrongpassword")
    
    assert response.status_code == 401
    assert "Incorrect email or password" in response.json()["detail"]


def test_login_nonexistent_user(client):
    """Test login with non-existent email"""
    response = _login(client, "nonexistent@example.com", "anypassword")
    
    assert response.status_code == 401


def test_get_me_with_valid_token(client, test_user):
    """Test /auth/me endpoint with valid token"""
    login_response = _login(client, test_user.email, "testpass123")
    tokens = login_response.json()
    
    # Get me
    response = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {tokens['access_token']}"}
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["email"] == test_user.email
    assert data["full_name"] == test_user.full_name


def test_get_me_without_token(client):
    """Test /auth/me without authentication"""
    response = client.get("/api/v1/auth/me")
    assert response.status_code == 401


def test_refresh_token(client, test_user):
    """Test token refresh endpoint"""
    login_response = _login(client, test_user.email, "testpass123")
    tokens = login_response.json()
    
    # Refresh
    response = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": tokens["refresh_token"]}
    )
    
    assert response.status_code == 200
    new_tokens = response.json()
    assert "access_token" in new_tokens
    assert "refresh_token" in new_tokens
    assert new_tokens["token_type"] == "bearer"
    assert isinstance(new_tokens["access_token"], str) and len(new_tokens["access_token"]) > 0


def test_signup_invite_code_incorrect_returns_403(client, db, monkeypatch):
    _ensure_role(db, "OPERATIVO")
    monkeypatch.setattr(settings, "SIGNUP_INVITE_CODE", "VALID-CODE", raising=False)
    monkeypatch.setattr(settings, "ADMIN_INVITE_CODE", None, raising=False)

    response = client.post(
        "/api/v1/auth/signup",
        json={
            "display_name": "Operativo 01",
            "email": "operativo1@example.com",
            "password": "Password123",
            "role": "OPERATIVO",
            "invite_code": "WRONG-CODE",
        },
    )

    assert response.status_code == 403


def test_signup_operativo_with_valid_invite_returns_201(client, db, monkeypatch):
    _ensure_role(db, "OPERATIVO")
    monkeypatch.setattr(settings, "SIGNUP_INVITE_CODE", "VALID-CODE", raising=False)
    monkeypatch.setattr(settings, "ADMIN_INVITE_CODE", None, raising=False)

    response = client.post(
        "/api/v1/auth/signup",
        json={
            "display_name": "Operativo 02",
            "email": "operativo2@example.com",
            "password": "Password123",
            "role": "OPERATIVO",
            "invite_code": "VALID-CODE",
        },
    )

    assert response.status_code == 201
    payload = response.json()
    assert payload["email"] == "operativo2@example.com"
    assert payload["role"] == "OPERATIVO"
    assert isinstance(payload["user_id"], str) and payload["user_id"]


def test_signup_admin_without_admin_invite_config_returns_403(client, db, monkeypatch):
    _ensure_role(db, "ADMIN")
    monkeypatch.setattr(settings, "SIGNUP_INVITE_CODE", "VALID-CODE", raising=False)
    monkeypatch.setattr(settings, "ADMIN_INVITE_CODE", None, raising=False)

    response = client.post(
        "/api/v1/auth/signup",
        json={
            "display_name": "Admin 01",
            "email": "admin1@example.com",
            "password": "Password123",
            "role": "ADMIN",
            "invite_code": "ANY-CODE",
        },
    )

    assert response.status_code == 403


def test_signup_admin_with_admin_invite_returns_201(client, db, monkeypatch):
    _ensure_role(db, "ADMIN")
    monkeypatch.setattr(settings, "SIGNUP_INVITE_CODE", "VALID-CODE", raising=False)
    monkeypatch.setattr(settings, "ADMIN_INVITE_CODE", "ADMIN-CODE", raising=False)

    response = client.post(
        "/api/v1/auth/signup",
        json={
            "display_name": "Admin 02",
            "email": "admin2@example.com",
            "password": "Password123",
            "role": "ADMIN",
            "invite_code": "ADMIN-CODE",
        },
    )

    assert response.status_code == 201
    payload = response.json()
    assert payload["email"] == "admin2@example.com"
    assert payload["role"] == "ADMIN"


def test_auth_roles_returns_configured_role_names(client, db):
    _ensure_role(db, "ADMIN")
    _ensure_role(db, "OPERATIVO")

    response = client.get("/api/v1/auth/roles")

    assert response.status_code == 200
    payload = response.json()
    assert isinstance(payload, list)
    assert "ADMIN" in payload
    assert "OPERATIVO" in payload


def test_update_my_pin_sets_hashed_pin(client, db, test_user):
    login_response = _login(client, test_user.email, "testpass123")
    tokens = login_response.json()

    response = client.put(
        "/api/v1/auth/me/pin",
        json={"pin": "1234"},
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    )

    assert response.status_code == 200
    assert response.json()["ok"] is True

    db.refresh(test_user)
    assert test_user.pin_hash is not None
    assert verify_password("1234", test_user.pin_hash)


def test_update_my_pin_rejects_non_digit_pin(client, test_user):
    login_response = _login(client, test_user.email, "testpass123")
    tokens = login_response.json()

    response = client.put(
        "/api/v1/auth/me/pin",
        json={"pin": "12ab"},
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    )

    assert response.status_code == 422


def test_login_rate_limit_returns_429(client, test_user, monkeypatch):
    monkeypatch.setattr(settings, "RATE_LIMIT_AUTH_LOGIN_PER_MINUTE", 2, raising=False)
    monkeypatch.setattr(settings, "RATE_LIMIT_WINDOW_SECONDS", 60, raising=False)

    first = _login(client, test_user.email, "testpass123")
    second = _login(client, test_user.email, "testpass123")
    third = _login(client, test_user.email, "testpass123")

    assert first.status_code == 200
    assert second.status_code == 200
    assert third.status_code == 429


def test_me_projects_returns_project_scoped_roles(client, db, test_user):
    role = _ensure_role(db, "OPERATIVO")
    tmq = Project(
        id="TMQ",
        name="Proyecto TMQ",
        status=ProjectStatus.ACTIVE,
        start_date=datetime.now().date(),
    )
    tap = Project(
        id="TAP",
        name="Proyecto TAP",
        status=ProjectStatus.ACTIVE,
        start_date=datetime.now().date(),
    )
    db.add(tmq)
    db.add(tap)
    db.flush()

    db.add(
        UserRoleScope(
            id=uuid4(),
            user_id=test_user.id,
            role_id=role.id,
            project_id="TMQ",
        )
    )
    db.commit()

    login_response = _login(client, test_user.email, "testpass123")
    token = login_response.json()["access_token"]
    response = client.get(
        "/api/v1/me/projects",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    payload = response.json()
    assert len(payload) == 1
    assert payload[0]["project_id"] == "TMQ"
    assert payload[0]["project_name"] == "Proyecto TMQ"
    assert payload[0]["role_names"] == ["OPERATIVO"]


def test_me_projects_returns_all_projects_for_global_scope(client, db, test_user):
    role = _ensure_role(db, "SUPERVISOR")
    db.add(
        Project(
            id="TMQ",
            name="Proyecto TMQ",
            status=ProjectStatus.ACTIVE,
            start_date=datetime.now().date(),
        )
    )
    db.add(
        Project(
            id="TAP",
            name="Proyecto TAP",
            status=ProjectStatus.ACTIVE,
            start_date=datetime.now().date(),
        )
    )
    db.flush()

    db.add(
        UserRoleScope(
            id=uuid4(),
            user_id=test_user.id,
            role_id=role.id,
            project_id=None,
        )
    )
    db.commit()

    login_response = _login(client, test_user.email, "testpass123")
    token = login_response.json()["access_token"]
    response = client.get(
        "/api/v1/me/projects",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    payload = response.json()
    assert [item["project_id"] for item in payload] == ["TAP", "TMQ"]
    assert all(item["role_names"] == ["SUPERVISOR"] for item in payload)
