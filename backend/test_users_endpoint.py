"""Test /users endpoint in all scenarios."""
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.api import deps as deps_module
from app.services.firestore_identity_service import get_firestore_user_by_id, list_firestore_users
from app.core.config import settings


@pytest.fixture
def client():
    return TestClient(app)


def test_operativo_can_access_users_endpoint(client, monkeypatch):
    """OPERATIVO user can call /users and see themselves."""
    monkeypatch.setattr(settings, "DATA_BACKEND", "firestore", raising=False)
    
    # Get real Fernanda from Firestore
    fernanda = get_firestore_user_by_id("f5f92a1b-c9e2-482a-937b-317dccd9429e")
    assert fernanda is not None
    print(f"\nFernanda: {fernanda.full_name}")
    print(f"  Roles: {fernanda.roles}")
    print(f"  Status: {fernanda.status}")
    
    # Fernanda calls /users with different parameters
    app.dependency_overrides[deps_module.get_current_user] = lambda: fernanda
    try:
        # Test 1: /users?role=OPERATIVO
        print("\n=== Test 1: /users?role=OPERATIVO ===")
        response = client.get("/api/v1/users?role=OPERATIVO")
        print(f"Status: {response.status_code}")
        assert response.status_code == 200
        payload = response.json()
        print(f"Response: {payload}")
        assert len(payload) >= 1
        assert payload[0]["email"] == "fernanda@sao.mx"
        
        # Test 2: /users?role=OPERATIVO&project_id=TMQ
        print("\n=== Test 2: /users?role=OPERATIVO&project_id=TMQ ===")
        response = client.get("/api/v1/users?role=OPERATIVO&project_id=TMQ")
        print(f"Status: {response.status_code}")
        assert response.status_code == 200
        payload = response.json()
        print(f"Response: {payload}")
        assert len(payload) >= 1
        assert payload[0]["full_name"] == "Fernanda Lopez Guevara"
        
        # Test 3: /users (no role, no project)
        print("\n=== Test 3: /users (no filters) ===")
        response = client.get("/api/v1/users")
        print(f"Status: {response.status_code}")
        assert response.status_code == 200
        payload = response.json()
        print(f"Response count: {len(payload)}")
        assert len(payload) >= 1
        
        print("\n✓ All tests passed")
    finally:
        app.dependency_overrides.pop(deps_module.get_current_user, None)


def test_admin_can_access_users_endpoint(client, monkeypatch):
    """ADMIN user can call /users and see all OPERATIVO users."""
    monkeypatch.setattr(settings, "DATA_BACKEND", "firestore", raising=False)
    
    # Get first ADMIN from Firestore
    users = list_firestore_users()
    admin = None
    for u in users:
        if any(r.upper() == "ADMIN" for r in u.roles):
            admin = u
            break
    
    if not admin:
        print("\n⚠️ No ADMIN user found, skipping test")
        return
    
    print(f"\nAdmin: {admin.full_name}")
    print(f"  Roles: {admin.roles}")
    
    app.dependency_overrides[deps_module.get_current_user] = lambda: admin
    try:
        # Admin calls /users?role=OPERATIVO
        print("\n=== Admin test: /users?role=OPERATIVO ===")
        response = client.get("/api/v1/users?role=OPERATIVO")
        print(f"Status: {response.status_code}")
        assert response.status_code == 200
        payload = response.json()
        print(f"Response count: {len(payload)}")
        for item in payload[:3]:
            print(f"  - {item['full_name']}")
        assert len(payload) > 0
        
        print("\n✓ Admin test passed")
    finally:
        app.dependency_overrides.pop(deps_module.get_current_user, None)
