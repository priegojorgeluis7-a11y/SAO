from types import SimpleNamespace

from app.api.v1 import evidences as evidences_api


class _FakeDocumentSnapshot:
    def __init__(self, payload):
        self._payload = payload
        self.exists = payload is not None

    def to_dict(self):
        return dict(self._payload or {})


class _FakeDocumentReference:
    def __init__(self, payload):
        self._payload = payload

    def get(self):
        return _FakeDocumentSnapshot(self._payload)

    def set(self, values, merge=False):
        if self._payload is None:
            self._payload = {}
        if merge:
            self._payload.update(values)
        else:
            self._payload = dict(values)


class _FakeFirestoreCollection:
    def __init__(self, docs):
        self._docs = docs

    def document(self, doc_id: str):
        return _FakeDocumentReference(self._docs.get(doc_id))


class _FakeFirestoreClient:
    def __init__(self, collections):
        self._collections = collections

    def collection(self, name: str):
        return _FakeFirestoreCollection(self._collections.get(name, {}))


class _FakeCredentialsWithoutPrivateKey:
    def __init__(self):
        self.service_account_email = "sao-runner@sao-prod-488416.iam.gserviceaccount.com"
        self.token = ""
        self.refresh_calls = 0

    def refresh(self, _request):
        self.refresh_calls += 1
        self.token = "refreshed-access-token"


class _FakeBlob:
    def __init__(self, bucket_name: str, object_path: str):
        self.bucket_name = bucket_name
        self.object_path = object_path
        self.calls: list[dict[str, object]] = []

    def generate_signed_url(self, **kwargs):
        self.calls.append(dict(kwargs))
        if "service_account_email" not in kwargs and "access_token" not in kwargs and self.bucket_name == "needs-fallback":
            raise AttributeError("you need a private key to sign credentials")
        return f"https://example.test/{self.bucket_name}/{self.object_path}"

    def exists(self, client=None):
        return True


class _FakeBucket:
    def __init__(self, name: str):
        self.name = name

    def blob(self, object_path: str):
        return _FakeBlob(self.name, object_path)


class _FakeStorageClient:
    def __init__(self):
        self.bucket_names: list[str] = []
        self.blobs: list[_FakeBlob] = []

    def bucket(self, name: str, user_project=None):
        self.bucket_names.append(name)
        bucket = _FakeBucket(name)
        original_blob = bucket.blob

        def _tracking_blob(object_path: str):
            blob = original_blob(object_path)
            self.blobs.append(blob)
            return blob

        bucket.blob = _tracking_blob
        return bucket


def test_generate_signed_upload_url_normalizes_bucket_name(monkeypatch):
    fake_storage = _FakeStorageClient()

    monkeypatch.setattr(
        evidences_api,
        "storage",
        SimpleNamespace(Client=lambda: fake_storage),
    )
    monkeypatch.setattr(evidences_api.settings, "EVIDENCE_STORAGE_BACKEND", "gcs")
    monkeypatch.setattr(
        evidences_api.settings,
        "GCS_BUCKET",
        " gs://sao-evidences-97150883570/\n",
    )

    signed_url, _ = evidences_api._generate_signed_upload_url(
        "activities/act-1/evidences/test.jpg",
        "image/jpeg",
        "ev-1",
    )

    assert fake_storage.bucket_names == ["sao-evidences-97150883570"]
    assert signed_url == (
        "https://example.test/sao-evidences-97150883570/"
        "activities/act-1/evidences/test.jpg"
    )


