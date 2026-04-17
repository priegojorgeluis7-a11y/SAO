"""Firestore-only integrated E2E regression test for auth + catalog + sync."""

from datetime import datetime, timezone
from uuid import uuid4

import pytest

from app.api import deps as deps_api
from app.api.v1 import auth as auth_api
from app.api.v1 import catalog as catalog_api
from app.api.v1 import completed_activities as completed_activities_api
from app.api.v1 import review as review_api
from app.api.v1 import sync as sync_api
from app.core.config import settings
from app.core.security import get_password_hash
from app.core.enums import UserStatus
from app.services.firestore_identity_service import FirestoreUserPrincipal


class _FakeDocumentSnapshot:
    def __init__(self, doc_id: str, payload: dict | None):
        self.id = doc_id
        self._payload = payload

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
        return _FakeDocumentSnapshot(self.id, self._client._docs.get(self._path))

    def set(self, payload: dict, merge: bool = False) -> None:
        if merge and self._path in self._client._docs:
            next_payload = dict(self._client._docs[self._path])
            next_payload.update(payload)
            self._client._docs[self._path] = next_payload
            return
        self._client._docs[self._path] = dict(payload)

    def collection(self, name: str) -> "_FakeCollectionRef":
        return _FakeCollectionRef(self._client, f"{self._path}/{name}")


class _FakeQuery:
    def __init__(self, collection: "_FakeCollectionRef"):
        self._collection = collection
        self._filters: list[tuple[str, str, object]] = []
        self._limit: int | None = None
        self._order_by: tuple[str, str] | None = None

    def where(self, field: str, op: str, value: object) -> "_FakeQuery":
        self._filters.append((field, op, value))
        return self

    def limit(self, value: int) -> "_FakeQuery":
        self._limit = value
        return self

    def order_by(self, field: str, direction: str = "ASCENDING") -> "_FakeQuery":
        self._order_by = (field, direction)
        return self

    def stream(self):
        docs = [snap for snap in self._collection.stream()]

        def _matches(snapshot: _FakeDocumentSnapshot) -> bool:
            payload = snapshot.to_dict()
            for field, op, expected in self._filters:
                if op != "==":
                    continue
                if payload.get(field) != expected:
                    return False
            return True

        rows = [snap for snap in docs if _matches(snap)]
        if self._order_by is not None:
            field, direction = self._order_by
            rows.sort(key=lambda s: s.to_dict().get(field))
            if str(direction).upper() == "DESCENDING":
                rows.reverse()

        if self._limit is not None:
            rows = rows[: self._limit]

        for row in rows:
            yield row


class _FakeCollectionRef:
    def __init__(self, client: "_FakeFirestoreClient", path: str):
        self._client = client
        self._path = path

    def document(self, doc_id: str) -> _FakeDocumentRef:
        return _FakeDocumentRef(self._client, f"{self._path}/{doc_id}")

    def where(self, field: str, op: str, value: object) -> _FakeQuery:
        query = _FakeQuery(self)
        return query.where(field, op, value)

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
            yield _FakeDocumentSnapshot(suffix, payload)


class _FakeFirestoreClient:
    def __init__(self):
        self._docs: dict[str, dict] = {}

    def collection(self, name: str) -> _FakeCollectionRef:
        return _FakeCollectionRef(self, name)


@pytest.fixture(scope="function")
def force_firestore_backend(monkeypatch):
    monkeypatch.setattr(settings, "DATA_BACKEND", "firestore", raising=False)


def test_firestore_e2e_auth_catalog_sync_flow(client, monkeypatch, force_firestore_backend):
    fake_client = _FakeFirestoreClient()

    user_id = uuid4()
    project_id = "TMQ"
    catalog_version_id = str(uuid4())

    # Seed minimum catalog docs required by /catalog/version/current and /sync/push validation.
    fake_client.collection("catalog_current").document(project_id).set(
        {
            "project_id": project_id,
            "version_id": catalog_version_id,
            "is_current": True,
        }
    )
    fake_client.collection("catalog_effective").document(f"{project_id}:{catalog_version_id}").set(
        {
            "project_id": project_id,
            "version_id": catalog_version_id,
            "activities": [{"id": "INSP_CIVIL"}],
        }
    )

    principal = FirestoreUserPrincipal(
        id=user_id,
        email="firestore-e2e@example.com",
        full_name="Firestore E2E",
        status=UserStatus.ACTIVE,
        created_at=datetime.now(timezone.utc),
        last_login_at=None,
        roles=["OPERATIVO"],
        project_ids=[project_id],
        permission_scopes=[
            {
                "permission_code": "catalog.view",
                "project_id": project_id,
                "effect": "allow",
            }
        ],
        password_hash=get_password_hash("testpass123"),
        pin_hash=None,
    )

    monkeypatch.setattr(
        auth_api,
        "get_firestore_user_by_email",
        lambda email: principal if email == principal.email else None,
    )
    monkeypatch.setattr(
        deps_api,
        "get_firestore_user_by_id",
        lambda principal_id: principal if str(principal_id) == str(principal.id) else None,
    )
    monkeypatch.setattr(auth_api, "update_last_login", lambda _user_id: None)

    monkeypatch.setattr(catalog_api, "get_firestore_client", lambda: fake_client)
    monkeypatch.setattr(sync_api, "get_firestore_client", lambda: fake_client)

    login_response = client.post(
        "/api/v1/auth/login",
        json={"email": principal.email, "password": "testpass123"},
    )
    assert login_response.status_code == 200
    access_token = login_response.json()["access_token"]
    headers = {"Authorization": f"Bearer {access_token}"}

    me_response = client.get("/api/v1/auth/me", headers=headers)
    assert me_response.status_code == 200
    assert me_response.json()["email"] == principal.email

    version_response = client.get(
        "/api/v1/catalog/version/current",
        params={"project_id": project_id},
        headers=headers,
    )
    assert version_response.status_code == 200
    assert version_response.json()["version_id"] == catalog_version_id

    activity_uuid = str(uuid4())
    push_response = client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={
            "project_id": project_id,
            "activities": [
                {
                    "uuid": activity_uuid,
                    "project_id": project_id,
                    "front_id": None,
                    "pk_start": 100,
                    "pk_end": 120,
                    "execution_state": "PENDIENTE",
                    "assigned_to_user_id": None,
                    "created_by_user_id": str(principal.id),
                    "catalog_version_id": catalog_version_id,
                    "activity_type_code": "INSP_CIVIL",
                    "title": "Firestore integrated flow",
                    "description": "auth + catalog + sync",
                    "latitude": None,
                    "longitude": None,
                    "deleted_at": None,
                }
            ],
        },
    )
    assert push_response.status_code == 200
    push_payload = push_response.json()
    assert push_payload["results"][0]["status"] == "CREATED"
    assert push_payload["results"][0]["uuid"] == activity_uuid

    pull_response = client.post(
        "/api/v1/sync/pull",
        headers=headers,
        json={"project_id": project_id, "since_version": 0, "limit": 100},
    )
    assert pull_response.status_code == 200
    pull_payload = pull_response.json()
    assert pull_payload["current_version"] >= 1

    pulled = [row for row in pull_payload["activities"] if row["uuid"] == activity_uuid]
    assert len(pulled) == 1
    assert pulled[0]["execution_state"] == "PENDIENTE"
    assert pulled[0]["operational_state"] == "PENDIENTE"
    assert pulled[0]["sync_state"] == "SYNCED"
    assert pulled[0]["review_state"] == "NOT_APPLICABLE"
    assert pulled[0]["next_action"] == "INICIAR_ACTIVIDAD"


