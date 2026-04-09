from types import SimpleNamespace

from app.api.v1 import evidences as evidences_api


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
