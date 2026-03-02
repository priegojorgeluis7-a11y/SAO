# SAO - Google Cloud Integration (Cloud Run + Cloud SQL + GCS)

## Goal
Connect SAO Mobile + SAO Desktop to Google Cloud:
- FastAPI on Cloud Run
- PostgreSQL on Cloud SQL
- Evidence files in Google Cloud Storage (GCS)
- Secrets in Secret Manager
- Signed URLs for uploads/downloads (no file proxy through API)

## Services
1) Cloud Run: FastAPI container
2) Cloud SQL: PostgreSQL
3) GCS Bucket: sao-evidences
4) Secret Manager:
   - DATABASE_URL
   - JWT_SECRET
   - GCS_BUCKET
5) Cloud Logging: default

## Database
Use PostgreSQL as single source of truth.

Tables (minimum):
- evidences(id uuid pk, activity_id uuid, object_path text, mime_type text, size_bytes int, caption text, created_by uuid, created_at timestamptz)
- activities(... existing ...)
- users(... existing ...)

## Evidence Upload Strategy (Required)
Use Signed URLs with PUT:
1) POST /evidences/upload-init
   Request: { activityId, mimeType, sizeBytes, fileName }
   Response: { evidenceId, objectPath, signedUrl, expiresAt }

2) Client uploads bytes directly to signedUrl (HTTP PUT) with Content-Type = mimeType.

3) POST /evidences/upload-complete
   Request: { evidenceId }
   Response: { ok: true }

## Evidence Download Strategy
Use Signed URLs with GET:
- GET /evidences/{evidenceId}/download-url
  Response: { signedUrl, expiresAt }

## Backend Requirements (FastAPI)
- Add dependency: google-cloud-storage
- EvidenceService:
  - generate_signed_upload_url(bucket, object_name, mime_type, expiry_minutes)
  - generate_signed_download_url(bucket, object_name, expiry_minutes)
  - object_exists(bucket, object_name)
- Store object_path in DB only after upload-complete verifies object exists.
- Never expose service account keys to clients.
- Use Cloud Run service account IAM to access GCS and Cloud SQL.

## Flutter Requirements (Mobile/Desktop)
- EvidenceUploadRepository:
  - uploadInit(activityId, mimeType, sizeBytes, fileName)
  - uploadBytesToSignedUrl(signedUrl, bytes, mimeType)
  - uploadComplete(evidenceId)
- Offline-first on mobile:
  - queue pending uploads in local sqlite (drift)
  - retry with exponential backoff
- Desktop online:
  - fetch and show evidence via download signed URL

## Security
- All API endpoints require JWT.
- RBAC: only authorized roles can view evidences.
- Signed URLs short expiry (10-15 minutes).}+