def test_firestore_e2e_sync_pull_denies_out_of_scope_project(client, monkeypatch, force_firestore_backend):
    fake_client = _FakeFirestoreClient()

    user_id = uuid4()
    principal = FirestoreUserPrincipal(
        id=user_id,
        email="firestore-scope@example.com",
        full_name="Scope User",
        status=UserStatus.ACTIVE,
        created_at=datetime.now(timezone.utc),
        last_login_at=None,
        roles=["OPERATIVO"],
        project_ids=["TMQ"],
        password_hash=get_password_hash("testpass123"),
        pin_hash=None,
    )

    monkeypatch.setattr(
        auth_api,
        "get_firestore_user_by_email",
        lambda email: principal if email == principal.email else None,
    )
    monkeypatch.setattr(
        deps_api,
        "get_firestore_user_by_id",
        lambda principal_id: principal if str(principal_id) == str(principal.id) else None,
    )
    monkeypatch.setattr(auth_api, "update_last_login", lambda _user_id: None)
    monkeypatch.setattr(sync_api, "get_firestore_client", lambda: fake_client)

    login_response = client.post(
        "/api/v1/auth/login",
        json={"email": principal.email, "password": "testpass123"},
    )
    assert login_response.status_code == 200
    headers = {"Authorization": f"Bearer {login_response.json()['access_token']}"}

    forbidden_pull = client.post(
        "/api/v1/sync/pull",
        headers=headers,
        json={"project_id": "TAP", "since_version": 0, "limit": 100},
    )
    assert forbidden_pull.status_code == 403
    assert "does not have access" in forbidden_pull.json()["detail"]


def test_firestore_e2e_sync_push_rejects_activity_type_not_in_catalog(client, monkeypatch, force_firestore_backend):
    fake_client = _FakeFirestoreClient()

    user_id = uuid4()
    project_id = "TMQ"
    catalog_version_id = str(uuid4())

    fake_client.collection("catalog_current").document(project_id).set(
        {
            "project_id": project_id,
            "version_id": catalog_version_id,
            "is_current": True,
        }
    )
    fake_client.collection("catalog_effective").document(f"{project_id}:{catalog_version_id}").set(
        {
            "project_id": project_id,
            "version_id": catalog_version_id,
            "activities": [{"id": "INSP_CIVIL"}],
        }
    )

    principal = FirestoreUserPrincipal(
        id=user_id,
        email="firestore-invalid-code@example.com",
        full_name="Validation User",
        status=UserStatus.ACTIVE,
        created_at=datetime.now(timezone.utc),
        last_login_at=None,
        roles=["OPERATIVO"],
        project_ids=[project_id],
        password_hash=get_password_hash("testpass123"),
        pin_hash=None,
    )

    monkeypatch.setattr(
        auth_api,
        "get_firestore_user_by_email",
        lambda email: principal if email == principal.email else None,
    )
    monkeypatch.setattr(
        deps_api,
        "get_firestore_user_by_id",
        lambda principal_id: principal if str(principal_id) == str(principal.id) else None,
    )
    monkeypatch.setattr(auth_api, "update_last_login", lambda _user_id: None)
    monkeypatch.setattr(sync_api, "get_firestore_client", lambda: fake_client)

    login_response = client.post(
        "/api/v1/auth/login",
        json={"email": principal.email, "password": "testpass123"},
    )
    assert login_response.status_code == 200
    headers = {"Authorization": f"Bearer {login_response.json()['access_token']}"}

    invalid_uuid = str(uuid4())
    invalid_push = client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={
            "project_id": project_id,
            "activities": [
                {
                    "uuid": invalid_uuid,
                    "project_id": project_id,
                    "front_id": None,
                    "pk_start": 100,
                    "pk_end": 120,
                    "execution_state": "PENDIENTE",
                    "assigned_to_user_id": None,
                    "created_by_user_id": str(principal.id),
                    "catalog_version_id": catalog_version_id,
                    "activity_type_code": "BAD_CODE",
                    "title": "Invalid activity type",
                    "description": "should fail catalog validation",
                    "latitude": None,
                    "longitude": None,
                    "deleted_at": None,
                }
            ],
        },
    )
    assert invalid_push.status_code == 200
    invalid_result = invalid_push.json()["results"][0]
    assert invalid_result["status"] == "INVALID"
    assert invalid_result["error_code"] == "ACTIVITY_TYPE_NOT_IN_CATALOG_VERSION"
    assert invalid_result["retryable"] is False
    assert invalid_result["suggested_action"] == "REFRESH_CATALOG_AND_RETRY"

    pull_response = client.post(
        "/api/v1/sync/pull",
        headers=headers,
        json={"project_id": project_id, "since_version": 0, "limit": 100},
    )
    assert pull_response.status_code == 200
    assert pull_response.json()["activities"] == []


