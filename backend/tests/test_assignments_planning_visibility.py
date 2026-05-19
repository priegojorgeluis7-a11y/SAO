from datetime import datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

import logging

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
    monkeypatch.setattr(
        assignments_api,
        "resolve_user_project_access",
        lambda *_args, **_kwargs: (False, {project_id}),
    )

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


def test_list_assignments_single_project_does_not_scan_other_projects(monkeypatch):
    class _NoProjectScanClient(_FakeFirestoreClient):
        def collection(self, name: str):
            if name == 'projects':
                raise AssertionError('single-project agenda request should not scan projects collection')
            return super().collection(name)

    fake_client = _NoProjectScanClient()
    tmq_assignee_id = str(uuid4())
    tap_assignee_id = str(uuid4())
    tmq_assignment_id = str(uuid4())
    tap_assignment_id = str(uuid4())

    fake_client.collection('activities').document(tmq_assignment_id).set(
        {
            'uuid': tmq_assignment_id,
            'project_id': 'TMQ',
            'assigned_to_user_id': tmq_assignee_id,
            'activity_type_code': 'INSP_CIVIL',
            'title': 'Actividad TMQ',
            'execution_state': 'PENDIENTE',
            'pk_start': 10,
            'assignment_start_at': datetime(2026, 4, 27, 15, 0, tzinfo=timezone.utc).isoformat(),
            'assignment_end_at': datetime(2026, 4, 27, 16, 0, tzinfo=timezone.utc).isoformat(),
        }
    )
    fake_client.collection('activities').document(tap_assignment_id).set(
        {
            'uuid': tap_assignment_id,
            'project_id': 'TAP',
            'assigned_to_user_id': tap_assignee_id,
            'activity_type_code': 'INSP_CIVIL',
            'title': 'Actividad TAP',
            'execution_state': 'PENDIENTE',
            'pk_start': 20,
            'assignment_start_at': datetime(2026, 4, 27, 17, 0, tzinfo=timezone.utc).isoformat(),
            'assignment_end_at': datetime(2026, 4, 27, 18, 0, tzinfo=timezone.utc).isoformat(),
        }
    )

    monkeypatch.setattr(assignments_api, 'get_firestore_client', lambda: fake_client)
    monkeypatch.setattr(
        assignments_api,
        'list_firestore_users',
        lambda: [
            SimpleNamespace(id=tmq_assignee_id, full_name='Usuario TMQ', email='tmq@example.com'),
            SimpleNamespace(id=tap_assignee_id, full_name='Usuario TAP', email='tap@example.com'),
        ],
        raising=False,
    )
    monkeypatch.setattr(assignments_api, 'user_has_any_role', lambda *args, **kwargs: True)
    monkeypatch.setattr(
        assignments_api,
        'resolve_user_project_access',
        lambda *_args, **_kwargs: (False, {'TMQ', 'TAP'}),
    )

    result = assignments_api.list_assignments(
        project_id='TMQ',
        from_dt=datetime(2026, 4, 27, 0, 0, tzinfo=timezone.utc),
        to_dt=datetime(2026, 4, 28, 0, 0, tzinfo=timezone.utc),
        include_all=True,
        current_user=SimpleNamespace(id=str(uuid4())),
    )

    assert [item.project_id for item in result] == ['TMQ']
    assert [item.id for item in result] == [tmq_assignment_id]


