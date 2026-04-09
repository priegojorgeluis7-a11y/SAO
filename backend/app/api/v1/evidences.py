"""Evidence API endpoints for upload and download URL workflows."""

from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import UUID, uuid4

import google.auth
from fastapi import APIRouter, Depends, HTTPException, Request, status
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


def _generate_signed_download_url(object_path: str) -> tuple[str, datetime]:
    expires_at = _utc_now() + timedelta(minutes=settings.SIGNED_URL_EXPIRE_MINUTES)
    if _is_local_backend():
        return f"{settings.LOCAL_BASE_URL}/uploads/{object_path}", expires_at
    blob = storage.Client().bucket(_normalized_bucket_name()).blob(object_path)
    url = _generate_gcs_signed_url(blob, method="GET")
    return url, expires_at


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
    project_id = str(payload.get("project_id") or "")
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
            "sync_version": int(payload.get("sync_version") or 0) + 1,
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
    project_id = str(payload.get("project_id") or "")
    verify_project_access(_authenticated_user, project_id, None)
    if not user_has_permission(_authenticated_user, "activity.view", None, project_id=project_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Missing permission: activity.view for project: {project_id}",
        )
    object_path = payload.get("object_path")
    if not object_path:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Evidence file not available yet")
    signed_url, expires_at = _generate_signed_download_url(str(object_path))

    return DownloadUrlResponse(
        signedUrl=signed_url,
        expiresAt=expires_at,
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