def test_firestore_e2e_sync_push_conflict_returns_guidance(client, monkeypatch, force_firestore_backend):
    fake_client = _FakeFirestoreClient()

    user_id = uuid4()
    project_id = "TMQ"
    catalog_version_id = str(uuid4())

    _seed_catalog(fake_client, project_id, catalog_version_id)

    principal = FirestoreUserPrincipal(
        id=user_id,
        email="firestore-conflict@example.com",
        full_name="Conflict User",
        status=UserStatus.ACTIVE,
        created_at=datetime.now(timezone.utc),
        last_login_at=None,
        roles=["OPERATIVO"],
        project_ids=[project_id],
        password_hash=get_password_hash("testpass123"),
        pin_hash=None,
    )

    monkeypatch.setattr(
        auth_api,
        "get_firestore_user_by_email",
        lambda email: principal if email == principal.email else None,
    )
    monkeypatch.setattr(
        deps_api,
        "get_firestore_user_by_id",
        lambda principal_id: principal if str(principal_id) == str(principal.id) else None,
    )
    monkeypatch.setattr(auth_api, "update_last_login", lambda _user_id: None)
    monkeypatch.setattr(sync_api, "get_firestore_client", lambda: fake_client)

    login_response = client.post(
        "/api/v1/auth/login",
        json={"email": principal.email, "password": "testpass123"},
    )
    assert login_response.status_code == 200
    headers = {"Authorization": f"Bearer {login_response.json()['access_token']}"}

    activity_uuid = str(uuid4())
    first_push = client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={
            "project_id": project_id,
            "activities": [
                {
                    "uuid": activity_uuid,
                    "project_id": project_id,
                    "front_id": None,
                    "pk_start": 100,
                    "pk_end": 120,
                    "execution_state": "PENDIENTE",
                    "assigned_to_user_id": None,
                    "created_by_user_id": str(principal.id),
                    "catalog_version_id": catalog_version_id,
                    "activity_type_code": "INSP_CIVIL",
                    "title": "Baseline",
                    "description": "initial",
                    "latitude": None,
                    "longitude": None,
                    "deleted_at": None,
                    "sync_version": 0,
                }
            ],
        },
    )
    assert first_push.status_code == 200
    assert first_push.json()["results"][0]["status"] == "CREATED"

    conflict_push = client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={
            "project_id": project_id,
            "activities": [
                {
                    "uuid": activity_uuid,
                    "project_id": project_id,
                    "front_id": None,
                    "pk_start": 100,
                    "pk_end": 120,
                    "execution_state": "EN_CURSO",
                    "assigned_to_user_id": None,
                    "created_by_user_id": str(principal.id),
                    "catalog_version_id": catalog_version_id,
                    "activity_type_code": "INSP_CIVIL",
                    "title": "Changed title",
                    "description": "stale update",
                    "latitude": None,
                    "longitude": None,
                    "deleted_at": None,
                    "sync_version": 0,
                }
            ],
        },
    )
    assert conflict_push.status_code == 200
    conflict_result = conflict_push.json()["results"][0]
    assert conflict_result["status"] == "CONFLICT"
    assert conflict_result["retryable"] is False
    assert conflict_result["suggested_action"] == "PULL_AND_RESOLVE_CONFLICT"


def test_firestore_review_queue_includes_canonical_projection(client, monkeypatch, force_firestore_backend):
    fake_client = _FakeFirestoreClient()
    project_id = "TMQ"
    principal = _make_principal("review-queue@example.com", project_id)

    activity_uuid = str(uuid4())
    now = datetime.now(timezone.utc)
    fake_client.collection("activities").document(activity_uuid).set(
        {
            "uuid": activity_uuid,
            "project_id": project_id,
            "front_id": None,
            "pk_start": 100,
            "pk_end": 120,
            "execution_state": "REVISION_PENDIENTE",
            "assigned_to_user_id": None,
            "created_by_user_id": str(principal.id),
            "catalog_version_id": str(uuid4()),
            "activity_type_code": "INSP_CIVIL",
            "title": "Review queue item",
            "description": "pending review",
            "created_at": now,
            "updated_at": now,
            "sync_version": 2,
        }
    )

    monkeypatch.setattr(
        auth_api,
        "get_firestore_user_by_email",
        lambda email: principal if email == principal.email else None,
    )
    monkeypatch.setattr(
        deps_api,
        "get_firestore_user_by_id",
        lambda pid: principal if str(pid) == str(principal.id) else None,
    )
    monkeypatch.setattr(auth_api, "update_last_login", lambda _: None)
    monkeypatch.setattr(review_api, "get_firestore_client", lambda: fake_client)

    login_response = client.post("/api/v1/auth/login", json={"email": principal.email, "password": "testpass123"})
    assert login_response.status_code == 200
    headers = {"Authorization": f"Bearer {login_response.json()['access_token']}"}

    queue_response = client.get("/api/v1/review/queue", headers=headers, params={"project_id": project_id})
    assert queue_response.status_code == 200
    payload = queue_response.json()
    assert payload["items"]

    item = payload["items"][0]
    assert item["operational_state"] == "POR_COMPLETAR"
    assert item["sync_state"] == "SYNCED"
    assert item["review_state"] == "PENDING_REVIEW"
    assert item["next_action"] == "ESPERAR_DECISION_COORDINACION"


