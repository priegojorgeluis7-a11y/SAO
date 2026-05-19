"""Tests para la limpieza en cascada al eliminar una actividad."""
from datetime import datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest

from app.api.v1 import activities as activities_api
from app.api.v1 import evidences as evidences_api


# ── Helpers comunes ─────────────────────────────────────────────────────────

class _FakeDoc:
    """Documento Firestore simulado con id, to_dict y reference.delete()."""

    def __init__(self, doc_id: str, payload: dict):
        self.id = doc_id
        self._payload = dict(payload)
        self.deleted = False
        self.reference = self

    def to_dict(self):
        return dict(self._payload)

    def delete(self):
        self.deleted = True


class _FakeRef:
    """Referencia simulada que apoya get(), delete() y colecciones hijas."""

    def __init__(self, doc_id: str, payload: dict | None = None):
        self.id = doc_id
        self._payload = payload
        self.deleted = False
        self._sub: dict[str, "_FakeCollection"] = {}

    @property
    def exists(self):
        return self._payload is not None

    def to_dict(self):
        return dict(self._payload or {})

    def get(self):
        return self

    def delete(self):
        self.deleted = True

    def collection(self, name: str):
        if name not in self._sub:
            self._sub[name] = _FakeCollection({})
        return self._sub[name]


class _FakeCollection:
    def __init__(self, docs: dict):
        # docs: {doc_id: payload_dict}
        self._docs: dict[str, _FakeRef] = {
            k: _FakeRef(k, v) for k, v in docs.items()
        }
        self._where_results: list[_FakeDoc] = []

    def document(self, doc_id: str):
        if doc_id not in self._docs:
            self._docs[doc_id] = _FakeRef(doc_id, None)
        return self._docs[doc_id]

    def where(self, *args, **kwargs):
        return self

    def stream(self):
        return iter(self._where_results)

    def limit(self, n: int):
        return self


class _FakeClient:
    def __init__(self, collections: dict):
        self._collections: dict[str, _FakeCollection] = {
            name: _FakeCollection(docs) for name, docs in collections.items()
        }

    def collection(self, name: str):
        if name not in self._collections:
            self._collections[name] = _FakeCollection({})
        return self._collections[name]


# ── Tests: _delete_activity_cascade ─────────────────────────────────────────

def test_cascade_delete_no_related_docs():
    """Sin assignments ni evidencias → counts en 0."""
    client = _FakeClient({})
    counts = activities_api._delete_activity_cascade(client, str(uuid4()))
    assert counts["assignments"] == 0
    assert counts["evidences"] == 0


def test_cascade_delete_removes_subcollection_assignments():
    """Assignments en sub-colección activity/{uuid}/assignments se borran."""
    activity_id = str(uuid4())
    assign_id = str(uuid4())
    assign_doc = _FakeDoc(assign_id, {"activity_id": activity_id, "user_id": "u1"})

    client = _FakeClient({"activities": {activity_id: {"uuid": activity_id}}})
    # Inyectar el doc en la sub-colección
    sub_col = _FakeCollection({})
    sub_col._where_results = [assign_doc]
    client.collection("activities").document(activity_id)._sub["assignments"] = sub_col

    counts = activities_api._delete_activity_cascade(client, activity_id)

    assert assign_doc.deleted
    assert counts["assignments"] >= 1


def test_cascade_delete_removes_root_assignments():
    """Assignments en colección raíz con activity_id coincidente se borran."""
    activity_id = str(uuid4())
    assign_doc = _FakeDoc(str(uuid4()), {"activity_id": activity_id})

    client = _FakeClient({"activities": {activity_id: {}}})
    client.collection("assignments")._where_results = [assign_doc]

    counts = activities_api._delete_activity_cascade(client, activity_id)

    assert assign_doc.deleted
    assert counts["assignments"] >= 1


