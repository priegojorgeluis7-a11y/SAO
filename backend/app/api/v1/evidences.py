"""Evidence API endpoints for upload and download URL workflows."""

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import require_permission, verify_project_access
from app.core.database import get_db
from app.models.user import User
from app.schemas.evidence import (
    UploadInitRequest,
    UploadInitResponse,
    UploadCompleteRequest,
    UploadCompleteResponse,
    DownloadUrlResponse,
)
from app.services.evidence_service import EvidenceService


router = APIRouter(prefix="/evidences", tags=["evidences"])


@router.post("/upload-init", response_model=UploadInitResponse, status_code=status.HTTP_200_OK)
def upload_init(
    request: UploadInitRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("activity.edit")),
):
    service = EvidenceService(db)
    activity = service.get_activity_or_404(request.activityId)

    # RBAC by project scope
    verify_project_access(current_user, activity.project_id, db)

    evidence, signed_url, expires_at = service.upload_init(
        activity_id=request.activityId,
        mime_type=request.mimeType,
        size_bytes=request.sizeBytes,
        file_name=request.fileName,
        current_user=current_user,
    )

    return UploadInitResponse(
        evidenceId=str(evidence.id),
        objectPath=evidence.pending_object_path or "",
        signedUrl=signed_url,
        expiresAt=expires_at,
    )


@router.post("/upload-complete", response_model=UploadCompleteResponse, status_code=status.HTTP_200_OK)
def upload_complete(
    request: UploadCompleteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("activity.edit")),
):
    service = EvidenceService(db)
    service.upload_complete(request.evidenceId, current_user)
    return UploadCompleteResponse(ok=True)


@router.get("/{evidence_id}/download-url", response_model=DownloadUrlResponse, status_code=status.HTTP_200_OK)
def get_download_url(
    evidence_id: str,
    db: Session = Depends(get_db),
    _authenticated_user: User = Depends(require_permission("activity.view")),
):
    service = EvidenceService(db)
    signed_url, expires_at = service.generate_download_url(evidence_id)

    return DownloadUrlResponse(
        signedUrl=signed_url,
        expiresAt=expires_at,
    )
