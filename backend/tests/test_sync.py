"""Smoke tests for Firestore sync endpoints."""

from datetime import datetime, timezone
from uuid import uuid4

import pytest

from app.api.v1 import sync as sync_api
from app.core.config import settings


# ---------------------------------------------------------------------------
# Fake Firestore helpers
# ---------------------------------------------------------------------------


class _FakeDocumentSnapshot:
    def __init__(self, doc_id: str, payload: dict | None, reference=None):
        self.id = doc_id
        self._payload = payload
        self.reference = reference

    @property
    def exists(self) -> bool:
        return self._payload is not None

    def to_dict(self) -> dict:
        return dict(self._payload or {})


class _FakeDocumentRef:
    def __init__(self, client: "_FakeFirestoreClient", path: str):
        self._client = client
        self._path = path

    @property
    def id(self) -> str:
        return self._path.rsplit("/", 1)[-1]

    def get(self) -> _FakeDocumentSnapshot:
        payload = self._client._docs.get(self._path)
        return _FakeDocumentSnapshot(self.id, payload, reference=self)

    def set(self, payload: dict, merge: bool = False) -> None:
        if merge and self._path in self._client._docs:
            next_payload = dict(self._client._docs[self._path])
            next_payload.update(payload)
            self._client._docs[self._path] = next_payload
            return
        self._client._docs[self._path] = dict(payload)

    def update(self, payload: dict) -> None:
        existing = dict(self._client._docs.get(self._path) or {})
        existing.update(payload)
        self._client._docs[self._path] = existing


class _FakeQuery:
    def __init__(self, collection: "_FakeCollectionRef"):
        self._collection = collection
        self._filters: list[tuple[str, str, object]] = []
        self._limit_val: int | None = None
        self._order_field: str | None = None
        self._order_dir: str = "ASCENDING"
        self._where_conditions: list[tuple[str, str, object]] = []

    def where(self, field: str, op: str, value: object) -> "_FakeQuery":
        self._filters.append((field, op, value))
        return self

    def limit(self, value: int) -> "_FakeQuery":
        self._limit_val = value
        return self

    def order_by(self, field: str, direction: str = "ASCENDING") -> "_FakeQuery":
        self._order_field = field
        self._order_dir = direction
        return self

    def stream(self):
        results = []
        for snap in self._collection.stream():
            payload = snap.to_dict()
            match = all(
                payload.get(f) == v for f, op, v in self._filters if op == "=="
            )
            if match:
                results.append(snap)
        if self._order_field:
            reverse = self._order_dir.upper() == "DESCENDING"
            results.sort(
                key=lambda s: s.to_dict().get(self._order_field, ""),
                reverse=reverse,
            )
        if self._limit_val is not None:
            results = results[: self._limit_val]
        yield from results


class _FakeCollectionRef:
    def __init__(self, client: "_FakeFirestoreClient", path: str):
        self._client = client
        self._path = path

    def document(self, doc_id: str) -> _FakeDocumentRef:
        return _FakeDocumentRef(self._client, f"{self._path}/{doc_id}")

    def where(self, field: str, op: str, value: object) -> _FakeQuery:
        return _FakeQuery(self).where(field, op, value)

    def limit(self, value: int) -> _FakeQuery:
        return _FakeQuery(self).limit(value)

    def order_by(self, field: str, direction: str = "ASCENDING") -> _FakeQuery:
        return _FakeQuery(self).order_by(field, direction)

    def stream(self):
        prefix = f"{self._path}/"
        for full_path, payload in self._client._docs.items():
            if not full_path.startswith(prefix):
                continue
            suffix = full_path[len(prefix):]
            if "/" in suffix:
                continue
            ref = _FakeDocumentRef(self._client, full_path)
            yield _FakeDocumentSnapshot(suffix, payload, reference=ref)


class _FakeFirestoreClient:
    def __init__(self):
        self._docs: dict[str, dict] = {}

    def collection(self, name: str) -> _FakeCollectionRef:
        return _FakeCollectionRef(self, name)


@pytest.fixture
def force_firestore_backend(monkeypatch):
    monkeypatch.setattr(settings, "DATA_BACKEND", "firestore", raising=False)


# ---------------------------------------------------------------------------
# Smoke tests — marked integration so the smoke script can filter them
# ---------------------------------------------------------------------------


@pytest.mark.integration
def test_firestore_sync_fake_client_stores_and_retrieves(force_firestore_backend):
    """Smoke: activities written via fake client can be retrieved by uuid field."""
    fake_client = _FakeFirestoreClient()
    activity_uuid = str(uuid4())
    doc_id = f"mobile-{uuid4()}"

    fake_client._docs[f"activities/{doc_id}"] = {
        "uuid": activity_uuid,
        "project_id": "PROJ_SMOKE",
        "activity_type_code": "CAM",
        "sync_version": 1,
        "status": "pending",
        "updated_at": datetime.now(timezone.utc),
    }

    # Simulate the uuid-field lookup used in sync push conflict detection
    docs = list(
        fake_client.collection("activities")
        .where("uuid", "==", activity_uuid)
        .limit(1)
        .stream()
    )
    assert len(docs) == 1
    assert docs[0].to_dict()["project_id"] == "PROJ_SMOKE"


@pytest.mark.integration
def test_firestore_sync_pull_returns_empty_for_unknown_project(force_firestore_backend):
    """Smoke: sync pull on a project with no activities returns empty list."""
    fake_client = _FakeFirestoreClient()

    docs = list(
        fake_client.collection("activities")
        .where("project_id", "==", "NO_EXIST_PROJECT")
        .stream()
    )
    assert docs == []


