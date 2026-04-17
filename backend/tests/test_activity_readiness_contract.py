from datetime import datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

from app.api import deps as deps_module
from app.api.v1 import activities as activities_api
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


class _FakeEvidenceQuery:
    def __init__(self, count):
        self._count = count

    def where(self, *_args, **_kwargs):
        return self

    def limit(self, _value):
        return self

    def stream(self):
        return [_FakeSnapshot({'id': f'ev-{idx}'}) for idx in range(self._count)]


class _FakeCollection:
    def __init__(self, name, activity_payload, evidence_count):
        self._name = name
        self._activity_payload = activity_payload
        self._evidence_count = evidence_count

    def document(self, _doc_id):
        if self._name != 'activities':
            raise AssertionError('Only activities docs are expected in this test')
        return _FakeDocRef(self._activity_payload)

    def where(self, *_args, **_kwargs):
        if self._name != 'evidences':
            raise AssertionError('Only evidences queries are expected in this test')
        return _FakeEvidenceQuery(self._evidence_count)


class _FakeClient:
    def __init__(self, activity_payload, evidence_count):
        self._activity_payload = activity_payload
        self._evidence_count = evidence_count

    def collection(self, name):
        return _FakeCollection(name, self._activity_payload, self._evidence_count)


def _principal():
    return FirestoreUserPrincipal(
        id=uuid4(),
        email='admin@example.com',
        full_name='Readiness Contract Test',
        status=UserStatus.ACTIVE,
        created_at=datetime.now(timezone.utc),
        last_login_at=None,
        roles=['ADMIN'],
        project_ids=['TMQ'],
        scopes=[],
        permission_scopes=[],
        password_hash='hash',
        pin_hash=None,
        last_logout_at=None,
    )


def test_activity_readiness_returns_desktop_compatible_contract(client, monkeypatch):
    activity_uuid = str(uuid4())
    dto = SimpleNamespace(
        uuid=activity_uuid,
        project_id='TMQ',
        latitude=20.0,
        longitude=-100.0,
        activity_type_code='ASAMBLEA',
    )
    activity_payload = {
        'uuid': activity_uuid,
        'project_id': 'TMQ',
        'server_id': None,
        'wizard_payload': {
            'evidences': [
                {'localPath': '/tmp/evidence.jpg'},
            ],
        },
    }

    monkeypatch.setattr(activities_api, '_get_activity_by_uuid_firestore', lambda _uuid: dto)
    monkeypatch.setattr(activities_api, 'get_firestore_client', lambda: _FakeClient(activity_payload, 1))

    app.dependency_overrides[deps_module.get_current_user] = _principal
    try:
        response = client.get(f'/api/v1/activities/{activity_uuid}/readiness')
    finally:
        app.dependency_overrides.pop(deps_module.get_current_user, None)

    assert response.status_code == 200
    payload = response.json()
    assert payload['ready'] is True
    assert payload['is_ready'] is True
    assert payload['evidence_count'] == 1
    assert payload['checklist_summary'] == {'total': 2, 'completed': 2}
    assert payload['missing'] == []
