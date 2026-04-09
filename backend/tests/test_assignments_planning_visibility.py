from datetime import datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

from app.api.v1 import assignments as assignments_api
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