def test_list_assignments_include_all_returns_canceled_items(monkeypatch):
    fake_client = _FakeFirestoreClient()
    project_id = 'TMQ'
    creator_id = str(uuid4())
    assignment_id = str(uuid4())
    start_at = datetime(2026, 4, 27, 8, 0, tzinfo=timezone.utc)
    end_at = datetime(2026, 4, 27, 9, 0, tzinfo=timezone.utc)

    fake_client.collection('activities').document(assignment_id).set(
        {
            'uuid': assignment_id,
            'project_id': project_id,
            'assigned_to_user_id': None,
            'created_by_user_id': creator_id,
            'activity_type_code': 'REU',
            'title': 'Reunion cancelada',
            'execution_state': 'PENDIENTE',
            'pk_start': 12,
            'assignment_start_at': start_at.isoformat(),
            'assignment_end_at': end_at.isoformat(),
            'deleted_at': datetime(2026, 4, 27, 7, 30, tzinfo=timezone.utc).isoformat(),
        }
    )

    monkeypatch.setattr(assignments_api, 'get_firestore_client', lambda: fake_client)
    monkeypatch.setattr(
        assignments_api,
        'list_firestore_users',
        lambda: [SimpleNamespace(id=creator_id, full_name='Usuario Planeacion', email='plan@example.com')],
        raising=False,
    )
    monkeypatch.setattr(assignments_api, 'user_has_any_role', lambda *args, **kwargs: True)
    monkeypatch.setattr(
        assignments_api,
        'resolve_user_project_access',
        lambda *_args, **_kwargs: (False, {project_id}),
    )

    result = assignments_api.list_assignments(
        project_id=project_id,
        from_dt=datetime(2026, 4, 27, 0, 0, tzinfo=timezone.utc),
        to_dt=datetime(2026, 4, 28, 0, 0, tzinfo=timezone.utc),
        include_all=True,
        current_user=SimpleNamespace(id=str(uuid4())),
    )

    assert len(result) == 1
    assert result[0].id == assignment_id
    assert result[0].status == 'CANCELADA'


def test_list_assignments_shows_item_to_secondary_participant(monkeypatch):
    fake_client = _FakeFirestoreClient()
    project_id = 'TMQ'
    primary_assignee_id = str(uuid4())
    secondary_assignee_id = str(uuid4())
    assignment_id = str(uuid4())

    fake_client.collection('activities').document(assignment_id).set(
        {
            'uuid': assignment_id,
            'project_id': project_id,
            'assigned_to_user_id': primary_assignee_id,
            'participant_user_ids': [primary_assignee_id, secondary_assignee_id],
            'activity_type_code': 'INSP_CIVIL',
            'title': 'Actividad compartida',
            'execution_state': 'PENDIENTE',
            'pk_start': 10,
            'assignment_start_at': datetime(2026, 4, 27, 15, 0, tzinfo=timezone.utc).isoformat(),
            'assignment_end_at': datetime(2026, 4, 27, 16, 0, tzinfo=timezone.utc).isoformat(),
        }
    )

    monkeypatch.setattr(assignments_api, 'get_firestore_client', lambda: fake_client)
    monkeypatch.setattr(
        assignments_api,
        'list_firestore_users',
        lambda: [
            SimpleNamespace(id=primary_assignee_id, full_name='Usuario Uno', email='uno@example.com'),
            SimpleNamespace(id=secondary_assignee_id, full_name='Usuario Dos', email='dos@example.com'),
        ],
        raising=False,
    )
    monkeypatch.setattr(assignments_api, 'user_has_any_role', lambda *args, **kwargs: False)
    monkeypatch.setattr(
        assignments_api,
        'resolve_user_project_access',
        lambda *_args, **_kwargs: (False, {project_id}),
    )

    result = assignments_api.list_assignments(
        project_id=project_id,
        from_dt=datetime(2026, 4, 27, 0, 0, tzinfo=timezone.utc),
        to_dt=datetime(2026, 4, 28, 0, 0, tzinfo=timezone.utc),
        include_all=False,
        current_user=SimpleNamespace(id=secondary_assignee_id),
    )

    assert len(result) == 1
    assert result[0].id == assignment_id


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
            assignee_user_ids=[str(uuid4())],
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
    assert len(audit_calls[0]['details']['participant_user_ids']) == 2


