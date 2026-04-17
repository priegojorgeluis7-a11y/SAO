from datetime import datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

from app.api.v1 import assignments as assignments_api
from app.schemas.assignment import AssignmentCreate, AssignmentTransferRequest
from tests.test_firestore_e2e_flow import _FakeFirestoreClient


def test_list_assignments_uses_explicit_assignment_window(monkeypatch):
    fake_client = _FakeFirestoreClient()
    project_id = "TMQ"
    assignee_id = str(uuid4())
    assignment_id = str(uuid4())
    start_at = datetime(2026, 3, 27, 15, 0, tzinfo=timezone.utc)
    end_at = datetime(2026, 3, 27, 16, 0, tzinfo=timezone.utc)

    fake_client.collection("activities").document(assignment_id).set(
        {
            "uuid": assignment_id,
            "project_id": project_id,
            "assigned_to_user_id": assignee_id,
            "activity_type_code": "INSP_CIVIL",
            "title": "Asignacion visible en planeacion",
            "execution_state": "PENDIENTE",
            "pk_start": 10,
            "assignment_start_at": start_at.isoformat(),
            "assignment_end_at": end_at.isoformat(),
            # Simulate a later operational update that must not move the planning slot.
            "created_at": datetime(2026, 3, 20, 9, 0, tzinfo=timezone.utc).isoformat(),
            "updated_at": datetime(2026, 3, 28, 9, 0, tzinfo=timezone.utc).isoformat(),
        }
    )

    monkeypatch.setattr(assignments_api, "get_firestore_client", lambda: fake_client)
    monkeypatch.setattr(
        assignments_api,
        "list_firestore_users",
        lambda: [SimpleNamespace(id=assignee_id, full_name="Planeacion User", email="plan@example.com")],
        raising=False,
    )
    monkeypatch.setattr(assignments_api, "user_has_any_role", lambda *args, **kwargs: True)

    result = assignments_api.list_assignments(
        project_id=project_id,
        from_dt=datetime(2026, 3, 27, 0, 0, tzinfo=timezone.utc),
        to_dt=datetime(2026, 3, 28, 0, 0, tzinfo=timezone.utc),
        include_all=True,
        current_user=SimpleNamespace(id=str(uuid4())),
    )

    assert len(result) == 1
    assert result[0].id == assignment_id
    assert result[0].start_at == start_at
    assert result[0].end_at == end_at


def test_build_assignment_list_item_falls_back_to_legacy_timestamps():
    start_at = datetime(2026, 3, 27, 15, 0, tzinfo=timezone.utc)
    end_at = datetime(2026, 3, 27, 16, 0, tzinfo=timezone.utc)
    item = assignments_api._build_assignment_list_item(
        doc_id=str(uuid4()),
        payload={
            "uuid": str(uuid4()),
            "project_id": "TMQ",
            "assigned_to_user_id": str(uuid4()),
            "activity_type_code": "INSP_CIVIL",
            "title": "Legacy assignment",
            "created_at": start_at.isoformat(),
            "updated_at": end_at.isoformat(),
            "execution_state": "PENDIENTE",
            "pk_start": 10,
        },
        project_id="TMQ",
        assignee_principal=None,
    )

    assert item.start_at == start_at
    assert item.end_at == end_at


def test_create_assignment_writes_audit_with_assignment_context(monkeypatch):
    fake_client = _FakeFirestoreClient()
    assignee_id = str(uuid4())
    actor_id = str(uuid4())
    audit_calls = []

    monkeypatch.setattr(assignments_api, 'get_firestore_client', lambda: fake_client)
    monkeypatch.setattr(assignments_api, '_next_project_sync_version', lambda *_args, **_kwargs: 7)
    monkeypatch.setattr(
        assignments_api,
        'get_firestore_user_by_id',
        lambda user_id: SimpleNamespace(
            id=user_id,
            full_name='Operativo Demo',
            email='operativo@example.com',
            roles=['OPERATIVO'],
            project_ids=['TMQ'],
            status='active',
        ),
    )
    monkeypatch.setattr(
        assignments_api,
        'write_firestore_audit_log',
        lambda **kwargs: audit_calls.append(kwargs),
    )

    result = assignments_api.create_assignment(
        payload=AssignmentCreate(
            project_id='TMQ',
            assignee_user_id=assignee_id,
            activity_type_code='INSP_CIVIL',
            title='Asignación con auditoría',
            start_at=datetime(2026, 4, 16, 12, 0, tzinfo=timezone.utc),
            end_at=datetime(2026, 4, 16, 13, 0, tzinfo=timezone.utc),
        ),
        current_user=SimpleNamespace(
            id=actor_id,
            email='coord@example.com',
            full_name='Coord Demo',
            roles=['COORD'],
        ),
    )

    assert result.project_id == 'TMQ'
    assert len(audit_calls) == 1
    assert audit_calls[0]['action'] == 'ASSIGNMENT_CREATED'
    assert audit_calls[0]['entity'] == 'activity'
    assert audit_calls[0]['details']['assigned_to_name'] == 'Operativo Demo'