def test_firestore_review_queue_infers_front_from_municipality_scope(client, monkeypatch, force_firestore_backend):
    fake_client = _FakeFirestoreClient()
    project_id = "TMQ"
    principal = _make_principal("review-front@example.com", project_id)

    fake_client.collection("projects").document(project_id).set(
        {
            "front_location_scope": [
                {
                    "front_name": "Frente 1",
                    "municipio": "Doctor Mora",
                }
            ]
        }
    )

    activity_uuid = str(uuid4())
    now = datetime.now(timezone.utc)
    fake_client.collection("activities").document(activity_uuid).set(
        {
            "uuid": activity_uuid,
            "project_id": project_id,
            "front_id": None,
            "municipio": "Doctor Mora",
            "pk_start": 100,
            "execution_state": "REVISION_PENDIENTE",
            "assigned_to_user_id": None,
            "created_by_user_id": str(principal.id),
            "catalog_version_id": str(uuid4()),
            "activity_type_code": "INSP_CIVIL",
            "title": "Review queue item with inferred front",
            "description": "pending review",
            "created_at": now,
            "updated_at": now,
            "sync_version": 2,
        }
    )

    monkeypatch.setattr(
        auth_api,
        "get_firestore_user_by_email",
        lambda email: principal if email == principal.email else None,
    )
    monkeypatch.setattr(
        deps_api,
        "get_firestore_user_by_id",
        lambda pid: principal if str(pid) == str(principal.id) else None,
    )
    monkeypatch.setattr(auth_api, "update_last_login", lambda _: None)
    monkeypatch.setattr(review_api, "get_firestore_client", lambda: fake_client)

    login_response = client.post("/api/v1/auth/login", json={"email": principal.email, "password": "testpass123"})
    assert login_response.status_code == 200
    headers = {"Authorization": f"Bearer {login_response.json()['access_token']}"}

    queue_response = client.get("/api/v1/review/queue", headers=headers, params={"project_id": project_id})
    assert queue_response.status_code == 200
    payload = queue_response.json()
    assert payload["items"]

    item = payload["items"][0]
    assert item["front"] == "Frente 1"
    assert item["municipality"] == "Doctor Mora"


def test_firestore_completed_activity_detail_returns_traceability_payload(client, monkeypatch, force_firestore_backend):
    fake_client = _FakeFirestoreClient()
    project_id = "TMQ"
    principal = _make_principal("completed-detail@example.com", project_id)
    principal.roles = ["COORD"]

    fake_client.collection("projects").document(project_id).set(
        {
            "front_location_scope": [
                {
                    "front_name": "Frente 1",
                    "municipio": "Doctor Mora",
                }
            ]
        }
    )

    fake_client.collection("users").document(str(principal.id)).set(
        {
            "full_name": "Jesus Perez Lopez",
            "display_name": "Jesus",
            "email": principal.email,
        }
    )

    activity_uuid = str(uuid4())
    now = datetime.now(timezone.utc)
    fake_client.collection("activities").document(activity_uuid).set(
        {
            "uuid": activity_uuid,
            "project_id": project_id,
            "front_id": None,
            "municipio": "Doctor Mora",
            "pk_start": 20000,
            "pk_end": 20050,
            "execution_state": "COMPLETADA",
            "review_decision": "APPROVE",
            "assigned_to_user_id": str(principal.id),
            "created_by_user_id": str(principal.id),
            "catalog_version_id": str(uuid4()),
            "activity_type_code": "CAM",
            "title": "Caminamiento aprobado",
            "description": "detalle completo",
            "created_at": now,
            "updated_at": now,
            "last_reviewed_by": str(principal.id),
            "last_reviewed_at": now,
            "sync_version": 4,
        }
    )
    fake_client.collection("evidences").document(str(uuid4())).set(
        {
            "activity_id": activity_uuid,
            "description": "Pie de foto",
            "gcs_path": "gs://bucket/pie_de_foto.jpg",
            "created_at": now,
            "uploaded_by": str(principal.id),
        }
    )

    monkeypatch.setattr(
        auth_api,
        "get_firestore_user_by_email",
        lambda email: principal if email == principal.email else None,
    )
    monkeypatch.setattr(
        deps_api,
        "get_firestore_user_by_id",
        lambda pid: principal if str(pid) == str(principal.id) else None,
    )
    monkeypatch.setattr(auth_api, "update_last_login", lambda _: None)
    monkeypatch.setattr(completed_activities_api, "get_firestore_client", lambda: fake_client)

    login_response = client.post("/api/v1/auth/login", json={"email": principal.email, "password": "testpass123"})
    assert login_response.status_code == 200
    headers = {"Authorization": f"Bearer {login_response.json()['access_token']}"}

    detail_response = client.get(f"/api/v1/completed-activities/{activity_uuid}", headers=headers)
    assert detail_response.status_code == 200
    payload = detail_response.json()
    assert payload["front"] == "Frente 1"
    assert payload["assigned_name"] == "Jesus Perez Lopez"
    assert payload["evidence_count"] == 1
    assert payload["evidences"][0]["description"] == "Pie de foto"


