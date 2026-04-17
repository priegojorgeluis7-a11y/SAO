from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.api.v1 import dashboard as dashboard_api
from app.api.v1 import dashboard_kpis as dashboard_kpis_api
from app.api.v1 import reports as reports_api
from app.api.v1 import review as review_api
from tests.test_firestore_e2e_flow import _FakeFirestoreClient


def test_dashboard_kpis_requires_accessible_projects(monkeypatch):
    fake_client = _FakeFirestoreClient()
    monkeypatch.setattr(dashboard_kpis_api, "get_firestore_client", lambda: fake_client)

    with pytest.raises(HTTPException) as exc_info:
        dashboard_kpis_api.get_operational_kpis(
            project_id=None,
            current_user=SimpleNamespace(project_ids=[]),
        )

    assert exc_info.value.status_code == 403
    assert exc_info.value.detail == "No accessible projects"


def test_dashboard_kpis_excludes_soft_deleted_from_total(monkeypatch):
    fake_client = _FakeFirestoreClient()
    now = datetime.now(timezone.utc)

    fake_client.collection("activities").document("active-1").set(
        {
            "uuid": "active-1",
            "project_id": "TMQ",
            "execution_state": "COMPLETADA",
            "created_at": now,
            "updated_at": now,
            "deleted_at": None,
        }
    )
    fake_client.collection("activities").document("deleted-1").set(
        {
            "uuid": "deleted-1",
            "project_id": "TMQ",
            "execution_state": "COMPLETADA",
            "created_at": now,
            "updated_at": now,
            "deleted_at": now,
        }
    )

    monkeypatch.setattr(dashboard_api, "get_firestore_client", lambda: fake_client)

    payload = dashboard_api.get_dashboard_kpis(
        project_id="TMQ",
        _current_user=SimpleNamespace(id=str(uuid4()), project_ids=["TMQ"]),
    )

    assert payload["kpis"]["total"] == 1
    assert payload["kpis"]["completed"] == 1


def test_reports_activities_paginates_and_preserves_meta(monkeypatch):
    fake_client = _FakeFirestoreClient()
    project_id = "TMQ"
    front_id = "front-1"
    user_id = str(uuid4())
    now = datetime.now(timezone.utc)

    fake_client.collection("fronts").document(front_id).set({"name": "Frente Norte"})
    fake_client.collection("users").document(user_id).set({"display_name": "Usuario Reportes"})

    older_id = str(uuid4())
    newer_id = str(uuid4())
    fake_client.collection("activities").document(older_id).set(
        {
            "uuid": older_id,
            "project_id": project_id,
            "front_id": front_id,
            "assigned_to_user_id": user_id,
            "activity_type_code": "INSP_CIVIL",
            "execution_state": "COMPLETADA",
            "review_decision": "APPROVE",
            "created_at": now - timedelta(days=1),
        }
    )
    fake_client.collection("activities").document(newer_id).set(
        {
            "uuid": newer_id,
            "project_id": project_id,
            "front_id": front_id,
            "assigned_to_user_id": user_id,
            "activity_type_code": "INSP_CIVIL",
            "execution_state": "COMPLETADA",
            "review_decision": "APPROVE",
            "created_at": now,
        }
    )

    monkeypatch.setattr(reports_api, "get_firestore_client", lambda: fake_client)

    payload = reports_api.list_report_activities(
        project_id=project_id,
        front=None,
        date_from=None,
        date_to=None,
        status=None,
        page=2,
        page_size=1,
        _current_user=SimpleNamespace(id=user_id),
    )

    assert payload["meta"]["total"] == 2
    assert payload["meta"]["page"] == 2
    assert payload["meta"]["page_size"] == 1
    assert payload["meta"]["has_next"] is False
    assert len(payload["items"]) == 1
    assert payload["items"][0]["id"] == older_id


