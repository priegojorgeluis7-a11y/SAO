from app.api.v1 import catalog as catalog_api


class _FakeSnapshot:
    def __init__(self, payload):
        self._payload = payload
        self.exists = payload is not None
        self.id = str((payload or {}).get("version_id") or (payload or {}).get("project_id") or "")

    def to_dict(self):
        return dict(self._payload or {})


class _FakeDocumentRef:
    def __init__(self, docs, doc_id: str):
        self._docs = docs
        self._doc_id = doc_id
        self.get_calls = 0

    def get(self):
        self.get_calls += 1
        return _FakeSnapshot(self._docs.get(self._doc_id))

    def set(self, values, merge=False):
        current = dict(self._docs.get(self._doc_id) or {})
        if merge:
            current.update(values)
        else:
            current = dict(values)
        self._docs[self._doc_id] = current


class _FakeQuery:
    def __init__(self, collection):
        self._collection = collection
        self._filters = []
        self._limit = None

    def where(self, field, op, value):
        self._filters.append((field, op, value))
        return self

    def limit(self, value):
        self._limit = value
        return self

    def order_by(self, *args, **kwargs):
        return self

    def stream(self):
        self._collection.stream_calls += 1
        rows = []
        for doc_id, payload in self._collection._docs.items():
            if self._collection._path == "catalog_versions":
                if not str(doc_id).startswith(self._collection._path + "/"):
                    continue
                suffix = str(doc_id).split("/", 1)[-1]
            else:
                suffix = doc_id
            match = True
            for field, op, expected in self._filters:
                if op == "==" and payload.get(field) != expected:
                    match = False
                    break
            if match:
                rows.append(_FakeSnapshot(payload))
        if self._limit is not None:
            rows = rows[: self._limit]
        return iter(rows)


class _FakeCollection:
    def __init__(self, docs, path: str):
        self._docs = docs
        self._path = path
        self.stream_calls = 0
        self._doc_refs = {}

    def document(self, doc_id: str):
        key = f"{self._path}/{doc_id}"
        if key not in self._docs:
            self._docs[key] = None
        if key not in self._doc_refs:
            self._doc_refs[key] = _FakeDocumentRef(self._docs, key)
        return self._doc_refs[key]

    def where(self, field, op, value):
        return _FakeQuery(self).where(field, op, value)

    def limit(self, value):
        return _FakeQuery(self).limit(value)

    def order_by(self, *args, **kwargs):
        return _FakeQuery(self).order_by(*args, **kwargs)

    def stream(self):
        self.stream_calls += 1
        rows = []
        for key, payload in self._docs.items():
            if not key.startswith(self._path + "/"):
                continue
            if payload is None:
                continue
            doc_id = key.split("/", 1)[-1] if "/" in key else key
            rows.append(_FakeSnapshot(payload))
        return iter(rows)


class _FakeClient:
    def __init__(self):
        self._docs = {
            "catalog_current/TMQ": {
                "project_id": "TMQ",
                "version_id": "tmq-v1",
                "version_number": "tmq-v1",
                "published_at": "2026-05-29T00:00:00+00:00",
                "is_current": True,
                "hash": "hash-1",
            },
            "catalog_versions/tmq-v1": {
                "project_id": "TMQ",
                "version_id": "tmq-v1",
                "version_number": "tmq-v1",
                "status": "published",
                "published_at": "2026-05-29T00:00:00+00:00",
                "created_at": "2026-05-29T00:00:00+00:00",
                "updated_at": "2026-05-29T00:00:00+00:00",
                "is_current": True,
                "hash": "hash-1",
            },
        }
        self.current_collection = _FakeCollection(self._docs, "catalog_current")
        self.versions_collection = _FakeCollection(self._docs, "catalog_versions")

    def collection(self, name: str):
        if name == "catalog_current":
            return self.current_collection
        if name == "catalog_versions":
            return self.versions_collection
        raise AssertionError(f"Unexpected collection: {name}")


def test_catalog_read_cache_reuses_reads_and_can_be_cleared(monkeypatch):
    fake_client = _FakeClient()
    monkeypatch.setattr(catalog_api, "get_firestore_client", lambda: fake_client)
    catalog_api._clear_catalog_read_cache()

    first_version = catalog_api._resolve_current_version_id_firestore("TMQ")
    second_version = catalog_api._resolve_current_version_id_firestore("TMQ")
    first_versions = catalog_api._catalog_versions_firestore("TMQ", None, 20)
    second_versions = catalog_api._catalog_versions_firestore("TMQ", None, 20)

    assert first_version == "tmq-v1"
    assert second_version == "tmq-v1"
    assert len(first_versions) == 1
    assert len(second_versions) == 1
    assert fake_client.current_collection.document("TMQ").get_calls == 1
    assert fake_client.current_collection.stream_calls == 0
    assert fake_client.versions_collection.stream_calls == 3

    fake_client._docs["catalog_current/TMQ"]["version_id"] = "tmq-v2"
    fake_client._docs["catalog_versions/tmq-v2"] = {
        "project_id": "TMQ",
        "version_id": "tmq-v2",
        "version_number": "tmq-v2",
        "status": "published",
        "published_at": "2026-05-29T01:00:00+00:00",
        "created_at": "2026-05-29T01:00:00+00:00",
        "updated_at": "2026-05-29T01:00:00+00:00",
        "is_current": True,
        "hash": "hash-2",
    }

    catalog_api._clear_catalog_read_cache()

    catalog_api._resolve_current_version_id_firestore("TMQ")
    refreshed_versions = catalog_api._catalog_versions_firestore("TMQ", None, 20)

    assert any(item.version_number == "tmq-v2" for item in refreshed_versions)
    assert fake_client.current_collection.document("TMQ").get_calls == 2
    assert fake_client.versions_collection.stream_calls == 6