def test_create_assignment_accepts_catalog_activities_list_shape(monkeypatch):
    fake_client = _FakeFirestoreClient()
    assignee_id = str(uuid4())

    fake_client.collection('catalog_current').document('TAP').set(
        {
            'project_id': 'TAP',
            'version_id': 'catalog-tap-v1',
            'is_current': True,
        }
    )
    fake_client.collection('catalog_versions').document('catalog-tap-v1').set(
        {
            'project_id': 'TAP',
            'version_id': 'catalog-tap-v1',
            'activities': [
                {'id': 'CAM', 'name': 'Caminamiento'},
                {'id': 'REU', 'name': 'Reunión'},
            ],
        }
    )

    monkeypatch.setattr(assignments_api, 'get_firestore_client', lambda: fake_client)
    monkeypatch.setattr(assignments_api, '_next_project_sync_version', lambda *_args, **_kwargs: 5)
    monkeypatch.setattr(
        assignments_api,
        'get_firestore_user_by_id',
        lambda user_id: SimpleNamespace(
            id=user_id,
            full_name='Operativo TAP',
            email='tap@example.com',
            roles=['OPERATIVO'],
            project_ids=['TAP'],
            status='active',
        ),
    )
    monkeypatch.setattr(assignments_api, 'write_firestore_audit_log', lambda **_kwargs: None)

    result = assignments_api.create_assignment(
        payload=AssignmentCreate(
            project_id='TAP',
            assignee_user_id=assignee_id,
            activity_type_code='CAM',
            title='Caminamiento TAP',
            start_at=datetime(2026, 4, 27, 9, 0, tzinfo=timezone.utc),
            end_at=datetime(2026, 4, 27, 11, 0, tzinfo=timezone.utc),
        ),
        current_user=SimpleNamespace(
            id=str(uuid4()),
            email='coord@example.com',
            full_name='Coord Demo',
            roles=['COORD'],
        ),
    )

    assert result.project_id == 'TAP'
    assert result.title == 'Caminamiento TAP'
    stored_docs = list(fake_client.collection('activities').stream())
    assert len(stored_docs) == 1
    assert stored_docs[0].to_dict()['activity_type_code'] == 'CAM'


def test_create_assignment_accepts_catalog_bundle_effective_entities_shape(monkeypatch):
    fake_client = _FakeFirestoreClient()
    assignee_id = str(uuid4())

    fake_client.collection('catalog_current').document('TAP').set(
        {
            'project_id': 'TAP',
            'version_id': 'TAP@2026-04-24T01:38:15Z',
            'is_current': True,
        }
    )
    fake_client.collection('catalog_versions').document('TAP@2026-04-24T01:38:15Z').set(
        {
            'project_id': 'TAP',
            'version_id': 'TAP@2026-04-24T01:38:15Z',
            # Emula producción: versión sin sección activities.
        }
    )
    fake_client.collection('catalog_bundles').document('TAP').set(
        {
            'effective': {
                'entities': {
                    'activities': [
                        {'id': 'CAM', 'name': 'Caminamiento'},
                        {'id': 'REU', 'name': 'Reunión'},
                    ]
                }
            }
        }
    )

    monkeypatch.setattr(assignments_api, 'get_firestore_client', lambda: fake_client)
    monkeypatch.setattr(assignments_api, '_next_project_sync_version', lambda *_args, **_kwargs: 5)
    monkeypatch.setattr(
        assignments_api,
        'get_firestore_user_by_id',
        lambda user_id: SimpleNamespace(
            id=user_id,
            full_name='Operativo TAP',
            email='tap@example.com',
            roles=['OPERATIVO'],
            project_ids=['TAP'],
            status='active',
        ),
    )
    monkeypatch.setattr(assignments_api, 'write_firestore_audit_log', lambda **_kwargs: None)

    result = assignments_api.create_assignment(
        payload=AssignmentCreate(
            project_id='TAP',
            assignee_user_id=assignee_id,
            activity_type_code='CAM',
            title='Caminamiento TAP Bundle',
            start_at=datetime(2026, 4, 27, 9, 0, tzinfo=timezone.utc),
            end_at=datetime(2026, 4, 27, 11, 0, tzinfo=timezone.utc),
        ),
        current_user=SimpleNamespace(
            id=str(uuid4()),
            email='coord@example.com',
            full_name='Coord Demo',
            roles=['COORD'],
        ),
    )

    assert result.project_id == 'TAP'
    assert result.title == 'Caminamiento TAP Bundle'


