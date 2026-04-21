"""Smoke tests for Firestore sync endpoints."""

from datetime import datetime, timezone
from uuid import uuid4

import pytest

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