def test_firestore_completed_activity_detail_separates_report_pdf_from_real_evidence(client, monkeypatch, force_firestore_backend):
    fake_client = _FakeFirestoreClient()
    project_id = "TMQ"
    principal = _make_principal("fernanda.pdf@example.com", project_id)
    principal.roles = ["ADMIN"]

    fake_client.collection("projects").document(project_id).set(
        {
            "front_location_scope": [
                {
                    "front_name": "Frente PDF",
                    "municipio": "Doctor Mora",
                }
            ]
        }
    )

    fake_client.collection("users").document(str(principal.id)).set(
        {
            "full_name": "Fernanda PDF",
            "email": principal.email,
        }
    )

    activity_uuid = str(uuid4())
    now = datetime.now(timezone.utc)
    fake_client.collection("activities").document(activity_uuid).set(
        {
            "uuid": activity_uuid,
            "project_id": project_id,
            "municipio": "Doctor Mora",
            "execution_state": "COMPLETADA",
            "review_decision": "APPROVE",
            "assigned_to_user_id": str(principal.id),
            "created_by_user_id": str(principal.id),
            "catalog_version_id": str(uuid4()),
            "activity_type_code": "CAM",
            "title": "Actividad con PDF",
            "created_at": now,
            "updated_at": now,
            "last_reviewed_by": str(principal.id),
            "last_reviewed_at": now,
        }
    )
    fake_client.collection("evidences").document(str(uuid4())).set(
        {
            "activity_id": activity_uuid,
            "evidence_type": "PHOTO",
            "description": "Foto real",
            "gcs_path": "gs://bucket/evidencia_real.jpg",
            "created_at": now,
            "uploaded_by": str(principal.id),
        }
    )
    fake_client.collection("evidences").document(str(uuid4())).set(
        {
            "activity_id": activity_uuid,
            "evidence_type": "PDF",
            "description": "Reporte generado",
            "gcs_path": "gs://bucket/reporte_generado.pdf",
            "original_file_name": "reporte_generado.pdf",
            "mime_type": "application/pdf",
            "created_at": now,
            "uploaded_by": str(principal.id),
        }
    )

    monkeypatch.setattr(
        auth_api,
        "get_firestore_user_by_email",
        lambda email: principal if email == principal.email else None,
    )
    monkeypatch.setattr(
        deps_api,
        "get_firestore_user_by_id",
        lambda pid: principal if str(pid) == str(principal.id) else None,
    )
    monkeypatch.setattr(auth_api, "update_last_login", lambda _: None)
    monkeypatch.setattr(completed_activities_api, "get_firestore_client", lambda: fake_client)

    login_response = client.post("/api/v1/auth/login", json={"email": principal.email, "password": "testpass123"})
    assert login_response.status_code == 200
    headers = {"Authorization": f"Bearer {login_response.json()['access_token']}"}

    list_response = client.get(
        f"/api/v1/completed-activities?project_id={project_id}&page=1&page_size=20",
        headers=headers,
    )
    assert list_response.status_code == 200
    list_payload = list_response.json()
    assert list_payload["items"][0]["evidence_count"] == 1

    detail_response = client.get(f"/api/v1/completed-activities/{activity_uuid}", headers=headers)
    assert detail_response.status_code == 200
    payload = detail_response.json()
    assert payload["evidence_count"] == 1
    assert len(payload["evidences"]) == 1
    assert payload["evidences"][0]["description"] == "Foto real"
    assert len(payload["documents"]) == 1
    assert payload["documents"][0]["description"] == "Reporte generado"


def test_firestore_review_queue_uses_creator_full_name_when_assigned_user_is_missing(client, monkeypatch, force_firestore_backend):
    fake_client = _FakeFirestoreClient()
    project_id = "TMQ"
    principal = _make_principal("jesus.perez.lopez@example.com", project_id)

    fake_client.collection("users").document(str(principal.id)).set(
        {
            "full_name": "Jesus Perez Lopez",
            "display_name": "Jesus",
            "email": principal.email,
        }
    )

    activity_uuid = str(uuid4())
    now = datetime.now(timezone.utc)
    fake_client.collection("activities").document(activity_uuid).set(
        {
            "uuid": activity_uuid,
            "project_id": project_id,
            "front_id": None,
            "pk_start": 111,
            "execution_state": "REVISION_PENDIENTE",
            "assigned_to_user_id": None,
            "created_by_user_id": str(principal.id),
            "catalog_version_id": str(uuid4()),
            "activity_type_code": "INSP_CIVIL",
            "title": "Review queue creator fallback",
            "description": "pending review",
            "created_at": now,
            "updated_at": now,
            "sync_version": 2,
        }
    )

    monkeypatch.setattr(
        auth_api,
        "get_firestore_user_by_email",
        lambda email: principal if email == principal.email else None,
    )
    monkeypatch.setattr(
        deps_api,
        "get_firestore_user_by_id",
        lambda pid: principal if str(pid) == str(principal.id) else None,
    )
    monkeypatch.setattr(auth_api, "update_last_login", lambda _: None)
    monkeypatch.setattr(review_api, "get_firestore_client", lambda: fake_client)

    login_response = client.post("/api/v1/auth/login", json={"email": principal.email, "password": "testpass123"})
    assert login_response.status_code == 200
    headers = {"Authorization": f"Bearer {login_response.json()['access_token']}"}

    queue_response = client.get("/api/v1/review/queue", headers=headers, params={"project_id": project_id})
    assert queue_response.status_code == 200
    payload = queue_response.json()
    assert payload["items"]

    item = payload["items"][0]
    assert item["assigned_to_user_name"] == "Jesus Perez Lopez"


