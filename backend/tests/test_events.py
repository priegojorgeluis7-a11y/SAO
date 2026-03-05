"""Tests for /api/v1/events endpoints."""
from datetime import datetime, timezone
from uuid import uuid4

import pytest

from app.models.catalog import CatalogStatus, CatalogVersion
from app.models.front import Front
from app.models.project import Project, ProjectStatus
from app.models.role import Role
from app.models.user_role_scope import UserRoleScope


# ─────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────

def _event_payload(
    *,
    project_id: str,
    reported_by_user_id: str,
    event_uuid: str | None = None,
    event_type_code: str = "DERRAME",
    title: str = "Evento test",
    severity: str = "MEDIUM",
    occurred_at: str | None = None,
    description: str | None = None,
    location_pk_meters: int | None = 142000,
    deleted_at=None,
) -> dict:
    return {
        "uuid": event_uuid or str(uuid4()),
        "project_id": project_id,
        "reported_by_user_id": reported_by_user_id,
        "event_type_code": event_type_code,
        "title": title,
        "severity": severity,
        "occurred_at": occurred_at or datetime.now(timezone.utc).isoformat(),
        "description": description,
        "location_pk_meters": location_pk_meters,
        "deleted_at": deleted_at,
    }


# ─────────────────────────────────────────────────────────────────
# Fixtures
# ─────────────────────────────────────────────────────────────────

@pytest.fixture
def test_role(db):
    role = Role(id=88, name="EVENT_TESTER", description="Test role for events tests")
    db.add(role)
    db.commit()
    db.refresh(role)
    return role


@pytest.fixture
def test_project_tmq(db):
    project = Project(
        id="TMQ",
        name="Test Project TMQ",
        status=ProjectStatus.ACTIVE,
        start_date=datetime.now().date(),
    )
    db.add(project)
    db.commit()
    db.refresh(project)
    return project


@pytest.fixture
def test_user_scope_tmq(db, test_user, test_role, test_project_tmq):
    scope = UserRoleScope(
        id=uuid4(),
        user_id=test_user.id,
        role_id=test_role.id,
        project_id=test_project_tmq.id,
    )
    db.add(scope)
    db.commit()
    db.refresh(scope)
    return scope


# ─────────────────────────────────────────────────────────────────
# Tests — Create
# ─────────────────────────────────────────────────────────────────

def test_create_event_success(client, auth_headers, test_project_tmq, test_user, test_user_scope_tmq):
    """Create a new event — should return 201."""
    payload = _event_payload(
        project_id=test_project_tmq.id,
        reported_by_user_id=str(test_user.id),
    )
    resp = client.post("/api/v1/events", json=payload, headers=auth_headers)
    assert resp.status_code == 201
    data = resp.json()
    assert data["uuid"] == payload["uuid"]
    assert data["event_type_code"] == "DERRAME"
    assert data["severity"] == "MEDIUM"
    assert data["sync_version"] >= 1
    assert data["server_id"] is not None
    assert data["deleted_at"] is None


def test_create_event_idempotent(client, auth_headers, test_project_tmq, test_user, test_user_scope_tmq):
    """Posting the same UUID twice should return 200 on second call."""
    payload = _event_payload(
        project_id=test_project_tmq.id,
        reported_by_user_id=str(test_user.id),
    )
    resp1 = client.post("/api/v1/events", json=payload, headers=auth_headers)
    assert resp1.status_code == 201

    resp2 = client.post("/api/v1/events", json=payload, headers=auth_headers)
    assert resp2.status_code == 200
    assert resp1.json()["server_id"] == resp2.json()["server_id"]


def test_create_event_requires_auth(client, test_project_tmq, test_user):
    """Creating an event without a token should return 401."""
    payload = _event_payload(
        project_id=test_project_tmq.id,
        reported_by_user_id=str(test_user.id),
    )
    resp = client.post("/api/v1/events", json=payload)
    assert resp.status_code == 401


def test_create_event_invalid_severity(client, auth_headers, test_project_tmq, test_user, test_user_scope_tmq):
    """Invalid severity value should return 422."""
    payload = _event_payload(
        project_id=test_project_tmq.id,
        reported_by_user_id=str(test_user.id),
        severity="EXTREME",
    )
    resp = client.post("/api/v1/events", json=payload, headers=auth_headers)
    assert resp.status_code == 422


# ─────────────────────────────────────────────────────────────────
# Tests — List
# ─────────────────────────────────────────────────────────────────

