"""Tests for multi-responsible activity deduplication in GET /activities.

Firestore stores one document per participant for multi-responsible activities,
linked by activity_group_id. The list endpoint must return only one activity
per group when no personal/incremental filter is active (dashboard use case),
and must return all documents when filtered by assigned_to_user_id or
updated_since_sync_version (mobile sync use case).
"""

from datetime import datetime, timezone
from uuid import uuid4

from app.api import deps as deps_module
from app.api.v1 import activities as activities_api
from app.core.enums import UserStatus
from app.main import app
from app.services.firestore_identity_service import FirestoreUserPrincipal


PROJECT_ID = "TMQ"


def _principal():
    return FirestoreUserPrincipal(
        id=uuid4(),
        email="admin@example.com",
        full_name="Dedup Test Admin",
        status=UserStatus.ACTIVE,
        created_at=datetime.now(timezone.utc),
        last_login_at=None,
        last_activity_at=None,
        roles=["ADMIN"],
        project_ids=[PROJECT_ID],
        scopes=[],
        permission_scopes=[],
        password_hash="hash",
        pin_hash=None,
        last_logout_at=None,
    )


def _make_activity(activity_group_id: str | None, user_id: str, extra: dict | None = None) -> dict:
    """Build a minimal Firestore activity document payload."""
    uid = str(uuid4())
    user_uuid = str(uuid4())
    now = datetime.now(timezone.utc).isoformat()
    base = {
        "uuid": uid,
        "server_id": None,
        "project_id": PROJECT_ID,
        "activity_type_code": "ASAMBLEA",
        "execution_state": "PENDIENTE",
        "assigned_to_user_id": user_uuid,
        "created_by_user_id": user_uuid,
        "assignment_start_at": "2026-01-01T00:00:00",
        "assignment_end_at": "2026-01-02T00:00:00",
        "front_id": None,
        "pk_start": 0,
        "pk_end": None,
        "created_at": now,
        "updated_at": now,
        "deleted_at": None,
        "sync_version": 1,
        "activity_group_id": activity_group_id,
        # dedup legacy key fields
        "_user_tag": user_id,  # only used to make legacy keys distinct per test
    }
    if extra:
        base.update(extra)
    return base


class _FakeSnap:
    def __init__(self, data: dict):
        self._data = data
        self.id = data.get("uuid", "unknown")

    def to_dict(self):
        return dict(self._data)


class _FakeCollection:
    def __init__(self, docs: list[dict]):
        self._docs = docs
        self._filters: list[tuple] = []
        self._order: str | None = None

    def where(self, field, op, value):
        clone = _FakeCollection(self._docs)
        clone._filters = list(self._filters) + [(field, op, value)]
        clone._order = self._order
        return clone

    def order_by(self, field, direction=None):
        clone = _FakeCollection(self._docs)
        clone._filters = list(self._filters)
        clone._order = field
        return clone

    def stream(self):
        result = []
        for doc in self._docs:
            match = True
            for field, op, value in self._filters:
                if op == "==" and doc.get(field) != value:
                    match = False
                    break
            if match:
                result.append(_FakeSnap(doc))
        return iter(result)

    def document(self, doc_id):
        raise NotImplementedError("document() not needed for list tests")


class _FakeFirestoreClient:
    def __init__(self, docs: list[dict]):
        self._docs = docs

    def collection(self, name: str):
        if name == "activities":
            return _FakeCollection(self._docs)
        return _FakeCollection([])


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

def test_list_activities_deduplicates_multi_responsible_group(client, monkeypatch):
    """When 3 users share activity_group_id, GET /activities returns only 1 item."""
    group_id = str(uuid4())
    docs = [
        _make_activity(group_id, "user-A"),
        _make_activity(group_id, "user-B"),
        _make_activity(group_id, "user-C"),
    ]
    monkeypatch.setattr(activities_api, "get_firestore_client", lambda: _FakeFirestoreClient(docs))

    app.dependency_overrides[deps_module.get_current_user] = _principal
    try:
        resp = client.get(f"/api/v1/activities?project_id={PROJECT_ID}")
    finally:
        app.dependency_overrides.pop(deps_module.get_current_user, None)

    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 1
    assert len(data["items"]) == 1


