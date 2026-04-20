"""Evidence API endpoints for upload and download URL workflows."""

import base64
import hashlib
import hmac
import json
from datetime import datetime, timedelta, timezone
from io import BytesIO
from pathlib import Path
from urllib.parse import quote, urlparse
from uuid import UUID, uuid4

import google.auth
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import FileResponse, StreamingResponse
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.cloud import storage

from app.api.deps import require_any_role, user_has_permission, verify_project_access
from app.core.rate_limit import enforce_rate_limit
from app.core.config import settings
from app.core.firestore import get_firestore_client
from typing import Any
from app.schemas.evidence import (
    UploadInitRequest,
    UploadInitResponse,
    UploadCompleteRequest,
    UploadCompleteResponse,
    DownloadUrlResponse,
)


router = APIRouter(prefix="/evidences", tags=["evidences"])

_ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "application/pdf"}
_MAX_UPLOAD_SIZE_BYTES = 20 * 1024 * 1024


def _allowed_for_evidence_edit():
    return require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])


def _allowed_for_evidence_view():
    return require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO", "LECTOR"])


def _is_local_backend() -> bool:
    return settings.EVIDENCE_STORAGE_BACKEND == "local"


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _normalized_bucket_name() -> str:
    bucket = str(settings.GCS_BUCKET or "").strip()
    if bucket.startswith("gs://"):
        bucket = bucket[len("gs://") :]
    return bucket.strip().strip("/")


def _sanitize_suffix(file_name: str) -> str:
    from pathlib import PurePosixPath
    import re

    suffix = PurePosixPath(file_name).suffix.lower()
    if not suffix:
        return ""
    return re.sub(r"[^a-zA-Z0-9.]", "", suffix)[:15]


