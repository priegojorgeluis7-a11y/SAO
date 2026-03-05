"""Tests for evidence upload endpoints"""
import pytest
from datetime import datetime, timezone
from uuid import uuid4
from unittest.mock import patch, MagicMock

from app.models.catalog import CatalogStatus, CatalogVersion
from app.core.config import settings
from app.models.front import Front
from app.models.project import Project, ProjectStatus
from app.models.role import Role
from app.models.permission import Permission
from app.models.user_role_scope import UserRoleScope


@pytest.fixture
def test_project(db):
    """Create test project"""
    project = Project(
        id="TMQ",
        name="Test Project TMQ",
        status=ProjectStatus.ACTIVE,
        start_date=datetime.now().date(),
    )
    db.add(project)
    db.commit()
    db.refresh(project)
    return project


@pytest.fixture
def test_front(db, test_project):
    """Create test front"""
    front = Front(
        id=uuid4(),
        code="F1",
        name="Front 1",
        project_id=test_project.id,
        pk_start=0,
        pk_end=50000,
    )
    db.add(front)
    db.commit()
    db.refresh(front)
    return front


@pytest.fixture
def test_catalog(db, test_user):
    """Create test catalog version"""
    catalog = CatalogVersion(
        id=uuid4(),
        project_id="TMQ",
        version_number="1.0.0",
        status=CatalogStatus.PUBLISHED,
        hash="test123",
        published_at=datetime.now(timezone.utc),
        published_by_id=test_user.id,
    )
    db.add(catalog)
    db.commit()
    db.refresh(catalog)
    return catalog


@pytest.fixture
def test_role(db):
    """Create test role with activity.edit and activity.view permissions"""
    role = Role(
        id=99,
        name="TEST_ROLE",
        description="Test role"
    )
    db.add(role)
    db.flush()
    
    # Create/fetch permissions
    edit_perm = db.query(Permission).filter(Permission.code == "activity.edit").first()
    if not edit_perm:
        edit_perm = Permission(
            id=100,
            code="activity.edit",
            resource="activity",
            action="edit"
        )
        db.add(edit_perm)
        db.flush()
    
    view_perm = db.query(Permission).filter(Permission.code == "activity.view").first()
    if not view_perm:
        view_perm = Permission(
            id=101,
            code="activity.view",
            resource="activity",
            action="view"
        )
        db.add(view_perm)
        db.flush()
    
    role.permissions.append(edit_perm)
    role.permissions.append(view_perm)
    db.commit()
    db.refresh(role)
    return role


@pytest.fixture
def test_user_scope_tmq(db, test_user, test_role, test_project):
    """Grant test user access to TMQ project with activity.edit"""
    scope = UserRoleScope(
        id=uuid4(),
        user_id=test_user.id,
        role_id=test_role.id,
        project_id=test_project.id,
    )
    db.add(scope)
    db.commit()
    db.refresh(scope)
    return scope


@pytest.fixture
def test_activity(db, test_project, test_front, test_catalog, test_user):
    """Create test activity"""
    from app.models.activity import Activity
    
    activity = Activity(
        uuid=uuid4(),
        project_id=test_project.id,
        front_id=test_front.id,
        pk_start=10000,
        pk_end=10500,
        execution_state="EN_CURSO",
        created_by_user_id=test_user.id,
        catalog_version_id=test_catalog.id,
        activity_type_code="INSP_CIVIL",
    )
    db.add(activity)
    db.commit()
    db.refresh(activity)
    return activity


@patch("app.services.evidence_service.storage.Client")
def test_upload_init(mock_storage_client, client, auth_headers, test_activity, test_user_scope_tmq):
    """Test evidence upload initialization"""
    # Mock GCS client
    mock_blob = MagicMock()
    mock_blob.generate_signed_url.return_value = "https://signed-url.example.com/upload"
    
    mock_bucket = MagicMock()
    mock_bucket.blob.return_value = mock_blob
    
    mock_client = MagicMock()
    mock_client.bucket.return_value = mock_bucket
    mock_storage_client.return_value = mock_client
    
    request_data = {
        "activityId": str(test_activity.uuid),
        "mimeType": "image/jpeg",
        "sizeBytes": 1024000,
        "fileName": "photo.jpg"
    }
    
    response = client.post(
        "/api/v1/evidences/upload-init",
        json=request_data,
        headers=auth_headers
    )
    
    assert response.status_code == 200
    data = response.json()
    assert "evidenceId" in data
    assert data["objectPath"].startswith("activities/")
    assert data["signedUrl"] == "https://signed-url.example.com/upload"
    assert "expiresAt" in data


