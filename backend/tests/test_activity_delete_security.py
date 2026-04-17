from datetime import datetime, timezone
from uuid import uuid4

from app.api import deps as deps_module
from app.api.v1 import activities as activities_api
from app.core.config import settings
from app.core.enums import UserStatus
from app.main import app
from app.services.firestore_identity_service import FirestoreUserPrincipal


class _FakeSnapshot:
    def __init__(self, payload):
        self._payload = payload

    @property
    def exists(self):
        return self._payload is not None

    def to_dict(self):
        return dict(self._payload) if self._payload is not None else None


class _FakeDocRef:
    def __init__(self, payload):
        self._payload = payload

    def get(self):
        return _FakeSnapshot(self._payload)

    def update(self, updates):
        self._payload.update(updates)


class _FakeCollection:
    def __init__(self, payload):
        self._payload = payload

    def document(self, _doc_id):
        return _FakeDocRef(self._payload)


class _FakeClient:
    def __init__(self, payload):
        self._payload = payload

    def collection(self, _name):
        return _FakeCollection(self._payload)


def _principal(*, email: str, roles: list[str], permission_scopes=None):
    return FirestoreUserPrincipal(
        id=uuid4(),
        email=email,
        full_name='Delete Security Test',
        status=UserStatus.ACTIVE,
        created_at=datetime.now(timezone.utc),
        last_login_at=None,
        roles=roles,
        project_ids=['TMQ'],
        scopes=[],
        permission_scopes=permission_scopes or [],
        password_hash='hash',
        pin_hash=None,
        last_logout_at=None,
    )


def _activity_payload(activity_uuid: str):
    now = datetime.now(timezone.utc)
    return {
        'uuid': activity_uuid,
        'server_id': None,
        'project_id': 'TMQ',
        'front_id': None,
        'pk_start': 100,
        'pk_end': None,
        'execution_state': 'PENDIENTE',
        'assigned_to_user_id': None,
        'created_by_user_id': str(uuid4()),
        'catalog_version_id': str(uuid4()),
        'activity_type_code': 'TEST_ACTIVITY',
        'latitude': None,
        'longitude': None,
        'title': 'Actividad protegida',
        'description': 'Solo admin puede borrar',
        'created_at': now,
        'updated_at': now,
        'deleted_at': None,
        'sync_version': 1,
    }


def test_activity_delete_rejects_non_admin_even_with_direct_permission_scope(client, monkeypatch):
    monkeypatch.setattr(settings, 'DATA_BACKEND', 'firestore', raising=False)
    activity_uuid = str(uuid4())
    payload = _activity_payload(activity_uuid)
    current_user = _principal(
        email='coord@example.com',
        roles=['COORD'],
        permission_scopes=[
            {
                'permission_code': 'activity.delete',
                'project_id': 'TMQ',
                'effect': 'allow',
            }
        ],
    )

    monkeypatch.setattr(activities_api, 'get_firestore_client', lambda: _FakeClient(payload))
    app.dependency_overrides[deps_module.get_current_user] = lambda: current_user
    try:
        response = client.delete(f'/api/v1/activities/{activity_uuid}')
    finally:
        app.dependency_overrides.pop(deps_module.get_current_user, None)

    assert response.status_code == 403
    assert 'administrators can delete activities' in response.json()['detail'].lower()
    assert payload['deleted_at'] is None


def test_activity_delete_writes_audit_for_admin(client, monkeypatch):
    monkeypatch.setattr(settings, 'DATA_BACKEND', 'firestore', raising=False)
    activity_uuid = str(uuid4())
    payload = _activity_payload(activity_uuid)
    current_user = _principal(email='admin@example.com', roles=['ADMIN'])
    audit_calls = []

    monkeypatch.setattr(activities_api, 'get_firestore_client', lambda: _FakeClient(payload))
    monkeypatch.setattr(
        activities_api,
        'write_firestore_audit_log',
        lambda **kwargs: audit_calls.append(kwargs),
    )

    app.dependency_overrides[deps_module.get_current_user] = lambda: current_user
    try:
        response = client.delete(f'/api/v1/activities/{activity_uuid}')
    finally:
        app.dependency_overrides.pop(deps_module.get_current_user, None)

    assert response.status_code == 200
    assert payload['deleted_at'] is not None
    assert response.json()['deleted_at'] is not None
    assert len(audit_calls) == 1
    assert audit_calls[0]['action'] == 'ACTIVITY_DELETE'
    assert audit_calls[0]['entity'] == 'activity'
    assert audit_calls[0]['entity_id'] == activity_uuid