def test_generate_signed_upload_url_uses_service_account_fallback_on_cloud_run(monkeypatch):
    fake_storage = _FakeStorageClient()
    fake_credentials = _FakeCredentialsWithoutPrivateKey()

    monkeypatch.setattr(
        evidences_api,
        "storage",
        SimpleNamespace(Client=lambda: fake_storage),
    )
    monkeypatch.setattr(evidences_api.settings, "EVIDENCE_STORAGE_BACKEND", "gcs")
    monkeypatch.setattr(evidences_api.settings, "GCS_BUCKET", "needs-fallback")
    monkeypatch.setattr(evidences_api.google.auth, "default", lambda scopes=None: (fake_credentials, "sao-prod-488416"))
    monkeypatch.setattr(evidences_api, "GoogleAuthRequest", lambda: object())

    signed_url, _ = evidences_api._generate_signed_upload_url(
        "activities/act-1/evidences/test.jpg",
        "image/jpeg",
        "ev-1",
    )

    assert signed_url == "https://example.test/needs-fallback/activities/act-1/evidences/test.jpg"
    assert fake_credentials.refresh_calls == 1
    assert fake_storage.blobs[-1].calls[-1]["service_account_email"] == fake_credentials.service_account_email
    assert fake_storage.blobs[-1].calls[-1]["access_token"] == "refreshed-access-token"


def test_get_download_url_allows_operativo_same_project_for_legacy_evidence(monkeypatch):
    fake_client = _FakeFirestoreClient(
        {
            "evidences": {
                "ev-1": {
                    "id": "ev-1",
                    "activity_id": "act-1",
                    "gcs_path": "activities/act-1/evidences/reporte.pdf",
                },
            },
            "activities": {
                "act-1": {
                    "uuid": "act-1",
                    "project_id": "TMQ",
                },
            },
        }
    )
    user = SimpleNamespace(
        id="operativo-1",
        roles=["OPERATIVO"],
        project_ids=["TMQ"],
        permission_scopes=[],
    )

    monkeypatch.setattr(evidences_api, "get_firestore_client", lambda: fake_client)
    monkeypatch.setattr(evidences_api, "user_has_permission", lambda *_args, **_kwargs: True)
    monkeypatch.setattr(evidences_api.settings, "EVIDENCE_STORAGE_BACKEND", "local")
    monkeypatch.setattr(evidences_api.settings, "LOCAL_BASE_URL", "http://localhost:8000")

    response = evidences_api.get_download_url("ev-1", _authenticated_user=user)

    assert str(response.signedUrl).endswith("/uploads/activities/act-1/evidences/reporte.pdf")


def test_get_download_url_falls_back_to_proxy_when_signing_is_unavailable(monkeypatch):
    fake_client = _FakeFirestoreClient(
        {
            "evidences": {
                "ev-2": {
                    "id": "ev-2",
                    "activity_id": "act-2",
                    "object_path": "activities/act-2/evidences/reporte.pdf",
                    "mime_type": "application/pdf",
                    "original_file_name": "reporte.pdf",
                },
            },
            "activities": {
                "act-2": {
                    "uuid": "act-2",
                    "project_id": "TMQ",
                },
            },
        }
    )
    user = SimpleNamespace(
        id="operativo-1",
        roles=["OPERATIVO"],
        project_ids=["TMQ"],
        permission_scopes=[],
    )
    fake_storage = _FakeStorageClient()
    fake_credentials = _FakeCredentialsWithoutPrivateKey()
    fake_credentials.service_account_email = ""

    monkeypatch.setattr(evidences_api, "get_firestore_client", lambda: fake_client)
    monkeypatch.setattr(evidences_api, "user_has_permission", lambda *_args, **_kwargs: True)
    monkeypatch.setattr(
        evidences_api,
        "storage",
        SimpleNamespace(Client=lambda: fake_storage),
    )
    monkeypatch.setattr(evidences_api.settings, "EVIDENCE_STORAGE_BACKEND", "gcs")
    monkeypatch.setattr(evidences_api.settings, "GCS_BUCKET", "needs-fallback")
    monkeypatch.setattr(evidences_api.settings, "LOCAL_BASE_URL", "http://localhost:8000")
    monkeypatch.setattr(
        evidences_api.google.auth,
        "default",
        lambda scopes=None: (fake_credentials, "sao-prod-488416"),
    )
    monkeypatch.setattr(evidences_api, "GoogleAuthRequest", lambda: object())

    response = evidences_api.get_download_url("ev-2", _authenticated_user=user)

    assert str(response.signedUrl).startswith(
        "http://localhost:8000/api/v1/evidences/ev-2/download-proxy?token="
    )
