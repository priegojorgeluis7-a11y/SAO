"""Authentication endpoint tests (Firestore-only)."""

from datetime import datetime, timezone
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.core.config import settings
from app.core.enums import UserStatus
from app.core.security import get_password_hash
from app.services.firestore_identity_service import FirestoreUserPrincipal
from app.api.deps import verify_project_access


def _login(client, email: str, password: str):
    return client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )


@pytest.fixture(scope="function")
def force_firestore_backend(monkeypatch):
    monkeypatch.setattr(settings, "DATA_BACKEND", "firestore", raising=False)


def _build_firestore_principal(*, email: str, password: str, project_ids: list[str] | None = None):
    return FirestoreUserPrincipal(
        id=uuid4(),
        email=email,
        full_name="Firestore User",
        status=UserStatus.ACTIVE,
        created_at=datetime.now(timezone.utc),
        last_login_at=None,
        roles=["OPERATIVO"],
        project_ids=project_ids or [],
        password_hash=get_password_hash(password),
        pin_hash=None,
    )


def test_firestore_login_success(client, monkeypatch, force_firestore_backend):
    principal = _build_firestore_principal(email="fs-user@example.com", password="testpass123")

    monkeypatch.setattr(
        "app.api.v1.auth.get_firestore_user_by_email",
        lambda email: principal if email == principal.email else None,
    )
    monkeypatch.setattr("app.api.v1.auth.update_last_login", lambda _user_id: None)

    response = _login(client, principal.email, "testpass123")
    assert response.status_code == 200
    payload = response.json()
    assert "access_token" in payload
    assert "refresh_token" in payload


def test_firestore_login_wrong_password_returns_401(client, monkeypatch, force_firestore_backend):
    principal = _build_firestore_principal(email="fs-user2@example.com", password="testpass123")

    monkeypatch.setattr("app.api.v1.auth.get_firestore_user_by_email", lambda _email: principal)
    monkeypatch.setattr("app.api.v1.auth.update_last_login", lambda _user_id: None)

    response = _login(client, principal.email, "bad-password")
    assert response.status_code == 401
    assert "Incorrect email or password" in response.json()["detail"]


def test_firestore_refresh_is_rejected_after_logout(client, monkeypatch, force_firestore_backend):
    principal = _build_firestore_principal(email="fs-logout@example.com", password="testpass123")

    def _update_last_logout(_user_id):
        principal.last_logout_at = datetime.now(timezone.utc)

    monkeypatch.setattr(
        "app.api.v1.auth.get_firestore_user_by_email",
        lambda email: principal if email == principal.email else None,
    )
    monkeypatch.setattr("app.api.v1.auth.get_firestore_user_by_id", lambda _user_id: principal)
    monkeypatch.setattr("app.api.deps.get_firestore_user_by_id", lambda _user_id: principal)
    monkeypatch.setattr("app.api.v1.auth.update_last_login", lambda _user_id: None)
    monkeypatch.setattr("app.api.v1.auth.update_last_logout", _update_last_logout)
    monkeypatch.setattr("app.api.v1.auth.write_firestore_audit_log", lambda **_kwargs: None)

    login_response = _login(client, principal.email, "testpass123")
    assert login_response.status_code == 200
    tokens = login_response.json()

    logout_response = client.post(
        "/api/v1/auth/logout",
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    )
    assert logout_response.status_code == 200

    refresh_response = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": tokens["refresh_token"]},
    )
    assert refresh_response.status_code == 401
    assert refresh_response.json()["detail"] == "Invalid refresh token"


def test_firestore_verify_project_access_enforces_scope(force_firestore_backend):
    principal = _build_firestore_principal(
        email="scope-user@example.com",
        password="testpass123",
        project_ids=["TMQ"],
    )

    verify_project_access(principal, "TMQ", db=None)

    with pytest.raises(HTTPException) as exc_info:
        verify_project_access(principal, "TAP", db=None)

    assert exc_info.value.status_code == 403


def test_login_nonexistent_user_returns_401(client, monkeypatch, force_firestore_backend):
    monkeypatch.setattr("app.api.v1.auth.get_firestore_user_by_email", lambda _email: None)
    response = _login(client, "nonexistent@example.com", "anypassword")
    assert response.status_code == 401


def test_signup_accepts_name_parts_and_birth_date(client, monkeypatch, force_firestore_backend):
    captured: dict[str, object] = {}
    principal = _build_firestore_principal(
        email="new.user@example.com",
        password="Password123!",
    )

    monkeypatch.setattr(settings, "SIGNUP_INVITE_CODE", "TEST-INVITE", raising=False)
    monkeypatch.setattr("app.api.v1.auth.get_firestore_user_by_email", lambda _email: None)

    def _create_user(**kwargs):
        captured.update(kwargs)
        return principal

    monkeypatch.setattr("app.api.v1.auth.create_firestore_user", _create_user)

    response = client.post(
        "/api/v1/auth/signup",
        json={
            "first_name": "jUaN",
            "last_name": "péREZ",
            "second_last_name": "lóPEZ",
            "birth_date": "1990-01-02",
            "email": "New.User@Example.COM",
            "password": "Password123!",
            "role": "OPERATIVO",
            "invite_code": "TEST-INVITE",
        },
    )

    assert response.status_code == 201
    assert captured["email"] == "new.user@example.com"
    assert captured["full_name"] == "Juan Pérez López"
    assert captured["first_name"] == "Juan"
    assert captured["last_name"] == "Pérez"
    assert captured["second_last_name"] == "López"
    assert captured["birth_date"] == "1990-01-02"