def test_create_assignment_does_not_fail_when_catalog_lookup_misses_type(monkeypatch, caplog):
    fake_client = _FakeFirestoreClient()
    assignee_id = str(uuid4())

    fake_client.collection('catalog_current').document('TAP').set(
        {
            'project_id': 'TAP',
            'version_id': 'catalog-tap-v2',
            'is_current': True,
        }
    )
    fake_client.collection('catalog_versions').document('catalog-tap-v2').set(
        {
            'project_id': 'TAP',
            'version_id': 'catalog-tap-v2',
            'activities': [{'id': 'CAM', 'name': 'Caminamiento'}],
        }
    )

    monkeypatch.setattr(assignments_api, 'get_firestore_client', lambda: fake_client)
    monkeypatch.setattr(assignments_api, '_next_project_sync_version', lambda *_args, **_kwargs: 6)
    monkeypatch.setattr(
        assignments_api,
        'get_firestore_user_by_id',
        lambda user_id: SimpleNamespace(
            id=user_id,
            full_name='Operativo TAP',
            email='tap@example.com',
            roles=['OPERATIVO'],
            project_ids=['TAP'],
            status='active',
        ),
    )
    monkeypatch.setattr(assignments_api, 'write_firestore_audit_log', lambda **_kwargs: None)

    with caplog.at_level(logging.WARNING):
        result = assignments_api.create_assignment(
            payload=AssignmentCreate(
                project_id='TAP',
                assignee_user_id=assignee_id,
                activity_type_code='REU',
                title='Reunión TAP sin bloqueo',
                start_at=datetime(2026, 4, 27, 12, 0, tzinfo=timezone.utc),
                end_at=datetime(2026, 4, 27, 13, 0, tzinfo=timezone.utc),
            ),
            current_user=SimpleNamespace(
                id=str(uuid4()),
                email='coord@example.com',
                full_name='Coord Demo',
                roles=['COORD'],
            ),
        )

    assert result.project_id == 'TAP'
    assert result.title == 'Reunión TAP sin bloqueo'
    assert 'Assignment activity_type_code not present in resolved catalog' in caplog.text


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

    stored = fake_client.collection('activities').document(assignment_id).get().to_dict()

    assert len(audit_calls) == 1
    assert audit_calls[0]['action'] == 'ASSIGNMENT_TRANSFERRED'
    assert audit_calls[0]['entity'] == 'activity'
    assert audit_calls[0]['details']['to_assignee_role'] == 'SUPERVISOR'
    assert stored['assigned_to_user_id'] == next_assignee_id
    assert stored['assigned_to_user_name'] == 'Supervisor Dos'
    assert stored['assigned_to_user_email'] == 'dos@example.com'
    assert stored['assigned_to_name'] == 'Supervisor Dos'
    assert stored['assigned_to_role'] == 'SUPERVISOR'


def test_next_project_sync_version_falls_back_when_index_query_fails(monkeypatch):
    """Cuando el contador de Firestore falla, se recurre al escaneo de actividades."""

    class _ErrorCounterRef:
        def set(self, data, merge=False):
            raise RuntimeError("The query requires an index")

        def get(self):
            raise RuntimeError("The query requires an index")

    class _ErrorCounterCollection:
        def document(self, doc_id):
            return _ErrorCounterRef()

    class _ActivityCollection:
        def __init__(self, docs):
            self._docs = docs

        def where(self, field, op, value):
            filtered = [d for d in self._docs if d.get(field) == value]
            return _ActivityQuery(filtered)

    class _ActivityQuery:
        def __init__(self, docs):
            self._docs = docs

        def stream(self):
            for payload in self._docs:
                yield SimpleNamespace(to_dict=lambda p=payload: p)

    class _FallbackClient:
        def __init__(self, docs):
            self._docs = docs

        def collection(self, name):
            if name == "project_sync_counters":
                return _ErrorCounterCollection()
            return _ActivityCollection(self._docs)

    fake_client = _FallbackClient(
        [
            {'project_id': 'TMQ', 'sync_version': 4},
            {'project_id': 'TMQ', 'sync_version': 9},
            {'project_id': 'TAP', 'sync_version': 15},
        ]
    )

    next_version = assignments_api._next_project_sync_version(fake_client, 'TMQ')

    assert next_version == 10