def test_transfer_assignment_writes_actor_and_role_details(monkeypatch):
    fake_client = _FakeFirestoreClient()
    assignment_id = str(uuid4())
    current_assignee_id = str(uuid4())
    next_assignee_id = str(uuid4())
    fake_client.collection('activities').document(assignment_id).set(
        {
            'uuid': assignment_id,
            'project_id': 'TMQ',
            'assigned_to_user_id': current_assignee_id,
            'title': 'Transferencia con auditoría',
            'execution_state': 'PENDIENTE',
            'assignment_start_at': datetime(2026, 4, 16, 10, 0, tzinfo=timezone.utc).isoformat(),
            'assignment_end_at': datetime(2026, 4, 16, 11, 0, tzinfo=timezone.utc).isoformat(),
            'sync_version': 2,
        }
    )
    audit_calls = []

    monkeypatch.setattr(assignments_api, 'get_firestore_client', lambda: fake_client)
    monkeypatch.setattr(assignments_api, '_next_project_sync_version', lambda *_args, **_kwargs: 3)
    monkeypatch.setattr(assignments_api, '_is_privileged_assignment_manager', lambda *_args, **_kwargs: True)

    def _fake_user(user_id):
        mapping = {
            current_assignee_id: SimpleNamespace(full_name='Operativo Uno', email='uno@example.com', roles=['OPERATIVO']),
            next_assignee_id: SimpleNamespace(full_name='Supervisor Dos', email='dos@example.com', roles=['SUPERVISOR'], status='active', project_ids=['TMQ']),
        }
        return mapping.get(str(user_id))

    monkeypatch.setattr(assignments_api, 'get_firestore_user_by_id', _fake_user)
    monkeypatch.setattr(
        assignments_api,
        'write_firestore_audit_log',
        lambda **kwargs: audit_calls.append(kwargs),
    )

    assignments_api.transfer_assignment(
        assignment_id=assignment_id,
        payload=AssignmentTransferRequest(
            assignee_user_id=next_assignee_id,
            reason='Cobertura temporal',
        ),
        current_user=SimpleNamespace(
            id=str(uuid4()),
            email='admin@example.com',
            full_name='Admin Demo',
            roles=['ADMIN'],
        ),
    )

    assert len(audit_calls) == 1
    assert audit_calls[0]['action'] == 'ASSIGNMENT_TRANSFERRED'
    assert audit_calls[0]['entity'] == 'activity'
    assert audit_calls[0]['details']['to_assignee_role'] == 'SUPERVISOR'


def test_next_project_sync_version_falls_back_when_index_query_fails(monkeypatch):
    class _FailingOrderQuery:
        def limit(self, _value):
            return self

        def stream(self):
            raise RuntimeError('The query requires an index')

    class _FallbackCollection:
        def __init__(self, docs):
            self._docs = docs

        def where(self, field, op, value):
            assert field == 'project_id'
            assert op == '=='
            filtered = [doc for doc in self._docs if doc.get('project_id') == value]

            class _WhereQuery:
                def __init__(self, docs):
                    self._docs = docs

                def order_by(self, *_args, **_kwargs):
                    return _FailingOrderQuery()

                def stream(self):
                    for payload in self._docs:
                        yield SimpleNamespace(to_dict=lambda payload=payload: payload)

            return _WhereQuery(filtered)

    class _FallbackClient:
        def __init__(self, docs):
            self._docs = docs

        def collection(self, name):
            assert name == 'activities'
            return _FallbackCollection(self._docs)

    fake_client = _FallbackClient(
        [
            {'project_id': 'TMQ', 'sync_version': 4},
            {'project_id': 'TMQ', 'sync_version': 9},
            {'project_id': 'TAP', 'sync_version': 15},
        ]
    )

    next_version = assignments_api._next_project_sync_version(fake_client, 'TMQ')

    assert next_version == 10