def test_cascade_delete_removes_evidences():
    """Evidencias con activity_id coincidente se borran."""
    activity_id = str(uuid4())
    ev_doc = _FakeDoc(str(uuid4()), {
        "activity_id": activity_id,
        "object_path": "activities/x/ev.jpg",
    })

    client = _FakeClient({"activities": {activity_id: {}}})
    client.collection("evidences")._where_results = [ev_doc]

    counts = activities_api._delete_activity_cascade(client, activity_id)

    assert ev_doc.deleted
    assert counts["evidences"] == 1


def test_cascade_delete_local_storage_cleanup(tmp_path, monkeypatch):
    """En modo local, el archivo físico de la evidencia se elimina."""
    activity_id = str(uuid4())
    object_path = "activities/x/evidence.jpg"
    fake_file = tmp_path / object_path
    fake_file.parent.mkdir(parents=True)
    fake_file.write_bytes(b"data")

    ev_doc = _FakeDoc(str(uuid4()), {
        "activity_id": activity_id,
        "object_path": object_path,
    })
    client = _FakeClient({"activities": {activity_id: {}}})
    client.collection("evidences")._where_results = [ev_doc]

    monkeypatch.setattr(activities_api.settings, "EVIDENCE_STORAGE_BACKEND", "local")
    monkeypatch.setattr(activities_api.settings, "LOCAL_UPLOADS_DIR", str(tmp_path))

    counts = activities_api._delete_activity_cascade(client, activity_id)

    assert not fake_file.exists(), "El archivo debe haberse borrado"
    assert counts.get("storage_files", 0) == 1


def test_cascade_delete_storage_error_does_not_abort(tmp_path, monkeypatch):
    """Un error al borrar el archivo no debe abortar la limpieza del documento."""
    activity_id = str(uuid4())
    ev_doc = _FakeDoc(str(uuid4()), {
        "activity_id": activity_id,
        "object_path": "activities/x/evidence.jpg",
    })
    client = _FakeClient({"activities": {activity_id: {}}})
    client.collection("evidences")._where_results = [ev_doc]

    monkeypatch.setattr(activities_api.settings, "EVIDENCE_STORAGE_BACKEND", "local")
    monkeypatch.setattr(activities_api.settings, "LOCAL_UPLOADS_DIR", "/nonexistent_dir_xyz")

    # No debe lanzar excepción
    counts = activities_api._delete_activity_cascade(client, activity_id)
    assert ev_doc.deleted
    assert counts["evidences"] == 1


# ── Tests: DELETE /evidences/{id} ───────────────────────────────────────────

def _make_user(roles: list[str], user_id: str = "user-1"):
    return SimpleNamespace(
        id=user_id,
        roles=roles,
        project_ids=["TMQ"],
        permission_scopes=[],
    )


def test_delete_evidence_owner_can_delete(monkeypatch, tmp_path):
    """El dueño (created_by) puede eliminar su propia evidencia."""
    ev_id = str(uuid4())
    object_path = "activities/x/ev.jpg"
    fake_file = tmp_path / object_path
    fake_file.parent.mkdir(parents=True)
    fake_file.write_bytes(b"data")

    ev_payload = {
        "id": ev_id,
        "activity_id": str(uuid4()),
        "project_id": "TMQ",
        "object_path": object_path,
        "mime_type": "image/jpeg",
        "created_by": "owner-user",
    }
    deleted_ids: list[str] = []

    class _FakeEvRef:
        @property
        def id(self):
            return ev_id

        exists = True

        def to_dict(self):
            return ev_payload

        def get(self):
            return self

        def delete(self):
            deleted_ids.append(ev_id)

    class _FakeEvCol:
        def document(self, doc_id):
            return _FakeEvRef()

        def where(self, *a, **kw):
            return self

        def limit(self, n):
            return self

        def stream(self):
            return iter([])

    class _FakeEvClient:
        def collection(self, name):
            return _FakeEvCol()

    monkeypatch.setattr(evidences_api, "get_firestore_client", lambda: _FakeEvClient())
    monkeypatch.setattr(evidences_api, "verify_project_access", lambda *a, **kw: None)
    monkeypatch.setattr(evidences_api, "user_has_permission", lambda *a, **kw: True)
    monkeypatch.setattr(evidences_api, "write_firestore_audit_log", lambda **kw: None)
    monkeypatch.setattr(evidences_api.settings, "EVIDENCE_STORAGE_BACKEND", "local")
    monkeypatch.setattr(evidences_api.settings, "LOCAL_UPLOADS_DIR", str(tmp_path))

    user = _make_user(["OPERATIVO"], user_id="owner-user")
    # No debe lanzar excepción → 204 implícito
    evidences_api.delete_evidence(ev_id, current_user=user)
    assert ev_id in deleted_ids