def test_list_events_empty(client, auth_headers, test_project_tmq, test_user_scope_tmq):
    """Empty list when no events exist."""
    resp = client.get(f"/api/v1/events?project_id={test_project_tmq.id}", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 0
    assert data["items"] == []


def test_list_events_with_data(client, auth_headers, test_project_tmq, test_user, test_user_scope_tmq):
    """List returns created events."""
    for _ in range(3):
        payload = _event_payload(
            project_id=test_project_tmq.id,
            reported_by_user_id=str(test_user.id),
        )
        client.post("/api/v1/events", json=payload, headers=auth_headers)

    resp = client.get(f"/api/v1/events?project_id={test_project_tmq.id}", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["total"] == 3


def test_list_events_filter_severity(client, auth_headers, test_project_tmq, test_user, test_user_scope_tmq):
    """Filter by severity returns only matching events."""
    for sev in ["LOW", "HIGH", "CRITICAL"]:
        payload = _event_payload(
            project_id=test_project_tmq.id,
            reported_by_user_id=str(test_user.id),
            severity=sev,
        )
        client.post("/api/v1/events", json=payload, headers=auth_headers)

    resp = client.get(
        f"/api/v1/events?project_id={test_project_tmq.id}&severity=HIGH",
        headers=auth_headers,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 1
    assert data["items"][0]["severity"] == "HIGH"


def test_list_events_since_version(client, auth_headers, test_project_tmq, test_user, test_user_scope_tmq):
    """since_version filter returns only newer events."""
    # Create 2 events
    for _ in range(2):
        payload = _event_payload(
            project_id=test_project_tmq.id,
            reported_by_user_id=str(test_user.id),
        )
        client.post("/api/v1/events", json=payload, headers=auth_headers)

    resp = client.get(
        f"/api/v1/events?project_id={test_project_tmq.id}&since_version=0",
        headers=auth_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["total"] == 2

    resp_none = client.get(
        f"/api/v1/events?project_id={test_project_tmq.id}&since_version=999",
        headers=auth_headers,
    )
    assert resp_none.json()["total"] == 0


def test_list_events_since_version_with_pagination(client, auth_headers, test_project_tmq, test_user, test_user_scope_tmq):
    """Events list paginates correctly while preserving since_version window."""
    created_uuids: list[str] = []
    for i in range(5):
        payload = _event_payload(
            project_id=test_project_tmq.id,
            reported_by_user_id=str(test_user.id),
            title=f"Event {i}",
        )
        resp = client.post("/api/v1/events", json=payload, headers=auth_headers)
        assert resp.status_code == 201
        created_uuids.append(resp.json()["uuid"])

    page1 = client.get(
        f"/api/v1/events?project_id={test_project_tmq.id}&since_version=0&page=1&page_size=3",
        headers=auth_headers,
    )
    assert page1.status_code == 200
    p1 = page1.json()
    assert p1["total"] == 5
    assert len(p1["items"]) == 3
    assert p1["has_next"] is True

    page2 = client.get(
        f"/api/v1/events?project_id={test_project_tmq.id}&since_version=0&page=2&page_size=3",
        headers=auth_headers,
    )
    assert page2.status_code == 200
    p2 = page2.json()
    assert p2["total"] == 5
    assert len(p2["items"]) == 2
    assert p2["has_next"] is False

    pulled = {
        *(item["uuid"] for item in p1["items"]),
        *(item["uuid"] for item in p2["items"]),
    }
    assert pulled == set(created_uuids)


# ─────────────────────────────────────────────────────────────────
# Tests — Get
# ─────────────────────────────────────────────────────────────────

def test_get_event_success(client, auth_headers, test_project_tmq, test_user, test_user_scope_tmq):
    """Get single event by UUID."""
    payload = _event_payload(
        project_id=test_project_tmq.id,
        reported_by_user_id=str(test_user.id),
    )
    client.post("/api/v1/events", json=payload, headers=auth_headers)

    resp = client.get(f"/api/v1/events/{payload['uuid']}", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["uuid"] == payload["uuid"]


def test_get_event_not_found(client, auth_headers):
    """Returns 404 for unknown UUID."""
    resp = client.get(f"/api/v1/events/{uuid4()}", headers=auth_headers)
    assert resp.status_code == 404


# ─────────────────────────────────────────────────────────────────
# Tests — Update
# ─────────────────────────────────────────────────────────────────

def test_update_event_severity(client, auth_headers, test_project_tmq, test_user, test_user_scope_tmq):
    """Update severity — sync_version must increment."""
    payload = _event_payload(
        project_id=test_project_tmq.id,
        reported_by_user_id=str(test_user.id),
        severity="LOW",
    )
    create_resp = client.post("/api/v1/events", json=payload, headers=auth_headers)
    initial_version = create_resp.json()["sync_version"]

    update_resp = client.put(
        f"/api/v1/events/{payload['uuid']}",
        json={"severity": "CRITICAL"},
        headers=auth_headers,
    )
    assert update_resp.status_code == 200
    updated = update_resp.json()
    assert updated["severity"] == "CRITICAL"
    assert updated["sync_version"] > initial_version


def test_update_event_resolved_at(client, auth_headers, test_project_tmq, test_user, test_user_scope_tmq):
    """Setting resolved_at marks event as resolved."""
    payload = _event_payload(
        project_id=test_project_tmq.id,
        reported_by_user_id=str(test_user.id),
    )
    client.post("/api/v1/events", json=payload, headers=auth_headers)

    resolved_time = datetime.now(timezone.utc).isoformat()
    resp = client.put(
        f"/api/v1/events/{payload['uuid']}",
        json={"resolved_at": resolved_time},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["resolved_at"] is not None


# ─────────────────────────────────────────────────────────────────
# Tests — Delete
# ─────────────────────────────────────────────────────────────────

def test_soft_delete_event(client, auth_headers, test_project_tmq, test_user, test_user_scope_tmq):
    """Soft-delete sets deleted_at and returns the event."""
    payload = _event_payload(
        project_id=test_project_tmq.id,
        reported_by_user_id=str(test_user.id),
    )
    client.post("/api/v1/events", json=payload, headers=auth_headers)

    del_resp = client.delete(f"/api/v1/events/{payload['uuid']}", headers=auth_headers)
    assert del_resp.status_code == 200
    assert del_resp.json()["deleted_at"] is not None

    # Soft-deleted event should not appear in normal list
    list_resp = client.get(
        f"/api/v1/events?project_id={test_project_tmq.id}",
        headers=auth_headers,
    )
    assert list_resp.json()["total"] == 0


def test_delete_event_not_found(client, auth_headers):
    """Returns 404 when deleting unknown UUID."""
    resp = client.delete(f"/api/v1/events/{uuid4()}", headers=auth_headers)
    assert resp.status_code == 404


def test_delete_event_requires_auth(client, test_project_tmq, test_user):
    """Deleting without token returns 401."""
    resp = client.delete(f"/api/v1/events/{uuid4()}")
    assert resp.status_code == 401