def _urlsafe_b64encode(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("utf-8").rstrip("=")


def _urlsafe_b64decode(raw: str) -> bytes:
    return base64.urlsafe_b64decode(raw + ("=" * (-len(raw) % 4)))


def _build_download_proxy_token(*, evidence_id: str, object_path: str, expires_at: datetime) -> str:
    payload = {
        "evidence_id": str(evidence_id).strip(),
        "object_path": _normalize_object_path(object_path),
        "exp": int(expires_at.timestamp()),
    }
    encoded = _urlsafe_b64encode(
        json.dumps(payload, separators=(",", ":")).encode("utf-8")
    )
    signature = hmac.new(
        settings.JWT_SECRET.encode("utf-8"),
        encoded.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    return f"{encoded}.{signature}"


def _resolve_download_proxy_token(token: str, *, evidence_id: str) -> str:
    encoded, separator, provided_signature = str(token or "").partition(".")
    if not encoded or not separator or not provided_signature:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid download token")

    expected_signature = hmac.new(
        settings.JWT_SECRET.encode("utf-8"),
        encoded.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(provided_signature, expected_signature):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid download token")

    try:
        payload = json.loads(_urlsafe_b64decode(encoded).decode("utf-8"))
    except Exception as exc:  # pragma: no cover - defensive decoding guard
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid download token") from exc

    token_evidence_id = str(payload.get("evidence_id") or "").strip()
    object_path = _normalize_object_path(payload.get("object_path"))
    expires_at = int(payload.get("exp") or 0)
    if token_evidence_id != str(evidence_id).strip() or not object_path or expires_at < int(_utc_now().timestamp()):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Expired or invalid download token")
    return object_path


def _build_download_proxy_url(*, evidence_id: str, object_path: str, expires_at: datetime) -> str:
    token = _build_download_proxy_token(
        evidence_id=evidence_id,
        object_path=object_path,
        expires_at=expires_at,
    )
    return (
        f"{settings.LOCAL_BASE_URL}/api/v1/evidences/{evidence_id}"
        f"/download-proxy?token={quote(token, safe='')}"
    )


def _generate_gcs_signed_url(blob, *, method: str, content_type: str | None = None) -> str:
    signed_url_kwargs: dict[str, Any] = {
        "version": "v4",
        "expiration": timedelta(minutes=settings.SIGNED_URL_EXPIRE_MINUTES),
        "method": method,
    }
    if content_type:
        signed_url_kwargs["content_type"] = content_type

    try:
        return blob.generate_signed_url(**signed_url_kwargs)
    except AttributeError as exc:
        if "private key" not in str(exc).lower():
            raise

        credentials, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
        refresh = getattr(credentials, "refresh", None)
        if callable(refresh):
            refresh(GoogleAuthRequest())

        service_account_email = str(getattr(credentials, "service_account_email", "") or "").strip()
        access_token = str(getattr(credentials, "token", "") or "").strip()
        if not service_account_email or not access_token:
            raise

        signed_url_kwargs["service_account_email"] = service_account_email
        signed_url_kwargs["access_token"] = access_token
        return blob.generate_signed_url(**signed_url_kwargs)


def _generate_signed_upload_url(object_path: str, mime_type: str, evidence_id: str) -> tuple[str, datetime]:
    expires_at = _utc_now() + timedelta(minutes=settings.SIGNED_URL_EXPIRE_MINUTES)
    if _is_local_backend():
        return f"{settings.LOCAL_BASE_URL}/api/v1/evidences/local-upload/{evidence_id}", expires_at
    blob = storage.Client().bucket(_normalized_bucket_name()).blob(object_path)
    url = _generate_gcs_signed_url(blob, method="PUT", content_type=mime_type)
    return url, expires_at


def _generate_signed_download_url(object_path: str, *, evidence_id: str | None = None) -> tuple[str, datetime]:
    expires_at = _utc_now() + timedelta(minutes=settings.SIGNED_URL_EXPIRE_MINUTES)
    if _is_local_backend():
        return f"{settings.LOCAL_BASE_URL}/uploads/{object_path}", expires_at
    blob = storage.Client().bucket(_normalized_bucket_name()).blob(object_path)
    try:
        url = _generate_gcs_signed_url(blob, method="GET")
    except AttributeError as exc:
        if evidence_id is None or "private key" not in str(exc).lower():
            raise
        url = _build_download_proxy_url(
            evidence_id=str(evidence_id),
            object_path=object_path,
            expires_at=expires_at,
        )
    return url, expires_at


def _normalize_object_path(raw_value: Any) -> str:
    value = str(raw_value or "").strip()
    if not value:
        return ""

    if value.startswith("gs://"):
        bucket_and_path = value[len("gs://") :]
        _bucket, _sep, path = bucket_and_path.partition("/")
        return path.strip("/")

    parsed = urlparse(value)
    if parsed.scheme in {"http", "https"}:
        path = parsed.path.strip("/")
        if path.startswith("uploads/"):
            return path[len("uploads/") :]
        return path

    normalized = value.strip("/")
    if normalized.startswith("uploads/"):
        return normalized[len("uploads/") :]
    return normalized


def _resolve_evidence_object_path(payload: dict[str, Any]) -> str:
    for key in ("object_path", "gcs_path", "storage_path", "pending_object_path"):
        normalized = _normalize_object_path(payload.get(key))
        if normalized:
            return normalized
    return ""


def _resolve_evidence_project_id(client, payload: dict[str, Any]) -> str:
    direct_project_id = str(payload.get("project_id") or "").strip().upper()
    if direct_project_id:
        return direct_project_id

    activity_id = str(payload.get("activity_id") or "").strip()
    if not activity_id:
        return ""

    activity_snap = client.collection("activities").document(activity_id).get()
    if not activity_snap.exists:
        return ""

    activity_payload = activity_snap.to_dict() or {}
    return str(activity_payload.get("project_id") or "").strip().upper()


def _object_exists(object_path: str) -> bool:
    if _is_local_backend():
        return (Path(settings.LOCAL_UPLOADS_DIR) / object_path).exists()
    blob = storage.Client().bucket(_normalized_bucket_name()).blob(object_path)
    return blob.exists(client=storage.Client())


@router.post("/upload-init", response_model=UploadInitResponse, status_code=status.HTTP_200_OK)
def upload_init(
    request: UploadInitRequest,
    http_request: Request,
    current_user: Any = Depends(_allowed_for_evidence_edit()),
):
    enforce_rate_limit(
        http_request,
        scope="evidences.upload_init",
        limit=settings.RATE_LIMIT_EVIDENCE_UPLOAD_INIT_PER_MINUTE,
        window_seconds=settings.RATE_LIMIT_WINDOW_SECONDS,
    )

    client = get_firestore_client()
    activity_uuid = str(request.activityId)
    activity_ref = client.collection("activities").document(activity_uuid)
    activity_snap = activity_ref.get()
    if not activity_snap.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Activity {activity_uuid} not found")
    activity_payload = activity_snap.to_dict() or {}
    project_id = str(activity_payload.get("project_id") or "")
    verify_project_access(current_user, project_id, None)
    if not user_has_permission(current_user, "activity.edit", None, project_id=project_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Missing permission: activity.edit for project: {project_id}",
        )

    normalized_mime = (request.mimeType or "").strip().lower()
    if normalized_mime not in _ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Invalid mime_type. Allowed values: image/jpeg, image/png, application/pdf",
        )
    if request.sizeBytes > _MAX_UPLOAD_SIZE_BYTES:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="File too large. Maximum allowed size is 20MB")

    evidence_id = uuid4()
    object_path = f"activities/{activity_uuid}/evidences/{evidence_id}{_sanitize_suffix(request.fileName)}"
    signed_url, expires_at = _generate_signed_upload_url(object_path, normalized_mime, str(evidence_id))
    now = _utc_now()
    client.collection("evidences").document(str(evidence_id)).set(
        {
            "id": str(evidence_id),
            "activity_id": activity_uuid,
            "project_id": project_id,
            "mime_type": normalized_mime,
            "size_bytes": request.sizeBytes,
            "original_file_name": request.fileName,
            "pending_object_path": object_path,
            "object_path": None,
            "created_by": str(getattr(current_user, "id", "")),
            "created_at": now,
            "uploaded_at": None,
            "sync_version": 1,
        }
    )

    return UploadInitResponse(
        evidenceId=str(evidence_id),
        objectPath=object_path,
        signedUrl=signed_url,
        expiresAt=expires_at,
    )


@router.post("/upload-complete", response_model=UploadCompleteResponse, status_code=status.HTTP_200_OK)
def upload_complete(
    request: UploadCompleteRequest,
    current_user: Any = Depends(_allowed_for_evidence_edit()),
):
    client = get_firestore_client()
    evidence_ref = client.collection("evidences").document(str(request.evidenceId))
    snap = evidence_ref.get()
    if not snap.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Evidence {request.evidenceId} not found")
    payload = snap.to_dict() or {}
    project_id = _resolve_evidence_project_id(client, payload)
    verify_project_access(current_user, project_id, None)
    if not user_has_permission(current_user, "activity.edit", None, project_id=project_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Missing permission: activity.edit for project: {project_id}",
        )
    if str(payload.get("created_by") or "") != str(getattr(current_user, "id", "")):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to complete this upload")
    object_path = payload.get("pending_object_path")
    if not object_path:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Evidence upload not initialized")
    if not _object_exists(str(object_path)):
        detail = "Uploaded object not found in local storage" if _is_local_backend() else "Uploaded object not found in storage"
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=detail)

    evidence_ref.set(
        {
            "object_path": object_path,
            "pending_object_path": None,
            "uploaded_at": _utc_now(),
            "uploaded_by": str(getattr(current_user, "id", "")),
            "sync_version": int(payload.get("sync_version") or 0) + 1,
            **({"caption": request.description.strip()} if request.description and request.description.strip() else {}),
        },
        merge=True,
    )
    return UploadCompleteResponse(ok=True)


