from datetime import datetime, timedelta, timezone
from uuid import uuid4
from types import SimpleNamespace

from app.api import deps as deps_module
from app.main import app
from app.core.config import settings
from app.core.enums import UserStatus
from app.services.firestore_identity_service import FirestoreUserPrincipal


def _principal(*, email: str, roles: list[str]) -> FirestoreUserPrincipal:
    return FirestoreUserPrincipal(
        id=uuid4(),
        email=email,
        full_name='Test Principal',
        status=UserStatus.ACTIVE,
        created_at=datetime.now(timezone.utc),
        last_login_at=None,
        roles=roles,
        project_ids=['TMQ'],
        scopes=[],
        permission_scopes=[],
        password_hash='hash',
        pin_hash=None,
        last_logout_at=None,
    )


def _invitation_payload(
    invite_id: str = 'INV-123456',
    role: str = 'OPERATIVO',
) -> dict:
    now = datetime.now(timezone.utc)
    return {
        'invite_id': invite_id,
        'role': role,
        'created_by': 'admin@example.com',
        'target_email': 'new.user@example.com',
        'expires_at': (now + timedelta(days=7)).isoformat(),
        'used': False,
        'used_by': None,
        'used_at': None,
        'created_at': now.isoformat(),
    }


def test_admin_can_create_and_list_invitations(client, monkeypatch):
    from app.api.v1 import invitations as invitations_api

    monkeypatch.setattr(settings, 'DATA_BACKEND', 'firestore', raising=False)
    current_user = _principal(email='admin@example.com', roles=['ADMIN'])
    created = _invitation_payload(role='ADMIN')

    monkeypatch.setattr(invitations_api, 'list_invitations', lambda: [created], raising=False)
    monkeypatch.setattr(
        invitations_api,
        'create_invitation',
        lambda **kwargs: created,
        raising=False,
    )

    app.dependency_overrides[deps_module.get_current_user] = lambda: current_user
    try:
        list_response = client.get('/api/v1/invitations')
        create_response = client.post(
            '/api/v1/invitations',
            json={
                'role': 'ADMIN',
                'target_email': 'new.user@example.com',
                'expire_days': 7,
            },
        )
    finally:
        app.dependency_overrides.pop(deps_module.get_current_user, None)

    assert list_response.status_code == 200
    assert list_response.json()[0]['invite_id'] == 'INV-123456'

    assert create_response.status_code == 201
    assert create_response.json()['invite_id'] == 'INV-123456'


def test_signup_accepts_dynamic_invitation_code(client, monkeypatch):
    from app.api.v1 import auth as auth_api

    monkeypatch.setattr(settings, 'DATA_BACKEND', 'firestore', raising=False)
    monkeypatch.setattr(settings, 'SIGNUP_INVITE_CODE', 'STATIC-CODE', raising=False)

    consumed: list[tuple[str, str]] = []

    monkeypatch.setattr(
        auth_api,
        'validate_user_invitation',
        lambda invite_code, role_name, email: SimpleNamespace(invite_id=invite_code),
        raising=False,
    )
    monkeypatch.setattr(
        auth_api,
        'mark_invitation_used',
        lambda invite_id, used_by: consumed.append((invite_id, used_by)),
        raising=False,
    )
    monkeypatch.setattr(auth_api, 'get_firestore_user_by_email', lambda _email: None)

    created_user = _principal(email='new.user@example.com', roles=['OPERATIVO'])
    monkeypatch.setattr(auth_api, 'create_firestore_user', lambda **kwargs: created_user)

    response = client.post(
        '/api/v1/auth/signup',
        json={
            'display_name': 'Nuevo Usuario',
            'email': 'new.user@example.com',
            'password': 'Password123!',
            'role': 'OPERATIVO',
            'invite_code': 'DYNAMIC-123',
        },
    )

    assert response.status_code == 201
    assert response.json()['email'] == 'new.user@example.com'
    assert consumed == [('DYNAMIC-123', 'new.user@example.com')]


def test_signup_accepts_dynamic_admin_invitation_code(client, monkeypatch):
    from app.api.v1 import auth as auth_api

    monkeypatch.setattr(settings, 'DATA_BACKEND', 'firestore', raising=False)
    monkeypatch.setattr(settings, 'ADMIN_INVITE_CODE', '', raising=False)

    consumed: list[tuple[str, str]] = []

    monkeypatch.setattr(
        auth_api,
        'validate_user_invitation',
        lambda invite_code, role_name, email: SimpleNamespace(invite_id=invite_code),
        raising=False,
    )
    monkeypatch.setattr(
        auth_api,
        'mark_invitation_used',
        lambda invite_id, used_by: consumed.append((invite_id, used_by)),
        raising=False,
    )
    monkeypatch.setattr(auth_api, 'get_firestore_user_by_email', lambda _email: None)

    created_user = _principal(email='new.admin@example.com', roles=['ADMIN'])
    monkeypatch.setattr(auth_api, 'create_firestore_user', lambda **kwargs: created_user)

    response = client.post(
        '/api/v1/auth/signup',
        json={
            'display_name': 'Nueva Admin',
            'email': 'new.admin@example.com',
            'password': 'Password123!',
            'role': 'ADMIN',
            'invite_code': 'ADMIN-DYNAMIC-123',
        },
    )

    assert response.status_code == 201
    assert response.json()['role'] == 'ADMIN'
    assert consumed == [('ADMIN-DYNAMIC-123', 'new.admin@example.com')]
