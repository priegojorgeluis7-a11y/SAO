from datetime import datetime, timezone

from app.api.v1 import catalog as catalog_api
from app.schemas.catalog_bundle import ProjectOpsRequest


class _FakeSnapshotReference:
    def __init__(self, path: str):
        self.id = path.rsplit("/", 1)[-1]


class _FakeDocumentSnapshot:
    def __init__(self, path: str, payload: dict | None):
        self._path = path
        self._payload = payload
        self.reference = _FakeSnapshotReference(path)

    @property
    def exists(self) -> bool:
        return self._payload is not None

    def to_dict(self) -> dict:
        return dict(self._payload or {})


class _FakeDocumentRef:
    def __init__(self, client: "_FakeFirestoreClient", path: str):
        self._client = client
        self._path = path

    def get(self) -> _FakeDocumentSnapshot:
        return _FakeDocumentSnapshot(self._path, self._client._docs.get(self._path))

    def set(self, payload: dict, merge: bool = False) -> None:
        if merge and self._path in self._client._docs:
            next_payload = dict(self._client._docs[self._path])
            next_payload.update(payload)
            self._client._docs[self._path] = next_payload
            return
        self._client._docs[self._path] = dict(payload)

    def collection(self, name: str) -> "_FakeCollectionRef":
        return _FakeCollectionRef(self._client, f"{self._path}/{name}")


class _FakeCollectionRef:
    def __init__(self, client: "_FakeFirestoreClient", path: str):
        self._client = client
        self._path = path

    def document(self, doc_id: str) -> _FakeDocumentRef:
        return _FakeDocumentRef(self._client, f"{self._path}/{doc_id}")


class _FakeFirestoreClient:
    def __init__(self):
        self._docs: dict[str, dict] = {}

    def collection(self, name: str) -> _FakeCollectionRef:
        return _FakeCollectionRef(self, name)


def test_apply_project_ops_updates_current_bundle_version_metadata(monkeypatch):
    fake_client = _FakeFirestoreClient()
    project_id = "TMQ"
    current_version_id = "v2"
    stale_version_id = "v1"
    generated_at = datetime.now(timezone.utc)

    stale_bundle = {
        "schema": "catalog_bundle/v1",
        "meta": {
            "project_id": project_id,
            "version_id": stale_version_id,
            "generated_at": generated_at,
        },
        "effective": {
            "entities": {
                "activities": [
                    {
                        "id": "ACT-1",
                        "name": "Nombre anterior",
                        "active": True,
                        "order": 1,
                    }
                ]
            },
            "relations": {},
        },
    }
    version_bundle = {
        "schema": "catalog_bundle/v1",
        "meta": {
            "project_id": project_id,
            "version_id": current_version_id,
            "generated_at": generated_at,
        },
        "effective": {
            "entities": {
                "activities": [
                    {
                        "id": "ACT-1",
                        "name": "Nombre anterior",
                        "active": True,
                        "order": 1,
                    }
                ]
            },
            "relations": {},
        },
    }

    fake_client.collection("catalog_bundles").document(project_id).set(stale_bundle)
    fake_client.collection("catalog_bundles").document(f"{project_id}:{current_version_id}").set(version_bundle)

    monkeypatch.setattr(catalog_api, "get_firestore_client", lambda: fake_client)
    monkeypatch.setattr(
        catalog_api,
        "_resolve_current_version_id_firestore",
        lambda project_id=None: current_version_id,
    )

    updated_bundle = catalog_api.apply_project_ops(
        project_id=project_id,
        body=ProjectOpsRequest.model_validate(
            {
                "ops": [
                    {
                        "op": "patch",
                        "entity": "activities",
                        "id": "ACT-1",
                        "payload": {"name": "Nombre actualizado"},
                    }
                ]
            }
        ),
        current_user=object(),
    )

    assert updated_bundle["meta"]["version_id"] == current_version_id

    current_bundle = fake_client.collection("catalog_bundles").document(project_id).get().to_dict()
    assert current_bundle["meta"]["version_id"] == current_version_id

    resolved_bundle = catalog_api._resolve_catalog_bundle_firestore(
        project_id=project_id,
        version_id=current_version_id,
        include_editor=True,
    )
    assert resolved_bundle["meta"]["version_id"] == current_version_id
    assert resolved_bundle["effective"]["entities"]["activities"][0]["name"] == "Nombre actualizado"