def test_firestore_review_queue_maps_changes_required_to_canonical_review_state(client, monkeypatch, force_firestore_backend):
    fake_client = _FakeFirestoreClient()
    project_id = "TMQ"
    principal = _make_principal("review-changes@example.com", project_id)

    activity_uuid = str(uuid4())
    now = datetime.now(timezone.utc)
    fake_client.collection("activities").document(activity_uuid).set(
        {
            "uuid": activity_uuid,
            "project_id": project_id,
            "front_id": None,
            "pk_start": 110,
            "pk_end": 130,
            "execution_state": "REVISION_PENDIENTE",
            "review_decision": "CHANGES_REQUIRED",
            "assigned_to_user_id": None,
            "created_by_user_id": str(principal.id),
            "catalog_version_id": str(uuid4()),
            "activity_type_code": "INSP_CIVIL",
            "title": "Review changes required",
            "description": "requires corrections",
            "created_at": now,
            "updated_at": now,
            "sync_version": 3,
        }
    )

    monkeypatch.setattr(
        auth_api,
        "get_firestore_user_by_email",
        lambda email: principal if email == principal.email else None,
    )
    monkeypatch.setattr(
        deps_api,
        "get_firestore_user_by_id",
        lambda pid: principal if str(pid) == str(principal.id) else None,
    )
    monkeypatch.setattr(auth_api, "update_last_login", lambda _: None)
    monkeypatch.setattr(review_api, "get_firestore_client", lambda: fake_client)

    login_response = client.post("/api/v1/auth/login", json={"email": principal.email, "password": "testpass123"})
    assert login_response.status_code == 200
    headers = {"Authorization": f"Bearer {login_response.json()['access_token']}"}

    queue_response = client.get("/api/v1/review/queue", headers=headers, params={"project_id": project_id})
    assert queue_response.status_code == 200
    payload = queue_response.json()
    assert payload["items"]

    item = payload["items"][0]
    assert item["review_state"] == "CHANGES_REQUIRED"
    assert item["next_action"] == "CORREGIR_Y_REENVIAR"


def test_firestore_review_reject_uses_effective_assignee_for_notification_and_observation(client, monkeypatch, force_firestore_backend):
    fake_client = _FakeFirestoreClient()
    project_id = "TMQ"
    reviewer = _make_principal("reviewer@example.com", project_id)
    reviewer.roles = ["COORD"]
    reviewer.permission_scopes = [
        {
            "permission_code": "activity.reject",
            "project_id": project_id,
            "effect": "allow",
        }
    ]

    activity_uuid = str(uuid4())
    now = datetime.now(timezone.utc)
    fake_client.collection("activities").document(activity_uuid).set(
        {
            "uuid": activity_uuid,
            "project_id": project_id,
            "front_id": None,
            "pk_start": 110,
            "pk_end": 130,
            "execution_state": "REVISION_PENDIENTE",
            "assigned_to_user_id": None,
            "created_by_user_id": str(reviewer.id),
            "deleted_at": now,
            "catalog_version_id": str(uuid4()),
            "activity_type_code": "INSP_CIVIL",
            "title": "Needs correction",
            "description": "requires corrections",
            "created_at": now,
            "updated_at": now,
            "sync_version": 3,
        }
    )
    fake_client.collection("reject_reasons").document("gps_error").set(
        {
            "reason_code": "gps_error",
            "label": "GPS error",
            "requires_comment": False,
            "active": True,
            "created_at": now,
        }
    )

    captured_notification = {}

    monkeypatch.setattr(
        auth_api,
        "get_firestore_user_by_email",
        lambda email: reviewer if email == reviewer.email else None,
    )
    monkeypatch.setattr(
        deps_api,
        "get_firestore_user_by_id",
        lambda pid: reviewer if str(pid) == str(reviewer.id) else None,
    )
    monkeypatch.setattr(auth_api, "update_last_login", lambda _: None)
    monkeypatch.setattr(review_api, "get_firestore_client", lambda: fake_client)
    monkeypatch.setattr(
        review_api,
        "notify_review_decision",
        lambda **kwargs: captured_notification.update(kwargs) or {"sent": 1, "failed": 0, "invalidated": 0},
    )

    login_response = client.post("/api/v1/auth/login", json={"email": reviewer.email, "password": "testpass123"})
    assert login_response.status_code == 200
    headers = {"Authorization": f"Bearer {login_response.json()['access_token']}"}

    decision_response = client.post(
        f"/api/v1/review/activity/{activity_uuid}/decision",
        headers=headers,
        json={
            "decision": "REJECT",
            "reject_reason_code": "gps_error",
            "comment": "Corrige evidencias y reenvia.",
            "field_resolutions": [],
            "apply_to_similar": False,
        },
    )
    assert decision_response.status_code == 200
    assert decision_response.json()["status"] == "CHANGES_REQUIRED"

    assert captured_notification["assigned_user_id"] == str(reviewer.id)

    updated_activity = fake_client.collection("activities").document(activity_uuid).get().to_dict()
    assert updated_activity["deleted_at"] is None

    observation_docs = [
        payload
        for path, payload in fake_client._docs.items()
        if path.startswith("observations/")
    ]
    assert observation_docs
    assert observation_docs[0]["assignee_user_id"] == str(reviewer.id)


# ─── E4: Dirty-data regression tests ──────────────────────────────────────────


def _make_principal(email: str, project_id: str) -> FirestoreUserPrincipal:
    """Return a minimal active Firestore principal for Firestore-only tests."""
    return FirestoreUserPrincipal(
        id=uuid4(),
        email=email,
        full_name="Test User",
        status=UserStatus.ACTIVE,
        created_at=datetime.now(timezone.utc),
        last_login_at=None,
        roles=["OPERATIVO"],
        project_ids=[project_id],
        password_hash=get_password_hash("testpass123"),
        pin_hash=None,
    )


def _seed_catalog(fake_client: _FakeFirestoreClient, project_id: str, catalog_version_id: str) -> None:
    fake_client.collection("catalog_effective").document(
        f"{project_id}:{catalog_version_id}"
    ).set(
        {
            "project_id": project_id,
            "version_id": catalog_version_id,
            "activities": [{"id": "INSP_CIVIL"}],
        }
    )