@router.get("/{evidence_id}/download-url", response_model=DownloadUrlResponse, status_code=status.HTTP_200_OK)
def get_download_url(
    evidence_id: str,
    _authenticated_user: Any = Depends(_allowed_for_evidence_view()),
):
    client = get_firestore_client()
    snap = client.collection("evidences").document(str(evidence_id)).get()
    if not snap.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Evidence {evidence_id} not found")
    payload = snap.to_dict() or {}
    project_id = _resolve_evidence_project_id(client, payload)
    verify_project_access(_authenticated_user, project_id, None)
    if not user_has_permission(_authenticated_user, "activity.view", None, project_id=project_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Missing permission: activity.view for project: {project_id}",
        )
    object_path = _resolve_evidence_object_path(payload)
    if not object_path:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Evidence file not available yet")

    legacy_backfill = {}
    if not str(payload.get("project_id") or "").strip() and project_id:
        legacy_backfill["project_id"] = project_id
    if not str(payload.get("object_path") or "").strip() and object_path:
        legacy_backfill["object_path"] = object_path
    if legacy_backfill:
        client.collection("evidences").document(str(evidence_id)).set(legacy_backfill, merge=True)

    signed_url, expires_at = _generate_signed_download_url(
        str(object_path),
        evidence_id=str(evidence_id),
    )

    return DownloadUrlResponse(
        signedUrl=signed_url,
        expiresAt=expires_at,
    )