def test_delete_evidence_non_owner_non_admin_raises_403(monkeypatch):
    """Un usuario que no es dueño ni ADMIN recibe 403."""
    import pytest
    from fastapi import HTTPException

    ev_id = str(uuid4())
    ev_payload = {
        "id": ev_id,
        "activity_id": str(uuid4()),
        "project_id": "TMQ",
        "object_path": "activities/x/ev.jpg",
        "mime_type": "image/jpeg",
        "created_by": "other-user",
    }

    class _FakeEvRef:
        @property
        def id(self):
            return ev_id

        exists = True

        def to_dict(self):
            return ev_payload

        def get(self):
            return self

        def delete(self):
            pass

    class _FakeCol:
        def document(self, _):
            return _FakeEvRef()

        def where(self, *a, **kw):
            return self

        def limit(self, n):
            return self

        def stream(self):
            return iter([])

    monkeypatch.setattr(evidences_api, "get_firestore_client", lambda: SimpleNamespace(collection=lambda _: _FakeCol()))
    monkeypatch.setattr(evidences_api, "verify_project_access", lambda *a, **kw: None)
    monkeypatch.setattr(evidences_api, "user_has_permission", lambda *a, **kw: True)

    user = _make_user(["OPERATIVO"], user_id="different-user")
    with pytest.raises(HTTPException) as exc_info:
        evidences_api.delete_evidence(ev_id, current_user=user)
    assert exc_info.value.status_code == 403


def test_delete_evidence_admin_can_delete_any(monkeypatch, tmp_path):
    """ADMIN puede eliminar evidencias ajenas."""
    ev_id = str(uuid4())
    ev_payload = {
        "id": ev_id,
        "activity_id": str(uuid4()),
        "project_id": "TMQ",
        "object_path": "",
        "mime_type": "image/jpeg",
        "created_by": "other-user",
    }
    deleted_ids: list[str] = []

    class _FakeEvRef:
        @property
        def id(self):
            return ev_id

        exists = True

        def to_dict(self):
            return ev_payload

        def get(self):
            return self

        def delete(self):
            deleted_ids.append(ev_id)

    class _FakeCol:
        def document(self, _):
            return _FakeEvRef()

        def where(self, *a, **kw):
            return self

        def limit(self, n):
            return self

        def stream(self):
            return iter([])

    monkeypatch.setattr(evidences_api, "get_firestore_client", lambda: SimpleNamespace(collection=lambda _: _FakeCol()))
    monkeypatch.setattr(evidences_api, "verify_project_access", lambda *a, **kw: None)
    monkeypatch.setattr(evidences_api, "user_has_permission", lambda *a, **kw: True)
    monkeypatch.setattr(evidences_api, "write_firestore_audit_log", lambda **kw: None)
    monkeypatch.setattr(evidences_api.settings, "EVIDENCE_STORAGE_BACKEND", "local")
    monkeypatch.setattr(evidences_api.settings, "LOCAL_UPLOADS_DIR", str(tmp_path))

    user = _make_user(["ADMIN"], user_id="admin-user")
    evidences_api.delete_evidence(ev_id, current_user=user)
    assert ev_id in deleted_ids