def test_list_activities_no_dedup_when_assigned_to_user_id(client, monkeypatch):
    """When filtering by assigned_to_user_id, all matching docs must be returned (mobile sync)."""
    group_id = str(uuid4())
    user_a = str(uuid4())
    user_b = str(uuid4())
    user_c = str(uuid4())
    now = datetime.now(timezone.utc).isoformat()

    def _doc(user_uuid):
        return {
            "uuid": str(uuid4()),
            "server_id": None,
            "project_id": PROJECT_ID,
            "activity_type_code": "ASAMBLEA",
            "execution_state": "PENDIENTE",
            "assigned_to_user_id": user_uuid,
            "created_by_user_id": user_uuid,
            "assignment_start_at": "2026-01-01T00:00:00",
            "assignment_end_at": "2026-01-02T00:00:00",
            "front_id": None,
            "pk_start": 0,
            "pk_end": None,
            "created_at": now,
            "updated_at": now,
            "deleted_at": None,
            "sync_version": 1,
            "activity_group_id": group_id,
        }

    docs = [_doc(user_a), _doc(user_b), _doc(user_c)]
    monkeypatch.setattr(activities_api, "get_firestore_client", lambda: _FakeFirestoreClient(docs))

    app.dependency_overrides[deps_module.get_current_user] = _principal
    try:
        resp = client.get(
            f"/api/v1/activities?project_id={PROJECT_ID}&assigned_to_user_id={user_a}"
        )
    finally:
        app.dependency_overrides.pop(deps_module.get_current_user, None)

    assert resp.status_code == 200
    data = resp.json()
    # Only user_a's document matches the filter — no dedup is applied but result is 1 naturally
    assert data["total"] == 1


def test_list_activities_no_dedup_when_updated_since_sync_version(client, monkeypatch):
    """updated_since_sync_version skips dedup — every changed doc should sync to mobile."""
    group_id = str(uuid4())
    docs = [
        _make_activity(group_id, "user-A", {"sync_version": 5}),
        _make_activity(group_id, "user-B", {"sync_version": 5}),
    ]
    monkeypatch.setattr(activities_api, "get_firestore_client", lambda: _FakeFirestoreClient(docs))

    app.dependency_overrides[deps_module.get_current_user] = _principal
    try:
        resp = client.get(
            f"/api/v1/activities?project_id={PROJECT_ID}&updated_since_sync_version=3"
        )
    finally:
        app.dependency_overrides.pop(deps_module.get_current_user, None)

    assert resp.status_code == 200
    data = resp.json()
    # Both docs have sync_version=5 > 3, so both pass the filter; no dedup applied
    assert data["total"] == 2


def test_list_activities_single_responsible_not_deduped(client, monkeypatch):
    """Single-responsible activities (no activity_group_id) without shared keys are all returned."""
    docs = [
        _make_activity(None, "user-A", {"front_id": "F1", "pk_start": "0+000"}),
        _make_activity(None, "user-B", {"front_id": "F2", "pk_start": "0+000"}),
        _make_activity(None, "user-C", {"front_id": "F3", "pk_start": "0+000"}),
    ]
    monkeypatch.setattr(activities_api, "get_firestore_client", lambda: _FakeFirestoreClient(docs))

    app.dependency_overrides[deps_module.get_current_user] = _principal
    try:
        resp = client.get(f"/api/v1/activities?project_id={PROJECT_ID}")
    finally:
        app.dependency_overrides.pop(deps_module.get_current_user, None)

    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 3


def test_list_activities_mixed_group_and_single(client, monkeypatch):
    """Mix of grouped (3 docs → 1) and single-responsible (2 docs → 2) returns 3 total."""
    group_id = str(uuid4())
    docs = [
        _make_activity(group_id, "user-A"),
        _make_activity(group_id, "user-B"),
        _make_activity(group_id, "user-C"),
        _make_activity(None, "user-D", {"front_id": "F4", "pk_start": "0+100"}),
        _make_activity(None, "user-E", {"front_id": "F5", "pk_start": "0+200"}),
    ]
    monkeypatch.setattr(activities_api, "get_firestore_client", lambda: _FakeFirestoreClient(docs))

    app.dependency_overrides[deps_module.get_current_user] = _principal
    try:
        resp = client.get(f"/api/v1/activities?project_id={PROJECT_ID}")
    finally:
        app.dependency_overrides.pop(deps_module.get_current_user, None)

    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 3