@router.get("/{evidence_id}/download-proxy", status_code=status.HTTP_200_OK)
def download_via_proxy(
    evidence_id: str,
    token: str,
):
    client = get_firestore_client()
    snap = client.collection("evidences").document(str(evidence_id)).get()
    if not snap.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Evidence {evidence_id} not found")

    payload = snap.to_dict() or {}
    token_object_path = _resolve_download_proxy_token(token, evidence_id=evidence_id)
    resolved_object_path = _resolve_evidence_object_path(payload) or token_object_path
    if resolved_object_path != token_object_path:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Download token no longer matches this evidence")

    media_type = str(payload.get("mime_type") or "application/octet-stream").strip() or "application/octet-stream"
    file_name = Path(str(payload.get("original_file_name") or Path(resolved_object_path).name or evidence_id)).name

    if _is_local_backend():
        local_file = Path(settings.LOCAL_UPLOADS_DIR) / resolved_object_path
        if not local_file.exists():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Evidence file not found in local storage")
        return FileResponse(
            path=local_file,
            media_type=media_type,
            filename=file_name,
        )

    storage_client = storage.Client()
    blob = storage_client.bucket(_normalized_bucket_name()).blob(resolved_object_path)
    if not blob.exists(client=storage_client):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Evidence file not found in storage")

    return StreamingResponse(
        BytesIO(blob.download_as_bytes()),
        media_type=media_type,
        headers={"Content-Disposition": f'inline; filename="{file_name}"'},
    )


@router.put("/local-upload/{evidence_id}", status_code=status.HTTP_200_OK)
async def local_upload(
    evidence_id: str,
    http_request: Request,
    current_user: Any = Depends(_allowed_for_evidence_edit()),
):
    """Receive a raw file PUT and save it to LOCAL_UPLOADS_DIR.
    Only available when EVIDENCE_STORAGE_BACKEND=local.
    This endpoint acts as a local replacement for GCS presigned PUT URLs.
    """
    if settings.EVIDENCE_STORAGE_BACKEND != "local":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Local upload endpoint not available in this environment",
        )
    client = get_firestore_client()
    snap = client.collection("evidences").document(str(evidence_id)).get()
    if not snap.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Evidence {evidence_id} not found")
    payload = snap.to_dict() or {}
    if str(payload.get("created_by") or "") != str(getattr(current_user, "id", "")):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to upload this evidence")
    object_path = payload.get("pending_object_path")
    if not object_path:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Evidence upload not initialized")
    body = await http_request.body()
    dest = Path(settings.LOCAL_UPLOADS_DIR) / str(object_path)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(body)
    return {"ok": True}
