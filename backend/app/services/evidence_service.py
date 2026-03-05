from datetime import datetime, timedelta, timezone
from pathlib import Path, PurePosixPath
import re
from typing import Tuple
from uuid import UUID

from fastapi import HTTPException, status
from google.cloud import storage
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.activity import Activity
from app.models.evidence import Evidence
from app.models.user import User


class EvidenceService:
    """Handle evidence upload lifecycle and signed URL operations.

    Supports two storage backends:
    - "gcs"   (default): Google Cloud Storage with signed URLs.
    - "local" (dev):     Saves files to LOCAL_UPLOADS_DIR; serves via /uploads/*.
    """

    ALLOWED_MIME_TYPES = {
        "image/jpeg",
        "image/png",
        "application/pdf",
    }
    MAX_UPLOAD_SIZE_BYTES = 20 * 1024 * 1024

    def __init__(self, db: Session):
        self.db = db
        self.bucket_name = settings.GCS_BUCKET
        if not self._is_local:
            self.storage_client = storage.Client()
        else:
            self.storage_client = None

    @property
    def _is_local(self) -> bool:
        return settings.EVIDENCE_STORAGE_BACKEND == "local"

    @staticmethod
    def _utc_now() -> datetime:
        """Return timezone-aware UTC datetime."""
        return datetime.now(timezone.utc)

    def _sanitize_filename(self, filename: str) -> str:
        """Return a safe, short file suffix (including dot) for object storage keys."""
        suffix = PurePosixPath(filename).suffix.lower()
        if not suffix:
            return ""
        return re.sub(r"[^a-zA-Z0-9.]", "", suffix)[:15]

    def _build_object_path(self, activity_id: str, evidence_id: UUID, file_name: str) -> str:
        """Build deterministic storage path for an evidence object."""
        suffix = self._sanitize_filename(file_name)
        return f"activities/{activity_id}/evidences/{evidence_id}{suffix}"

    @staticmethod
    def _parse_uuid(value: UUID | str) -> UUID:
        """Parse UUID strings into UUID objects."""
        if isinstance(value, UUID):
            return value
        return UUID(value)

    def _get_evidence_or_404(self, evidence_id: str) -> Evidence:
        """Get evidence by ID or raise 404 when it does not exist."""
        evidence = self.db.query(Evidence).filter(Evidence.id == UUID(evidence_id)).first()
        if not evidence:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Evidence {evidence_id} not found",
            )
        return evidence

    def generate_signed_upload_url(
        self,
        bucket: str,
        object_name: str,
        mime_type: str,
        expiry_minutes: int,
        evidence_id: str | None = None,
    ) -> Tuple[str, datetime]:
        """Create an upload URL. Returns a local PUT endpoint URL in local mode."""
        expires_at = self._utc_now() + timedelta(minutes=expiry_minutes)
        if self._is_local:
            url = f"{settings.LOCAL_BASE_URL}/api/v1/evidences/local-upload/{evidence_id}"
            return url, expires_at
        blob = self.storage_client.bucket(bucket).blob(object_name)
        signed_url = blob.generate_signed_url(
            version="v4",
            expiration=timedelta(minutes=expiry_minutes),
            method="PUT",
            content_type=mime_type,
        )
        return signed_url, expires_at

    def generate_signed_download_url(
        self,
        bucket: str,
        object_name: str,
        expiry_minutes: int,
    ) -> Tuple[str, datetime]:
        """Create a download URL. Returns a local static URL in local mode."""
        expires_at = self._utc_now() + timedelta(minutes=expiry_minutes)
        if self._is_local:
            url = f"{settings.LOCAL_BASE_URL}/uploads/{object_name}"
            return url, expires_at
        blob = self.storage_client.bucket(bucket).blob(object_name)
        signed_url = blob.generate_signed_url(
            version="v4",
            expiration=timedelta(minutes=expiry_minutes),
            method="GET",
        )
        return signed_url, expires_at

    def object_exists(self, bucket: str, object_name: str) -> bool:
        """Check whether object exists (GCS bucket or local disk)."""
        if self._is_local:
            return (Path(settings.LOCAL_UPLOADS_DIR) / object_name).exists()
        blob = self.storage_client.bucket(bucket).blob(object_name)
        return blob.exists(client=self.storage_client)

    def save_local_upload(self, evidence_id: str, content: bytes) -> None:
        """Persist an uploaded file to LOCAL_UPLOADS_DIR (local mode only)."""
        evidence = self._get_evidence_or_404(evidence_id)
        if not evidence.pending_object_path:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Evidence upload not initialized",
            )
        dest = Path(settings.LOCAL_UPLOADS_DIR) / evidence.pending_object_path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(content)

    def get_activity_or_404(self, activity_id: UUID | str) -> Activity:
        """Get activity by UUID or raise 404 when missing."""
        activity_uuid = self._parse_uuid(activity_id)
        activity = self.db.query(Activity).filter(Activity.uuid == activity_uuid).first()
        if not activity:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Activity {activity_id} not found",
            )
        return activity

    def upload_init(
        self,
        activity_id: UUID | str,
        mime_type: str,
        size_bytes: int,
        file_name: str,
        current_user: User,
    ) -> tuple[Evidence, str, datetime]:
        """Initialize evidence upload, persist pending object path, and return signed PUT URL."""
        normalized_mime = (mime_type or "").strip().lower()
        if normalized_mime not in self.ALLOWED_MIME_TYPES:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=(
                    "Invalid mime_type. Allowed values: "
                    "image/jpeg, image/png, application/pdf"
                ),
            )

        if size_bytes > self.MAX_UPLOAD_SIZE_BYTES:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="File too large. Maximum allowed size is 20MB",
            )

        self.get_activity_or_404(activity_id)

        evidence = Evidence(
            activity_id=self._parse_uuid(activity_id),
            mime_type=normalized_mime,
            size_bytes=size_bytes,
            original_file_name=file_name,
            created_by=current_user.id,
        )
        self.db.add(evidence)
        self.db.flush()

        object_path = self._build_object_path(str(activity_id), evidence.id, file_name)
        evidence.pending_object_path = object_path

        signed_url, expires_at = self.generate_signed_upload_url(
            bucket=self.bucket_name,
            object_name=object_path,
            mime_type=normalized_mime,
            expiry_minutes=settings.SIGNED_URL_EXPIRE_MINUTES,
            evidence_id=str(evidence.id),
        )

        self.db.commit()
        self.db.refresh(evidence)
        return evidence, signed_url, expires_at

    def upload_complete(self, evidence_id: str, current_user: User) -> None:
        """Mark upload as completed after verifying ownership and object presence."""
        evidence = self._get_evidence_or_404(evidence_id)

        if evidence.created_by != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not authorized to complete this upload",
            )

        if not evidence.pending_object_path:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Evidence upload not initialized",
            )

        if not self.object_exists(self.bucket_name, evidence.pending_object_path):
            detail = (
                "Uploaded object not found in local storage"
                if self._is_local
                else "Uploaded object not found in storage"
            )
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=detail)

        evidence.object_path = evidence.pending_object_path
        evidence.pending_object_path = None
        evidence.uploaded_at = self._utc_now()
        self.db.commit()

    def generate_download_url(self, evidence_id: str) -> tuple[str, datetime]:
        """Generate temporary download URL for an uploaded evidence file."""
        evidence = self._get_evidence_or_404(evidence_id)

        if not evidence.object_path:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Evidence file not available yet",
            )

        return self.generate_signed_download_url(
            bucket=self.bucket_name,
            object_name=evidence.object_path,
            expiry_minutes=settings.SIGNED_URL_EXPIRE_MINUTES,
        )
