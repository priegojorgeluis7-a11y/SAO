from datetime import datetime, timezone

from app.api.v1 import completed_activities as completed_api


class _FakeSnapshot:
    def __init__(self, payload):
        self._payload = payload

    def to_dict(self):
        return dict(self._payload)


class _FakeQuery:
    def __init__(self, rows):
        self._rows = rows

    def where(self, *_args, **_kwargs):
        return self

    def stream(self):
        return [_FakeSnapshot(row) for row in self._rows]


class _FakeCollection:
    def __init__(self, rows):
        self._rows = rows

    def where(self, *_args, **_kwargs):
        return _FakeQuery(self._rows)

    def stream(self):
        return [_FakeSnapshot(row) for row in self._rows]


class _FakeClient:
    def __init__(self, rows):
        self._rows = rows

    def collection(self, _name):
        return _FakeCollection(self._rows)


def test_document_count_map_counts_all_pdf_documents():
    rows = [
        {
            'gcs_path': 'gs://bucket/report-1.pdf',
            'evidence_type': 'PDF',
        },
        {
            'gcs_path': 'gs://bucket/report-2.pdf',
            'type': 'DOCUMENT',
        },
        {
            'gcs_path': 'gs://bucket/photo-1.jpg',
            'type': 'PHOTO',
        },
    ]
    client = _FakeClient(rows)

    document_counts = completed_api._document_count_map(client, {'act-1'})
    evidence_counts = completed_api._evidence_count_map(client, {'act-1'})

    assert document_counts['act-1'] == 2
    assert evidence_counts['act-1'] == 1


def test_normalize_related_activity_ids_dedupes_and_excludes_self():
    normalized = completed_api._normalize_related_activity_ids(
        ['act-2', 'act-2', '', 'act-1', 'act-3'],
        current_id='act-1',
    )

    assert normalized == ['act-2', 'act-3']


def test_normalize_related_links_preserves_tracking_metadata():
    normalized = completed_api._normalize_related_links(
        [
            {
                'activity_id': 'act-2',
                'relation_type': 'seguimiento',
                'status': 'en_seguimiento',
                'reason': 'Mismo tema social',
                'next_action': 'Llamada con ejidatarios',
                'due_date': '2026-04-25',
            },
            {
                'activity_id': 'act-2',
                'relation_type': 'seguimiento',
            },
            'act-3',
            None,
        ],
        current_id='act-1',
    )

    assert [item['activity_id'] for item in normalized] == ['act-2', 'act-3']
    assert normalized[0]['reason'] == 'Mismo tema social'
    assert normalized[0]['next_action'] == 'Llamada con ejidatarios'
    assert normalized[1]['relation_type'] == 'seguimiento'


def test_list_completed_activities_keeps_all_project_users_but_excludes_other_projects(monkeypatch):
    rows = [
        {
            'uuid': 'act-own',
            'project_id': 'TMQ',
            'assigned_to_user_id': 'operativo-1',
            'review_decision': 'APPROVE',
            'activity_type_code': 'SOCIAL',
            'title': 'Actividad propia',
            'created_at': datetime(2026, 4, 18, tzinfo=timezone.utc),
        },
        {
            'uuid': 'act-other-user',
            'project_id': 'TMQ',
            'assigned_to_user_id': 'operativo-2',
            'review_decision': 'APPROVE',
            'activity_type_code': 'AMBIENTAL',
            'title': 'Actividad compañera',
            'created_at': datetime(2026, 4, 19, tzinfo=timezone.utc),
        },
        {
            'uuid': 'act-other-project',
            'project_id': 'TAP',
            'assigned_to_user_id': 'operativo-3',
            'review_decision': 'APPROVE',
            'activity_type_code': 'SEGURIDAD',
            'title': 'Proyecto ajeno',
            'created_at': datetime(2026, 4, 17, tzinfo=timezone.utc),
        },
    ]
    current_user = type(
        'Principal',
        (),
        {
            'id': 'operativo-1',
            'roles': ['OPERATIVO'],
            'project_ids': ['TMQ'],
            'permission_scopes': [],
        },
    )()

    monkeypatch.setattr(completed_api, 'get_firestore_client', lambda: _FakeClient(rows))
    monkeypatch.setattr(completed_api, '_build_fronts_map', lambda *_args, **_kwargs: {})
    monkeypatch.setattr(completed_api, '_load_project_front_scope_map', lambda *_args, **_kwargs: {})
    monkeypatch.setattr(
        completed_api,
        '_build_users_map',
        lambda *_args, **_kwargs: {
            'operativo-1': 'Operativo Uno',
            'operativo-2': 'Operativo Dos',
            'operativo-3': 'Operativo Tres',
        },
    )
    monkeypatch.setattr(completed_api, '_evidence_count_map', lambda *_args, **_kwargs: {})
    monkeypatch.setattr(completed_api, '_document_count_map', lambda *_args, **_kwargs: {})

    payload = completed_api.list_completed_activities(
        project_id=None,
        frente=None,
        tema=None,
        estado=None,
        municipio=None,
        usuario=None,
        q=None,
        page=1,
        page_size=50,
        _current_user=current_user,
    )
    ids = [item['id'] for item in payload['items']]

    assert 'act-own' in ids
    assert 'act-other-user' in ids
    assert 'act-other-project' not in ids


def test_supplemental_audit_trail_infers_review_and_report_events():
    created_at = datetime(2026, 4, 16, 18, 0, tzinfo=timezone.utc)
    reviewed_at = datetime(2026, 4, 16, 19, 0, tzinfo=timezone.utc)
    doc = {
        'uuid': 'act-1',
        'created_at': created_at,
        'last_reviewed_at': reviewed_at,
        'review_decision': 'APPROVE',
        'report_generated_at': reviewed_at,
    }

    evidences = [
        {
            'id': 'ev-1',
            'uploaded_at': created_at.isoformat(),
            'uploader_name': 'Jesus Gaspar Rios',
            'description': 'Evidencia inicial',
        }
    ]
    documents = [
        {
            'id': 'doc-1',
            'uploaded_at': reviewed_at.isoformat(),
            'uploader_name': 'Admin User',
            'description': 'Reporte operativo generado',
        }
    ]

    trail = completed_api._build_supplemental_audit_trail(
        doc,
        {},
        'Jesus Gaspar Rios',
        'Admin User',
        evidences,
        documents,
        set(),
    )

    actions = {entry['action'] for entry in trail}
    assert 'ACTIVITY_CREATED' in actions
    assert 'EVIDENCE_UPLOADED' in actions
    assert 'REVIEW_APPROVED' in actions
    assert 'REPORT_GENERATE' in actions
