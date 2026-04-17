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
