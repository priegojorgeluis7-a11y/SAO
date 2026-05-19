"""Smoke tests for catalog resolve-catalog endpoint (Firestore-only backend)."""

from datetime import datetime, timezone
from uuid import uuid4

import pytest

from app.api.v1 import activities as activities_api
from app.api.v1.sync import _extract_custom_ids, _wizard_payload_has_custom_ids
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


# ---------------------------------------------------------------------------
# Unit tests for _extract_custom_ids and re-flag prevention logic
# ---------------------------------------------------------------------------


def test_extract_custom_ids_simple_fields():
    payload = {
        "activity": {"id": "CUSTOM_ACT_001", "name": "Custom Act"},
        "subcategory": {"id": "CAM_DDV", "name": "Normal"},
        "result": {"id": "CUSTOM_RES_999", "name": "Custom Res"},
    }
    ids = _extract_custom_ids(payload)
    assert ids == {"CUSTOM_ACT_001", "CUSTOM_RES_999"}


def test_extract_custom_ids_list_fields():
    payload = {
        "topics": [
            {"id": "CUSTOM_TOP_001", "name": "Custom Topic"},
            {"id": "TOP_GALIBOS", "name": "Normal Topic"},
        ],
        "attendees": [
            {"id": "CUSTOM_ATT_001", "name": "Custom Att"},
        ],
    }
    ids = _extract_custom_ids(payload)
    assert ids == {"CUSTOM_TOP_001", "CUSTOM_ATT_001"}


def test_extract_custom_ids_empty():
    assert _extract_custom_ids(None) == set()
    assert _extract_custom_ids({}) == set()
    assert _extract_custom_ids({"activity": {"id": "ACT_NORMAL", "name": "N"}}) == set()


def test_no_reflag_when_same_custom_ids_remain():
    """After admin resolves custom IDs (catalog_changed cleared), a sync with
    the same CUSTOM_* IDs must NOT raise the flag again."""
    existing_payload = {
        "activity": {"id": "CUSTOM_ACT_001", "name": "Custom Act"},
    }
    incoming_payload = {
        "activity": {"id": "CUSTOM_ACT_001", "name": "Custom Act"},
    }
    # Simulate the condition in _firestore_push_item after catalog_changed=False
    existing_catalog_changed = False
    existing_custom_ids = _extract_custom_ids(existing_payload)
    incoming_custom_ids = _extract_custom_ids(incoming_payload)

    should_reflag = (
        not existing_catalog_changed
        and _wizard_payload_has_custom_ids(incoming_payload)
        and bool(incoming_custom_ids - existing_custom_ids)
    )
    assert should_reflag is False, "Should NOT re-flag when same custom IDs are already known"


def test_reflag_when_new_custom_ids_appear():
    """A sync that introduces a NEW custom ID must raise the flag."""
    existing_payload = {
        "activity": {"id": "ACT_NORMAL", "name": "Normal"},
    }
    incoming_payload = {
        "activity": {"id": "ACT_NORMAL", "name": "Normal"},
        "topics": [{"id": "CUSTOM_TOP_NEW", "name": "New Custom Topic"}],
    }
    existing_catalog_changed = False
    existing_custom_ids = _extract_custom_ids(existing_payload)
    incoming_custom_ids = _extract_custom_ids(incoming_payload)

    should_reflag = (
        not existing_catalog_changed
        and _wizard_payload_has_custom_ids(incoming_payload)
        and bool(incoming_custom_ids - existing_custom_ids)
    )
    assert should_reflag is True, "Should flag when genuinely new custom IDs appear"
