"""Smoke tests for catalog resolve-catalog endpoint (Firestore-only backend)."""

from datetime import datetime, timezone
from uuid import uuid4

import pytest

from app.api.v1 import activities as activities_api
from app.core.config import settings


# ---------------------------------------------------------------------------
# Fake Firestore helpers (reuse same pattern as test_firestore_e2e_flow.py)
# ---------------------------------------------------------------------------


class _FakeDocumentSnapshot:
    def __init__(self, doc_id: str, payload: dict | None, reference=None):
        self.id = doc_id
        self._payload = payload
        self.reference = reference or _FakeDocumentRef.__new__(_FakeDocumentRef)

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

    def collection(self, name: str) -> "_FakeCollectionRef":
        return _FakeCollectionRef(self._client, f"{self._path}/{name}")


class _FakeQuery:
    def __init__(self, collection: "_FakeCollectionRef"):
        self._collection = collection
        self._filters: list[tuple[str, str, object]] = []
        self._limit_val: int | None = None

    def where(self, field: str, op: str, value: object) -> "_FakeQuery":
        self._filters.append((field, op, value))
        return self

    def limit(self, value: int) -> "_FakeQuery":
        self._limit_val = value
        return self

    def stream(self):
        results = []
        for snap in self._collection.stream():
            payload = snap.to_dict()
            match = True
            for field, op, expected in self._filters:
                if op == "==" and payload.get(field) != expected:
                    match = False
                    break
            if match:
                results.append(snap)
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

    def stream(self):
        prefix = f"{self._path}/"
        for full_path, payload in self._client._docs.items():
            if not full_path.startswith(prefix):
                continue
            suffix = full_path[len(prefix):]
            if "/" in suffix:
                continue
            doc_ref = _FakeDocumentRef(self._client, full_path)
            yield _FakeDocumentSnapshot(suffix, payload, reference=doc_ref)


class _FakeFirestoreClient:
    def __init__(self):
        self._docs: dict[str, dict] = {}

    def collection(self, name: str) -> _FakeCollectionRef:
        return _FakeCollectionRef(self, name)


@pytest.fixture
def force_firestore_backend(monkeypatch):
    monkeypatch.setattr(settings, "DATA_BACKEND", "firestore", raising=False)


# ---------------------------------------------------------------------------
# Smoke tests
# ---------------------------------------------------------------------------


def test_firestore_resolve_catalog_by_doc_id(monkeypatch, force_firestore_backend):
    """resolve-catalog updates wizard_payload when doc is found by document ID."""
    fake_client = _FakeFirestoreClient()
    activity_uuid = str(uuid4())
    fake_client._docs[f"activities/{activity_uuid}"] = {
        "uuid": activity_uuid,
        "project_id": "PROJ1",
        "activity_type_code": "CAM",
        "wizard_payload": {
            "subcategory": {"id": "CUSTOM_SUB_001", "name": "Custom sub"},
        },
        "sync_version": 1,
        "updated_at": datetime.now(timezone.utc),
    }

    monkeypatch.setattr(activities_api, "get_firestore_client", lambda: fake_client)

    doc_ref, snap, existing = activities_api._resolve_activity_doc_ref_and_snap(
        fake_client, activity_uuid
    )

    assert doc_ref is not None, "Should find document by ID"
    assert existing["uuid"] == activity_uuid
    assert existing["wizard_payload"]["subcategory"]["id"] == "CUSTOM_SUB_001"


def test_firestore_resolve_catalog_uuid_field_fallback(monkeypatch, force_firestore_backend):
    """resolve-catalog finds activity via uuid field when doc ID differs (mobile upload pattern)."""
    fake_client = _FakeFirestoreClient()
    activity_uuid = str(uuid4())
    mobile_doc_id = f"mobile-{uuid4()}"  # document ID is NOT the uuid
    fake_client._docs[f"activities/{mobile_doc_id}"] = {
        "uuid": activity_uuid,
        "project_id": "PROJ1",
        "activity_type_code": "CAM",
        "wizard_payload": {
            "subcategory": {"id": "CUSTOM_SUB_mobile", "name": "Mobile sub"},
        },
        "sync_version": 0,
        "updated_at": datetime.now(timezone.utc),
    }

    monkeypatch.setattr(activities_api, "get_firestore_client", lambda: fake_client)

    # Looking up by uuid should fail by doc ID, then fall back to uuid field
    doc_ref, snap, existing = activities_api._resolve_activity_doc_ref_and_snap(
        fake_client, activity_uuid
    )

    assert doc_ref is not None, "Should find document via uuid field fallback"
    assert existing["uuid"] == activity_uuid
    assert existing["wizard_payload"]["subcategory"]["id"] == "CUSTOM_SUB_mobile"


def test_firestore_resolve_catalog_not_found(monkeypatch, force_firestore_backend):
    """resolve-catalog returns (None, None, None) when activity does not exist."""
    fake_client = _FakeFirestoreClient()

    monkeypatch.setattr(activities_api, "get_firestore_client", lambda: fake_client)

    doc_ref, snap, existing = activities_api._resolve_activity_doc_ref_and_snap(
        fake_client, str(uuid4())
    )

    assert doc_ref is None
    assert snap is None
    assert existing is None