def _login_and_get_headers(client, monkeypatch, principal: FirestoreUserPrincipal) -> dict:
    monkeypatch.setattr(
        auth_api,
        "get_firestore_user_by_email",
        lambda email: principal if email == principal.email else None,
    )
    monkeypatch.setattr(
        deps_api,
        "get_firestore_user_by_id",
        lambda pid: principal if str(pid) == str(principal.id) else None,
    )
    monkeypatch.setattr(auth_api, "update_last_login", lambda _: None)
    resp = client.post("/api/v1/auth/login", json={"email": principal.email, "password": "testpass123"})
    assert resp.status_code == 200
    return {"Authorization": f"Bearer {resp.json()['access_token']}"}


def test_firestore_pull_skips_doc_with_missing_uuid(client, monkeypatch, force_firestore_backend):
    """Pull must return valid docs even when some Firestore docs lack uuid."""
    fake_client = _FakeFirestoreClient()
    project_id = "TMQ"
    catalog_version_id = str(uuid4())
    _seed_catalog(fake_client, project_id, catalog_version_id)

    principal = _make_principal("dirty-uuid@example.com", project_id)

    # Seed one malformed doc (no uuid) and one valid doc
    good_uuid = str(uuid4())
    fake_client.collection("activities").document("good").set(
        {
            "uuid": good_uuid,
            "project_id": project_id,
            "activity_type_code": "INSP_CIVIL",
            "execution_state": "PENDIENTE",
            "sync_version": 1,
            "pk_start": 100,
            "pk_end": 200,
            "catalog_version_id": catalog_version_id,
            "created_by_user_id": str(principal.id),
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc),
        }
    )
    fake_client.collection("activities").document("bad-no-uuid").set(
        {
            # uuid intentionally missing
            "project_id": project_id,
            "activity_type_code": "INSP_CIVIL",
            "execution_state": "PENDIENTE",
            "sync_version": 1,
            "pk_start": 200,
            "pk_end": 300,
            "catalog_version_id": catalog_version_id,
            "created_by_user_id": str(principal.id),
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc),
        }
    )

    monkeypatch.setattr(sync_api, "get_firestore_client", lambda: fake_client)
    headers = _login_and_get_headers(client, monkeypatch, principal)

    resp = client.post(
        "/api/v1/sync/pull",
        headers=headers,
        json={"project_id": project_id, "since_version": 0, "limit": 100},
    )
    assert resp.status_code == 200
    activities = resp.json()["activities"]
    # The malformed doc must be silently skipped; only the valid one returned
    assert len(activities) == 1
    assert activities[0]["uuid"] == good_uuid


def test_firestore_pull_skips_doc_with_invalid_sync_version(client, monkeypatch, force_firestore_backend):
    """Pull must not crash when sync_version is None, a float, or a string."""
    fake_client = _FakeFirestoreClient()
    project_id = "TMQ"
    catalog_version_id = str(uuid4())
    _seed_catalog(fake_client, project_id, catalog_version_id)

    principal = _make_principal("dirty-sv@example.com", project_id)

    good_uuid = str(uuid4())
    fake_client.collection("activities").document("good").set(
        {
            "uuid": good_uuid,
            "project_id": project_id,
            "activity_type_code": "INSP_CIVIL",
            "execution_state": "PENDIENTE",
            "sync_version": 1,
            "pk_start": 100,
            "pk_end": 200,
            "catalog_version_id": catalog_version_id,
            "created_by_user_id": str(principal.id),
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc),
        }
    )
    # Three bad sync_version variants
    for doc_id, bad_sv in [("sv-none", None), ("sv-float", 1.5), ("sv-str", "v1")]:
        fake_client.collection("activities").document(doc_id).set(
            {
                "uuid": str(uuid4()),
                "project_id": project_id,
                "activity_type_code": "INSP_CIVIL",
                "execution_state": "PENDIENTE",
                "sync_version": bad_sv,
                "pk_start": 100,
                "pk_end": 200,
                "catalog_version_id": catalog_version_id,
                "created_by_user_id": str(principal.id),
                "created_at": datetime.now(timezone.utc),
                "updated_at": datetime.now(timezone.utc),
            }
        )

    monkeypatch.setattr(sync_api, "get_firestore_client", lambda: fake_client)
    headers = _login_and_get_headers(client, monkeypatch, principal)

    resp = client.post(
        "/api/v1/sync/pull",
        headers=headers,
        json={"project_id": project_id, "since_version": 0, "limit": 100},
    )
    assert resp.status_code == 200
    activities = resp.json()["activities"]
    # sync_version=None docs are filtered by _coerce_sync_version; floats and strings
    # coerce to int via _coerce_sync_version (1.5→1, "v1"→skipped as ValueError).
    # At least the valid doc must be present.
    uuids = [a["uuid"] for a in activities]
    assert good_uuid in uuids


def test_firestore_pull_handles_malformed_dates(client, monkeypatch, force_firestore_backend):
    """Pull does not crash when created_at/updated_at are garbage strings."""
    fake_client = _FakeFirestoreClient()
    project_id = "TMQ"
    catalog_version_id = str(uuid4())
    _seed_catalog(fake_client, project_id, catalog_version_id)

    principal = _make_principal("dirty-dates@example.com", project_id)
    doc_uuid = str(uuid4())
    fake_client.collection("activities").document(doc_uuid).set(
        {
            "uuid": doc_uuid,
            "project_id": project_id,
            "activity_type_code": "INSP_CIVIL",
            "execution_state": "PENDIENTE",
            "sync_version": 1,
            "pk_start": 100,
            "pk_end": 200,
            "catalog_version_id": catalog_version_id,
            "created_by_user_id": str(principal.id),
            "created_at": "NOT_A_DATE",   # malformed
            "updated_at": 12345,          # numeric, not datetime
        }
    )

    monkeypatch.setattr(sync_api, "get_firestore_client", lambda: fake_client)
    headers = _login_and_get_headers(client, monkeypatch, principal)

    resp = client.post(
        "/api/v1/sync/pull",
        headers=headers,
        json={"project_id": project_id, "since_version": 0, "limit": 100},
    )
    assert resp.status_code == 200
    # Malformed dates are replaced with utc_now fallback; doc must still be returned
    activities = resp.json()["activities"]
    assert any(a["uuid"] == doc_uuid for a in activities)


