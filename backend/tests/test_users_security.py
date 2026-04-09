from datetime import datetime, timezone
from uuid import uuid4

from app.api import deps as deps_module
from app.api.v1 import users as users_api
from app.core.config import settings
from app.main import app
from app.services.firestore_identity_service import FirestoreUserPrincipal
from app.core.enums import UserStatus


def _principal(
    *,
    email: str,
    roles: list[str],
    status: UserStatus = UserStatus.ACTIVE,
    scopes: list[dict[str, str | None]] | None = None,
) -> FirestoreUserPrincipal:
    return FirestoreUserPrincipal(
        id=uuid4(),
        email=email,
        full_name="Test Principal",
        status=status,
        created_at=datetime.now(timezone.utc),
        last_login_at=None,
        roles=roles,
        project_ids=["TMQ"],
        scopes=scopes or [],
        permission_scopes=[],
        password_hash="hash",
        pin_hash=None,
        last_logout_at=None,
    )


def test_users_list_rejects_operativo_role(client, monkeypatch):
    """OPERATIVOs can access /users but only see themselves."""
    monkeypatch.setattr(settings, "DATA_BACKEND", "firestore", raising=False)
    current_user = _principal(email="operativo@example.com", roles=["OPERATIVO"])
    monkeypatch.setattr(users_api, "list_firestore_users", lambda role=None: [])

    app.dependency_overrides[deps_module.get_current_user] = lambda: current_user
    try:
        response = client.get("/api/v1/users")
    finally:
        app.dependency_overrides.pop(deps_module.get_current_user, None)

    # OPERATIVO should get 200 but only see themselves
    assert response.status_code == 200
    payload = response.json()
    assert len(payload) == 1
    assert payload[0]["email"] == "operativo@example.com"


def test_users_list_allows_supervisor_role(client, monkeypatch):
    monkeypatch.setattr(settings, "DATA_BACKEND", "firestore", raising=False)
    current_user = _principal(email="supervisor@example.com", roles=["SUPERVISOR"])
    listed_user = _principal(email="listed@example.com", roles=["OPERATIVO"])
    monkeypatch.setattr(users_api, "list_firestore_users", lambda role=None: [listed_user])

    app.dependency_overrides[deps_module.get_current_user] = lambda: current_user
    try:
        response = client.get("/api/v1/users")
    finally:
        app.dependency_overrides.pop(deps_module.get_current_user, None)

    assert response.status_code == 200
    payload = response.json()
    assert len(payload) == 1
    assert payload[0]["email"] == "listed@example.com"


def test_admin_users_list_prefers_persisted_scopes(client, monkeypatch):
    monkeypatch.setattr(settings, "DATA_BACKEND", "firestore", raising=False)
    current_user = _principal(email="supervisor@example.com", roles=["SUPERVISOR"])
    listed_user = _principal(
        email="multi@example.com",
        roles=["OPERATIVO", "SUPERVISOR"],
        scopes=[
            {"role_name": "OPERATIVO", "project_id": "TMQ"},
            {"role_name": "OPERATIVO", "project_id": "QRO"},
            {"role_name": "SUPERVISOR", "project_id": None},
        ],
    )
    monkeypatch.setattr(users_api, "list_firestore_users", lambda role=None: [listed_user])

    app.dependency_overrides[deps_module.get_current_user] = lambda: current_user
    try:
        response = client.get("/api/v1/users/admin")
    finally:
        app.dependency_overrides.pop(deps_module.get_current_user, None)

    assert response.status_code == 200
    payload = response.json()
    assert len(payload) == 1
    scopes = payload[0]["scopes"]
    assert scopes == [
        {"role_name": "OPERATIVO", "project_id": "TMQ"},
        {"role_name": "OPERATIVO", "project_id": "QRO"},
        {"role_name": "SUPERVISOR", "project_id": None},
    ]


def test_delete_admin_user_rejects_supervisor_role(client, monkeypatch):
    monkeypatch.setattr(settings, "DATA_BACKEND", "firestore", raising=False)
    current_user = _principal(email="supervisor@example.com", roles=["SUPERVISOR"])

    app.dependency_overrides[deps_module.get_current_user] = lambda: current_user
    try:
        response = client.delete(f"/api/v1/users/admin/{uuid4()}")
    finally:
        app.dependency_overrides.pop(deps_module.get_current_user, None)

    assert response.status_code == 403


def test_delete_admin_user_requires_inactive_status(client, monkeypatch):
    monkeypatch.setattr(settings, "DATA_BACKEND", "firestore", raising=False)
    current_user = _principal(email="admin@example.com", roles=["ADMIN"])
    target_user = _principal(email="target@example.com", roles=["OPERATIVO"], status=UserStatus.ACTIVE)
    monkeypatch.setattr(users_api, "get_firestore_user_by_id", lambda user_id: target_user)

    app.dependency_overrides[deps_module.get_current_user] = lambda: current_user
    try:
        response = client.delete(f"/api/v1/users/admin/{target_user.id}")
    finally:
        app.dependency_overrides.pop(deps_module.get_current_user, None)

    assert response.status_code == 409
    assert response.headers.get("X-Error-Code") == "USER_DELETE_REQUIRES_INACTIVE"
    assert "inactive" in response.json()["detail"].lower()


def test_delete_admin_user_allows_inactive_user(client, monkeypatch):
    monkeypatch.setattr(settings, "DATA_BACKEND", "firestore", raising=False)
    current_user = _principal(email="admin@example.com", roles=["ADMIN"])
    target_user = _principal(email="target@example.com", roles=["OPERATIVO"], status=UserStatus.INACTIVE)
    monkeypatch.setattr(users_api, "get_firestore_user_by_id", lambda user_id: target_user)
    monkeypatch.setattr(users_api, "delete_firestore_user", lambda user_id: True)
    monkeypatch.setattr(users_api, "write_firestore_audit_log", lambda **kwargs: None)

    app.dependency_overrides[deps_module.get_current_user] = lambda: current_user
    try:
        response = client.delete(f"/api/v1/users/admin/{target_user.id}")
    finally:
        app.dependency_overrides.pop(deps_module.get_current_user, None)

    assert response.status_code == 204