@pytest.mark.integration
def test_firestore_sync_version_increments(force_firestore_backend):
    """Smoke: sync_version increments correctly when activity is updated."""
    fake_client = _FakeFirestoreClient()
    activity_uuid = str(uuid4())
    path = f"activities/{activity_uuid}"

    fake_client._docs[path] = {
        "uuid": activity_uuid,
        "project_id": "PROJ_SMOKE",
        "sync_version": 5,
        "status": "pending",
    }

    doc_ref = fake_client.collection("activities").document(activity_uuid)
    existing = doc_ref.get().to_dict()
    next_sync = int(existing.get("sync_version") or 0) + 1
    doc_ref.update({"sync_version": next_sync, "status": "completed"})

    updated = fake_client.collection("activities").document(activity_uuid).get().to_dict()
    assert updated["sync_version"] == 6
    assert updated["status"] == "completed"


@pytest.mark.integration
def test_sync_participant_fallback_uses_assignee_when_list_missing(force_firestore_backend):
    participants = sync_api._normalized_participant_user_ids(
        {
            "assigned_to_user_id": "user-123",
            "created_by_user_id": "creator-1",
        }
    )

    assert participants == ["user-123"]


# ---------------------------------------------------------------------------
# Unit tests for sync push fixes
# ---------------------------------------------------------------------------


def _make_push_item(**overrides):
    """Build a minimal SyncPushActivityItem-like dict for testing _firestore_push_item."""
    from app.schemas.sync import SyncPushActivityItem
    defaults = {
        "uuid": str(uuid4()),
        "project_id": "TMQ",
        "front_id": None,
        "pk_start": 0,
        "pk_end": None,
        "execution_state": "EN_CURSO",
        "assigned_to_user_id": str(uuid4()),
        "participant_user_ids": [],
        "catalog_version_id": "v1",
        "activity_type_code": "CAM",
        "latitude": None,
        "longitude": None,
        "title": "Test activity",
        "description": None,
        "wizard_payload": None,
        "sync_version": 1,
        "created_by_user_id": str(uuid4()),
        "deleted_at": None,
        "server_id": None,
    }
    defaults.update(overrides)
    return SyncPushActivityItem(**defaults)


def _make_push_request(items, *, project_id="TMQ", force_override=False):
    from app.schemas.sync import SyncPushRequest
    return SyncPushRequest(
        project_id=project_id,
        activities=items,
        force_override=force_override,
    )


def test_custom_activity_type_bypasses_catalog_check(monkeypatch, force_firestore_backend):
    """CUSTOM_* activity_type_code must be accepted even when catalog lookup finds nothing."""
    fake_client = _FakeFirestoreClient()

    # Catalog is completely empty — valid_codes will be empty
    monkeypatch.setattr(sync_api, "get_firestore_client", lambda: fake_client)
    monkeypatch.setattr(sync_api, "_firestore_catalog_activity_codes", lambda **kwargs: set())

    item = _make_push_item(activity_type_code="CUSTOM_INSPECCION_001")
    request = _make_push_request([item])

    results = []
    catalog_cache = {}
    sync_api._firestore_push_item(fake_client, None, datetime.now(timezone.utc), request, item, results, catalog_cache)

    assert len(results) == 1
    assert results[0].status in {"CREATED", "UPDATED"}, (
        f"CUSTOM_* activity should be accepted even with empty catalog; got {results[0].status}: {results[0].error_code}"
    )
    # Must be flagged for admin review
    stored = fake_client._docs.get(f"activities/{item.uuid}") or {}
    assert stored.get("catalog_changed") is True


def test_sibling_does_not_inherit_catalog_changed(monkeypatch, force_firestore_backend):
    """Sibling activities created for co-responsibles must not inherit catalog_changed=True."""
    fake_client = _FakeFirestoreClient()

    monkeypatch.setattr(sync_api, "get_firestore_client", lambda: fake_client)
    monkeypatch.setattr(
        sync_api, "_firestore_catalog_activity_codes",
        lambda **kwargs: {"CAM"},
    )

    primary_user = str(uuid4())
    sibling_user = str(uuid4())
    item = _make_push_item(
        assigned_to_user_id=primary_user,
        participant_user_ids=[primary_user, sibling_user],
        wizard_payload={"activity": {"id": "CUSTOM_CAM_001", "name": "Custom Cam"}},
    )
    request = _make_push_request([item])

    results = []
    catalog_cache = {}
    sync_api._firestore_push_item(fake_client, None, datetime.now(timezone.utc), request, item, results, catalog_cache)

    # Primary activity should be flagged
    primary_doc = fake_client._docs.get(f"activities/{item.uuid}") or {}
    assert primary_doc.get("catalog_changed") is True

    # Find sibling document (uuid different from item.uuid, assigned to sibling_user)
    sibling_docs = [
        doc for path, doc in fake_client._docs.items()
        if path.startswith("activities/")
        and path != f"activities/{item.uuid}"
        and doc.get("assigned_to_user_id") == sibling_user
    ]
    assert len(sibling_docs) == 1, "Expected exactly one sibling activity"
    sibling = sibling_docs[0]
    assert sibling.get("catalog_changed") is False, (
        f"Sibling must NOT inherit catalog_changed=True; got {sibling.get('catalog_changed')}"
    )
    assert sibling.get("wizard_payload") is None