def test_reports_activities_ignores_front_todos_and_recent_review_date(monkeypatch):
    fake_client = _FakeFirestoreClient()
    project_id = "TMQ"
    front_id = "front-1"
    user_id = str(uuid4())
    now = datetime.now(timezone.utc)

    fake_client.collection("fronts").document(front_id).set({"name": "Frente Norte"})
    fake_client.collection("users").document(user_id).set({"display_name": "Usuario Reportes"})

    activity_id = str(uuid4())
    fake_client.collection("activities").document(activity_id).set(
        {
            "uuid": activity_id,
            "project_id": project_id,
            "front_id": front_id,
            "assigned_to_user_id": user_id,
            "activity_type_code": "INSP_CIVIL",
            "execution_state": "COMPLETADA",
            "review_decision": "APPROVE",
            "created_at": now - timedelta(days=20),
            "updated_at": now,
            "last_reviewed_at": now,
        }
    )

    monkeypatch.setattr(reports_api, "get_firestore_client", lambda: fake_client)

    payload = reports_api.list_report_activities(
        project_id=project_id,
        front="Todos",
        date_from=now - timedelta(days=1),
        date_to=now + timedelta(minutes=1),
        status=None,
        page=1,
        page_size=50,
        _current_user=SimpleNamespace(id=user_id),
    )

    assert payload["meta"]["total"] == 1
    assert len(payload["items"]) == 1
    assert payload["items"][0]["id"] == activity_id
    assert payload["items"][0]["front"] == "Frente Norte"


def test_review_queue_applies_page_slice_after_filtering(monkeypatch):
    fake_client = _FakeFirestoreClient()
    project_id = "TMQ"
    front_id = "front-1"
    now = datetime.now(timezone.utc)

    fake_client.collection("fronts").document(front_id).set({"name": "Frente Uno"})

    activity_ids = [str(uuid4()), str(uuid4())]
    for index, activity_id in enumerate(activity_ids):
        fake_client.collection("activities").document(activity_id).set(
            {
                "uuid": activity_id,
                "project_id": project_id,
                "front_id": front_id,
                "execution_state": "REVISION_PENDIENTE",
                "activity_type_code": "INSP_CIVIL",
                "title": f"Actividad {index}",
                "created_at": now - timedelta(minutes=index),
                "updated_at": now - timedelta(minutes=index),
            }
        )

    monkeypatch.setattr(review_api, "get_firestore_client", lambda: fake_client)

    response = review_api.review_queue(
        project_id=project_id,
        front_id=None,
        status_filter=None,
        only_conflicts=False,
        q=None,
        from_dt=None,
        to_dt=None,
        page=2,
        page_size=1,
        _current_user=SimpleNamespace(id=str(uuid4()), project_ids=[project_id]),
    )

    assert response.counters.pending == 2
    assert len(response.items) == 1
    assert str(response.items[0].id) == activity_ids[1]


def test_review_queue_includes_legacy_en_revision_state(monkeypatch):
    fake_client = _FakeFirestoreClient()
    project_id = "TMQ"
    front_id = "front-1"
    now = datetime.now(timezone.utc)

    fake_client.collection("fronts").document(front_id).set({"name": "Frente Legacy"})

    activity_id = str(uuid4())
    fake_client.collection("activities").document(activity_id).set(
        {
            "uuid": activity_id,
            "project_id": project_id,
            "front_id": front_id,
            "execution_state": "EN_REVISION",
            "activity_type_code": "INSP_CIVIL",
            "title": "Actividad legacy",
            "created_at": now,
            "updated_at": now,
        }
    )

    monkeypatch.setattr(review_api, "get_firestore_client", lambda: fake_client)

    response = review_api.review_queue(
        project_id=project_id,
        front_id=None,
        status_filter=None,
        only_conflicts=False,
        q=None,
        from_dt=None,
        to_dt=None,
        page=1,
        page_size=50,
        _current_user=SimpleNamespace(id=str(uuid4()), project_ids=[project_id]),
    )

    assert len(response.items) == 1
    assert str(response.items[0].id) == activity_id
    assert response.items[0].status == "PENDING_REVIEW"
