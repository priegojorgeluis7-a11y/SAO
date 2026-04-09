"""Test users endpoint with Fernanda as current user."""
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.api import deps as deps_module


def _principal(email, roles, full_name=None, project_ids=None, status="active"):
    """Create a mock principal."""
    class FakePrincipal:
        pass
    p = FakePrincipal()
    p.id = "f5f92a1b-c9e2-482a-937b-317dccd9429e"  # Fernanda ID
    p.email = email
    p.full_name = full_name or email.split("@")[0]
    p.roles = roles
    p.project_ids = project_ids or ["TMQ"]
    p.status = status
    return p


@pytest.fixture
def client():
    return TestClient(app)


def test_fernanda_can_see_herself(client, monkeypatch):
    """When Fernanda calls /users, she should see only herself."""
    from app.api.v1 import users as users_api
    from app.core.config import settings
    
    monkeypatch.setattr(settings, "DATA_BACKEND", "firestore", raising=False)
    
    # Fernanda is OPERATIVO
    fernanda = _principal(
        email="fernanda@example.com",
        roles=["OPERATIVO"],
        full_name="Fernanda Lopez Guevara",
        project_ids=["TMQ", "TQI"]
    )
    
    # Mock list_firestore_users to return multiple OPERATIVOs
    other_operativo = _principal(
        email="jesus@example.com",
        roles=["OPERATIVO"],
        full_name="Jesus Gaspar Rios",
        project_ids=["TMQ"]
    )
    monkeypatch.setattr(users_api, "list_firestore_users", lambda role=None: [fernanda, other_operativo])

    # Fernanda calls /users
    app.dependency_overrides[deps_module.get_current_user] = lambda: fernanda
    try:
        response = client.get("/api/v1/users?role=OPERATIVO&project_id=TMQ")
    finally:
        app.dependency_overrides.pop(deps_module.get_current_user, None)

    print(f"\n\nResponse status: {response.status_code}")
    print(f"Response body: {response.json()}")
    
    assert response.status_code == 200
    payload = response.json()
    
    # Should only see herself
    assert len(payload) == 1, f"Expected 1 user, got {len(payload)}: {payload}"
    assert payload[0]["email"] == "fernanda@example.com"
    print(f"\n✓ Fernanda sees herself in /users response")
