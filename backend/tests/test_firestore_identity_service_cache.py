from uuid import UUID

from app.services import firestore_identity_service as identity_service


class _FakeSnapshot:
    def __init__(self, payload):
        self._payload = payload
        self.exists = payload is not None

    def to_dict(self):
        return dict(self._payload or {})


class _FakeDocumentReference:
    def __init__(self, docs, doc_id: str):
        self._docs = docs
        self._doc_id = doc_id

    def get(self):
        return _FakeSnapshot(self._docs.get(self._doc_id))

    def set(self, values, merge=False):
        current = dict(self._docs.get(self._doc_id) or {})
        if merge:
            current.update(values)
        else:
            current = dict(values)
        self._docs[self._doc_id] = current

    def delete(self):
        self._docs.pop(self._doc_id, None)


class _FakeCollection:
    def __init__(self, docs):
        self._docs = docs
        self.stream_calls = 0

    def document(self, doc_id: str):
        return _FakeDocumentReference(self._docs, doc_id)

    def stream(self):
        self.stream_calls += 1
        return [_FakeSnapshot(payload) for payload in self._docs.values()]


class _FakeClient:
    def __init__(self, users_docs):
        self.users_collection = _FakeCollection(users_docs)

    def collection(self, name: str):
        if name != "users":
            raise AssertionError(f"Unexpected collection: {name}")
        return self.users_collection


def test_list_firestore_users_uses_cache_and_clears_after_write(monkeypatch):
    users_docs = {
        "11111111-1111-1111-1111-111111111111": {
            "id": "11111111-1111-1111-1111-111111111111",
            "email": "ana@example.com",
            "full_name": "Ana Lopez",
            "status": "active",
            "roles": ["ADMIN"],
            "project_ids": ["TMQ"],
        }
    }
    fake_client = _FakeClient(users_docs)

    monkeypatch.setattr(identity_service, "get_firestore_client", lambda: fake_client)
    identity_service._cached_list_firestore_users.cache_clear()

    first = identity_service.list_firestore_users()
    second = identity_service.list_firestore_users()

    assert [user.full_name for user in first] == ["Ana Lopez"]
    assert [user.full_name for user in second] == ["Ana Lopez"]
    assert fake_client.users_collection.stream_calls == 1

    users_docs["22222222-2222-2222-2222-222222222222"] = {
        "id": "22222222-2222-2222-2222-222222222222",
        "email": "beatriz@example.com",
        "full_name": "Beatriz Ruiz",
        "status": "active",
        "roles": ["OPERATIVO"],
        "project_ids": ["TMQ"],
    }

    identity_service.update_last_login(UUID("11111111-1111-1111-1111-111111111111"))

    refreshed = identity_service.list_firestore_users()
    assert [user.full_name for user in refreshed] == ["Ana Lopez", "Beatriz Ruiz"]
    assert fake_client.users_collection.stream_calls == 2