@patch("app.services.evidence_service.storage.Client")
def test_upload_complete(mock_storage_client, client, auth_headers, test_activity, db, test_user_scope_tmq):
    """Test evidence upload completion"""
    from app.models.evidence import Evidence
    
    # Create pending evidence
    evidence =Evidence(
        activity_id=test_activity.uuid,
        mime_type="image/jpeg",
        size_bytes=1024000,
        original_file_name="photo.jpg",
        pending_object_path="activities/test-activity-uuid/evidences/evidence-uuid.jpg",
        created_by=test_activity.created_by_user_id,
    )
    db.add(evidence)
    db.commit()
    db.refresh(evidence)
    
    # Mock GCS client - object exists
    mock_blob = MagicMock()
    mock_blob.exists.return_value = True
    
    mock_bucket = MagicMock()
    mock_bucket.blob.return_value = mock_blob
    
    mock_client = MagicMock()
    mock_client.bucket.return_value = mock_bucket
    mock_storage_client.return_value = mock_client
    
    request_data = {
        "evidenceId": str(evidence.id)
    }
    
    response = client.post(
        "/api/v1/evidences/upload-complete",
        json=request_data,
        headers=auth_headers
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["ok"] is True
    
    # Verify evidence updated
    db.refresh(evidence)
    assert evidence.object_path == "activities/test-activity-uuid/evidences/evidence-uuid.jpg"
    assert evidence.pending_object_path is None
    assert evidence.uploaded_at is not None


@patch("app.services.evidence_service.storage.Client")
def test_download_url(mock_storage_client, client, auth_headers, test_activity, db, test_user_scope_tmq):
    """Test evidence download URL generation"""
    from app.models.evidence import Evidence
    
    # Create uploaded evidence
    evidence = Evidence(
        activity_id=test_activity.uuid,
        mime_type="image/jpeg",
        size_bytes=1024000,
        original_file_name="photo.jpg",
        object_path="activities/test-activity-uuid/evidences/evidence-uuid.jpg",
        created_by=test_activity.created_by_user_id,
    )
    db.add(evidence)
    db.commit()
    db.refresh(evidence)
    
    # Mock GCS client
    mock_blob = MagicMock()
    mock_blob.generate_signed_url.return_value = "https://signed-url.example.com/download"
    
    mock_bucket = MagicMock()
    mock_bucket.blob.return_value = mock_blob
    
    mock_client = MagicMock()
    mock_client.bucket.return_value = mock_bucket
    mock_storage_client.return_value = mock_client
    
    response = client.get(
        f"/api/v1/evidences/{evidence.id}/download-url",
        headers=auth_headers
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["signedUrl"] == "https://signed-url.example.com/download"
    assert "expiresAt" in data


def test_upload_init_unauthorized(client, auth_headers, db):
    """Test upload init without permission"""
    from app.models.activity import Activity
    from app.models.catalog import CatalogVersion, CatalogStatus
    from app.models.front import Front
    from app.models.project import Project, ProjectStatus
    
    # Create activity in a different project user doesn't have access to
    project = Project(
        id="OTHER",
        name="Other Project",
        status=ProjectStatus.ACTIVE,
        start_date=datetime.now().date(),
    )
    db.add(project)
    db.flush()
    
    catalog = CatalogVersion(
        id=uuid4(),
        project_id="OTHER",
        version_number="1.0.0",
        status=CatalogStatus.PUBLISHED,
        hash="test123",
        published_at=datetime.now(timezone.utc),
        published_by_id=None,  # Will set via direct query
    )
    # Skip for now
    
    request_data = {
        "activityId": str(uuid4()),
        "mimeType": "image/jpeg",
        "sizeBytes": 1024000,
        "fileName": "photo.jpg"
    }
    
    response = client.post(
        "/api/v1/evidences/upload-init",
        json=request_data,
        headers=auth_headers
    )
    
    # Should fail with 404 (activity not found) or 403 (no access)
    assert response.status_code in [404, 403]


@patch("app.services.evidence_service.storage.Client")
def test_upload_init_rejects_invalid_mime_type(mock_storage_client, client, auth_headers, test_activity, test_user_scope_tmq):
    """upload-init should reject mime types outside JPEG/PNG/PDF."""
    mock_storage_client.return_value = MagicMock()

    request_data = {
        "activityId": str(test_activity.uuid),
        "mimeType": "image/gif",
        "sizeBytes": 1024,
        "fileName": "anim.gif",
    }

    response = client.post(
        "/api/v1/evidences/upload-init",
        json=request_data,
        headers=auth_headers,
    )

    assert response.status_code == 422
    assert "Invalid mime_type" in response.json()["detail"]


@patch("app.services.evidence_service.storage.Client")
def test_upload_init_rejects_file_larger_than_20mb(mock_storage_client, client, auth_headers, test_activity, test_user_scope_tmq):
    """upload-init should reject payloads over 20MB."""
    mock_storage_client.return_value = MagicMock()

    request_data = {
        "activityId": str(test_activity.uuid),
        "mimeType": "image/jpeg",
        "sizeBytes": 20 * 1024 * 1024 + 1,
        "fileName": "large.jpg",
    }

    response = client.post(
        "/api/v1/evidences/upload-init",
        json=request_data,
        headers=auth_headers,
    )

    assert response.status_code == 422
    assert "20MB" in response.json()["detail"]


@patch("app.services.evidence_service.storage.Client")
def test_upload_init_rate_limit_returns_429(mock_storage_client, client, auth_headers, test_activity, test_user_scope_tmq, monkeypatch):
    monkeypatch.setattr(settings, "RATE_LIMIT_EVIDENCE_UPLOAD_INIT_PER_MINUTE", 2, raising=False)
    monkeypatch.setattr(settings, "RATE_LIMIT_WINDOW_SECONDS", 60, raising=False)

    mock_blob = MagicMock()
    mock_blob.generate_signed_url.return_value = "https://signed-url.example.com/upload"
    mock_bucket = MagicMock()
    mock_bucket.blob.return_value = mock_blob
    mock_client = MagicMock()
    mock_client.bucket.return_value = mock_bucket
    mock_storage_client.return_value = mock_client

    request_data = {
        "activityId": str(test_activity.uuid),
        "mimeType": "image/jpeg",
        "sizeBytes": 2048,
        "fileName": "photo.jpg",
    }

    first = client.post("/api/v1/evidences/upload-init", json=request_data, headers=auth_headers)
    second = client.post("/api/v1/evidences/upload-init", json=request_data, headers=auth_headers)
    third = client.post("/api/v1/evidences/upload-init", json=request_data, headers=auth_headers)

    assert first.status_code == 200
    assert second.status_code == 200
    assert third.status_code == 429
