"""Test Fernanda login flow."""
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.services.firestore_identity_service import get_firestore_user_by_id, get_firestore_user_by_email


def test_fernanda_login_and_users_endpoint(monkeypatch):
    """Simulate Fernanda logging in and calling /users."""
    from app.core.config import settings
    from app.services.firestore_identity_service import list_firestore_users
    
    monkeypatch.setattr(settings, "DATA_BACKEND", "firestore", raising=False)
    
    # Step 0: Find Fernanda's correct email
    print("\n=== STEP 0: Find Fernanda's email ===")
    all_users = list_firestore_users()
    fernanda_list = [u for u in all_users if "fernanda" in u.full_name.lower()]
    
    if not fernanda_list:
        print("❌ Fernanda NOT found in entire user list")
        return
    
    fernanda_user = fernanda_list[0]
    print(f"Found: {fernanda_user.full_name}")
    print(f"Email: {fernanda_user.email}")
    print(f"ID: {fernanda_user.id}")
    print(f"Roles (from list): {fernanda_user.roles}")
    
    # Step 1: Find Fernanda in Firestore by ID
    print("\n=== STEP 1: Find Fernanda by ID ===")
    fernanda_by_id = get_firestore_user_by_id(fernanda_user.id)
    
    if fernanda_by_id:
        print(f"Found: {fernanda_by_id.full_name}")
        print(f"  Roles (from get_by_id): {fernanda_by_id.roles}")
        print(f"  Status: {fernanda_by_id.status}")
    else:
        print(f"❌ NOT found by ID {fernanda_user.id}")
        return
    
    # Step 2: Test /users endpoint login
    print("\n=== STEP 2: Test /users endpoint ===")
    from app.api import deps as deps_module
    
    client = TestClient(app)
    app.dependency_overrides[deps_module.get_current_user] = lambda: fernanda_by_id
    try:
        response = client.get("/api/v1/users?role=OPERATIVO")
        print(f"Response status: {response.status_code}")
        if response.status_code == 200:
            payload = response.json()
            print(f"Response items: {len(payload)}")
            for item in payload:
                print(f"  - {item['full_name']} ({item['email']})")
        else:
            print(f"Error: {response.text}")
    finally:
        app.dependency_overrides.pop(deps_module.get_current_user, None)