def test_firestore_push_handles_per_item_server_error(monkeypatch, force_firestore_backend):
    """A crash inside one push item must not fail remaining items."""
    from app.api.v1.sync import _firestore_push
    from app.schemas.sync import SyncPushRequest, SyncPushActivityItem

    project_id = "TMQ"
    catalog_version_id_good = str(uuid4())
    good_uuid = str(uuid4())
    bad_uuid = str(uuid4())

    call_count = {"n": 0}

    class _BrokenForFirst:
        """Firestore client that raises on the first document set() call."""
        def __init__(self):
            self._store: dict = {}

        def collection(self, name: str):
            return self

        def document(self, doc_id: str):
            return self

        def get(self):
            snap = type("S", (), {"exists": False, "to_dict": lambda s: {}})()
            return snap

        def set(self, payload, merge=False):
            call_count["n"] += 1
            if call_count["n"] == 1:
                raise RuntimeError("Simulated Firestore write error")
            self._store[str(uuid4())] = payload

        def where(self, *_a, **_kw):
            return self

        def limit(self, _):
            return self

        def stream(self):
            return iter([])

    monkeypatch.setattr(sync_api, "get_firestore_client", _BrokenForFirst)
    monkeypatch.setattr(
        sync_api,
        "_firestore_catalog_activity_codes",
        lambda project_id, catalog_version_id: {"INSP_CIVIL"},
    )

    request = SyncPushRequest(
        project_id=project_id,
        activities=[
            SyncPushActivityItem(
                uuid=bad_uuid,
                server_id=None,
                project_id=project_id,
                front_id=None,
                pk_start=1,
                pk_end=2,
                execution_state="PENDIENTE",
                assigned_to_user_id=None,
                created_by_user_id=str(uuid4()),
                catalog_version_id=catalog_version_id_good,
                activity_type_code="INSP_CIVIL",
                title="bad",
                description=None,
                latitude=None,
                longitude=None,
                deleted_at=None,
                sync_version=None,
            ),
            SyncPushActivityItem(
                uuid=good_uuid,
                server_id=None,
                project_id=project_id,
                front_id=None,
                pk_start=10,
                pk_end=20,
                execution_state="PENDIENTE",
                assigned_to_user_id=None,
                created_by_user_id=str(uuid4()),
                catalog_version_id=catalog_version_id_good,
                activity_type_code="INSP_CIVIL",
                title="good",
                description=None,
                latitude=None,
                longitude=None,
                deleted_at=None,
                sync_version=None,
            ),
        ],
    )

    response = _firestore_push(request)

    results = {str(r.uuid): r for r in response.results}
    assert results[bad_uuid].status == "INVALID"
    assert results[bad_uuid].error_code == "SERVER_ERROR"
    assert results[good_uuid].status == "CREATED"


def test_firestore_push_resubmission_clears_changes_required_review_fields(monkeypatch, force_firestore_backend):
    """Corrected activities must leave the old CHANGES_REQUIRED review state when re-submitted."""
    from app.api.v1.sync import _firestore_push
    from app.schemas.sync import SyncPushRequest, SyncPushActivityItem

    fake_client = _FakeFirestoreClient()
    project_id = "TMQ"
    catalog_version_id = str(uuid4())
    activity_uuid = str(uuid4())
    created_by_user_id = str(uuid4())
    now = datetime.now(timezone.utc)

    _seed_catalog(fake_client, project_id, catalog_version_id)
    fake_client.collection("activities").document(activity_uuid).set(
        {
            "uuid": activity_uuid,
            "project_id": project_id,
            "activity_type_code": "INSP_CIVIL",
            "execution_state": "COMPLETADA",
            "review_decision": "CHANGES_REQUIRED",
            "review_comment": "Falta evidencia",
            "review_reject_reason_code": "MISSING_INFO",
            "sync_version": 7,
            "pk_start": 142000,
            "pk_end": None,
            "catalog_version_id": catalog_version_id,
            "created_by_user_id": created_by_user_id,
            "created_at": now,
            "updated_at": now,
            "wizard_payload": {"risk_level": "medio", "notes": "antes"},
        }
    )

    monkeypatch.setattr(sync_api, "get_firestore_client", lambda: fake_client)
    monkeypatch.setattr(
        sync_api,
        "_firestore_catalog_activity_codes",
        lambda project_id, catalog_version_id: {"INSP_CIVIL"},
    )

    response = _firestore_push(
        SyncPushRequest(
            project_id=project_id,
            activities=[
                SyncPushActivityItem(
                    uuid=activity_uuid,
                    server_id=None,
                    project_id=project_id,
                    front_id=None,
                    pk_start=142000,
                    pk_end=None,
                    execution_state="COMPLETADA",
                    assigned_to_user_id=None,
                    created_by_user_id=created_by_user_id,
                    catalog_version_id=catalog_version_id,
                    activity_type_code="INSP_CIVIL",
                    title="Actividad corregida",
                    description="Ahora incluye evidencia",
                    latitude=None,
                    longitude=None,
                    deleted_at=None,
                    sync_version=7,
                    wizard_payload={
                        "risk_level": "medio",
                        "notes": "Corregida con evidencia",
                        "evidences": [
                            {"localPath": "/tmp/evidence.jpg", "descripcion": "Foto corregida"},
                        ],
                    },
                ),
            ],
        )
    )

    assert response.results[0].status == "UPDATED"

    stored = fake_client.collection("activities").document(activity_uuid).get().to_dict()
    assert stored["review_decision"] is None
    assert stored["review_comment"] is None
    assert stored["review_reject_reason_code"] is None
    assert stored["wizard_payload"]["notes"] == "Corregida con evidencia"

