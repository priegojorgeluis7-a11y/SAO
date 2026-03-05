"""Tests for activities CRUD endpoints"""
import pytest
from datetime import datetime, timezone
import json
from uuid import uuid4

from app.models.audit_log import AuditLog
from app.models.catalog import CATActivityType, CatalogStatus, CatalogVersion
from app.models.front import Front
from app.models.project import Project, ProjectStatus


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
        id=uuid4(),  # Generate UUID
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
    db.flush()
    db.add(
        CATActivityType(
            id=uuid4(),
            version_id=catalog.id,
            code="INSP_CIVIL",
            name="Inspeccion civil",
            is_active=True,
        )
    )
    db.commit()
    db.refresh(catalog)
    return catalog


@pytest.fixture
def sample_activity_data(test_project, test_front, test_catalog, test_user):
    """Sample activity data for creation"""
    return {
        "uuid": str(uuid4()),
        "project_id": test_project.id,
        "front_id": str(test_front.id),
        "pk_start": 10000,
        "pk_end": 10500,
        "execution_state": "PENDIENTE",
        "assigned_to_user_id": None,
        "created_by_user_id": str(test_user.id),
        "catalog_version_id": str(test_catalog.id),
        "activity_type_code": "INSP_CIVIL",
        "latitude": "19.4326",
        "longitude": "-99.1332",
        "title": "Test Activity",
        "description": "Test Description",
    }


def test_create_activity(client, auth_headers, sample_activity_data):
    """Test creating a new activity"""
    response = client.post(
        "/api/v1/activities",
        json=sample_activity_data,
        headers=auth_headers
    )
    
    assert response.status_code == 201
    data = response.json()
    assert data["uuid"] == sample_activity_data["uuid"]
    assert data["project_id"] == sample_activity_data["project_id"]
    assert data["pk_start"] == sample_activity_data["pk_start"]
    assert data["pk_end"] == sample_activity_data["pk_end"]
    assert data["execution_state"] == "PENDIENTE"
    assert data["sync_version"] == 1  # Starts at 1 on create
    assert data["deleted_at"] is None
    assert "server_id" in data
    assert data["server_id"] is not None
    assert "flags" in data
    assert isinstance(data["flags"], dict)
    assert "gps_mismatch" in data["flags"]
    assert "catalog_changed" in data["flags"]


def test_create_activity_idempotent(client, auth_headers, sample_activity_data):
    """Test that creating activity with same uuid is idempotent"""
    # Create first time
    response1 = client.post(
        "/api/v1/activities",
        json=sample_activity_data,
        headers=auth_headers
    )
    assert response1.status_code == 201
    data1 = response1.json()
    
    # Create second time with same uuid
    response2 = client.post(
        "/api/v1/activities",
        json=sample_activity_data,
        headers=auth_headers
    )
    assert response2.status_code == 200  # Returns existing (not 201)
    data2 = response2.json()
    
    # Should return same activity
    assert data2["uuid"] == data1["uuid"]
    assert data2["server_id"] == data1["server_id"]
    assert data2["sync_version"] == data1["sync_version"]


def test_list_activities(client, auth_headers, sample_activity_data):
    """Test listing activities"""
    # Create test activity
    client.post("/api/v1/activities", json=sample_activity_data, headers=auth_headers)
    
    # List activities
    response = client.get("/api/v1/activities", headers=auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    assert "items" in data
    assert "total" in data
    assert "page" in data
    assert "page_size" in data
    assert "has_next" in data
    assert data["total"] >= 1
    assert len(data["items"]) >= 1


def test_list_activities_with_filters(client, auth_headers, sample_activity_data, test_project):
    """Test listing activities with filters"""
    # Create test activity
    client.post("/api/v1/activities", json=sample_activity_data, headers=auth_headers)
    
    # Filter by project
    response = client.get(
        f"/api/v1/activities?project_id={test_project.id}",
        headers=auth_headers
    )
    assert response.status_code == 200
    data = response.json()
    assert data["total"] >= 1
    assert all(item["project_id"] == test_project.id for item in data["items"])
    
    # Filter by execution_state
    response = client.get(
        "/api/v1/activities?execution_state=PENDIENTE",
        headers=auth_headers
    )
    assert response.status_code == 200
    data = response.json()
    assert all(item["execution_state"] == "PENDIENTE" for item in data["items"])


def test_list_activities_with_sync_version(client, auth_headers, sample_activity_data):
    """Test incremental sync using updated_since_sync_version"""
    # Create activity
    response = client.post("/api/v1/activities", json=sample_activity_data, headers=auth_headers)
    activity_uuid = response.json()["uuid"]
    
    # List all (sync_version = 0)
    response = client.get("/api/v1/activities", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["total"] >= 1
    
    # Update activity (increments sync_version)
    client.put(
        f"/api/v1/activities/{activity_uuid}",
        json={"execution_state": "EN_CURSO"},
        headers=auth_headers
    )
    
    # List activities updated after sync_version=0
    response = client.get(
        "/api/v1/activities?updated_since_sync_version=0",
        headers=auth_headers
    )
    assert response.status_code == 200
    data = response.json()
    assert data["total"] >= 1
    assert all(item["sync_version"] > 0 for item in data["items"])


def test_get_activity_by_uuid(client, auth_headers, sample_activity_data):
    """Test getting activity by uuid"""
    # Create activity
    create_response = client.post(
        "/api/v1/activities",
        json=sample_activity_data,
        headers=auth_headers
    )
    uuid = create_response.json()["uuid"]
    
    # Get activity
    response = client.get(f"/api/v1/activities/{uuid}", headers=auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    assert data["uuid"] == uuid
    assert data["project_id"] == sample_activity_data["project_id"]


def test_get_activity_not_found(client, auth_headers):
    """Test getting non-existent activity"""
    fake_uuid = str(uuid4())
    response = client.get(f"/api/v1/activities/{fake_uuid}", headers=auth_headers)
    
    assert response.status_code == 404
    assert "not found" in response.json()["detail"].lower()


def test_update_activity(client, auth_headers, sample_activity_data):
    """Test updating activity"""
    # Create activity
    create_response = client.post(
        "/api/v1/activities",
        json=sample_activity_data,
        headers=auth_headers
    )
    uuid = create_response.json()["uuid"]
    # Update activity
    update_data = {
        "execution_state": "EN_CURSO",
        "title": "Updated Title"
    }
    response = client.put(
        f"/api/v1/activities/{uuid}",
        json=update_data,
        headers=auth_headers
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["execution_state"] == "EN_CURSO"
    assert data["title"] == "Updated Title"
    assert data["sync_version"] == 2  # Incremented from 1 to 2


def test_update_increments_sync_version(client, auth_headers, sample_activity_data):
    """Test that updating activity increments sync_version"""
    # Create activity
    create_response = client.post(
        "/api/v1/activities",
        json=sample_activity_data,
        headers=auth_headers
    )
    uuid = create_response.json()["uuid"]
    
    # Update multiple times
    for i in range(3):
        response = client.put(
            f"/api/v1/activities/{uuid}",
            json={"title": f"Update {i}"},
            headers=auth_headers
        )
        assert response.status_code == 200
        # sync_version starts at 1, so after i updates: 1, 2, 3, 4
        assert response.json()["sync_version"] == i + 2


def test_delete_activity(client, auth_headers, sample_activity_data):
    """Test soft deleting activity"""
    # Create activity
    create_response = client.post(
        "/api/v1/activities",
        json=sample_activity_data,
        headers=auth_headers
    )
    uuid = create_response.json()["uuid"]
    # Delete activity
    response = client.delete(f"/api/v1/activities/{uuid}", headers=auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    assert data["deleted_at"] is not None
    assert data["sync_version"] == 2  # Incremented from 1 to 2 on delete
    
    # Verify activity no longer appears in default list
    list_response = client.get("/api/v1/activities", headers=auth_headers)
    activities = list_response.json()["items"]
    assert not any(a["uuid"] == uuid for a in activities)


def test_delete_sets_deleted_at_and_increments_sync(client, auth_headers, sample_activity_data):
    """Test that delete sets deleted_at and increments sync_version"""
    # Create activity
    create_response = client.post(
        "/api/v1/activities",
        json=sample_activity_data,
        headers=auth_headers
    )
    uuid = create_response.json()["uuid"]
    
    # Delete
    response = client.delete(f"/api/v1/activities/{uuid}", headers=auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    assert data["deleted_at"] is not None
    assert data["sync_version"] == 2  # Incremented from 1 to 2 on delete
    
    # List with include_deleted=true should show it
    list_response = client.get(
        "/api/v1/activities?include_deleted=true",
        headers=auth_headers
    )
    activities = list_response.json()["items"]
    deleted_activity = next((a for a in activities if a["uuid"] == uuid), None)
    assert deleted_activity is not None
    assert deleted_activity["deleted_at"] is not None


def test_delete_activity_not_found(client, auth_headers):
    """Test deleting non-existent activity"""
    fake_uuid = str(uuid4())
    response = client.delete(f"/api/v1/activities/{fake_uuid}", headers=auth_headers)
    
    assert response.status_code == 404


def test_activity_requires_auth(client, sample_activity_data):
    """Test that all activity endpoints require authentication"""
    # Create without auth
    response = client.post("/api/v1/activities", json=sample_activity_data)
    assert response.status_code == 401
    
    # List without auth
    response = client.get("/api/v1/activities")
    assert response.status_code == 401
    
    # Get without auth
    response = client.get(f"/api/v1/activities/{uuid4()}")
    assert response.status_code == 401
    
    # Update without auth
    response = client.put(f"/api/v1/activities/{uuid4()}", json={"title": "test"})
    assert response.status_code == 401

    # Delete without auth
    response = client.delete(f"/api/v1/activities/{uuid4()}")
    assert response.status_code == 401


def test_create_activity_rejects_unknown_activity_type_for_catalog(
    client,
    auth_headers,
    sample_activity_data,
):
    sample_activity_data["activity_type_code"] = "NOT_IN_CATALOG"

    response = client.post(
        "/api/v1/activities",
        json=sample_activity_data,
        headers=auth_headers,
    )

    assert response.status_code == 400
    detail = response.json()["detail"]
    assert detail["code"] == "ACTIVITY_TYPE_NOT_IN_CATALOG_VERSION"


def test_create_activity_validates_pk_range(client, auth_headers, sample_activity_data):
    """Test that pk_end must be >= pk_start"""
    invalid_data = sample_activity_data.copy()
    invalid_data["pk_start"] = 10000
    invalid_data["pk_end"] = 5000  # Invalid: pk_end < pk_start
    
    response = client.post(
        "/api/v1/activities",
        json=invalid_data,
        headers=auth_headers
    )
    
    # Should fail validation
    assert response.status_code == 422


def test_activity_timeline_returns_audit_events_desc(client, auth_headers, sample_activity_data, db, test_user):
    create_response = client.post(
        "/api/v1/activities",
        json=sample_activity_data,
        headers=auth_headers,
    )
    assert create_response.status_code == 201
    activity_uuid = create_response.json()["uuid"]

    older = AuditLog(
        actor_id=test_user.id,
        actor_email=test_user.email,
        action="REVIEW_REJECT",
        entity="activity",
        entity_id=activity_uuid,
        details_json=json.dumps({"reason": "missing_info"}),
    )
    newer = AuditLog(
        actor_id=test_user.id,
        actor_email=test_user.email,
        action="REVIEW_APPROVE",
        entity="activity",
        entity_id=activity_uuid,
        details_json=json.dumps({"ok": True}),
    )
    db.add(older)
    db.flush()
    db.add(newer)
    db.commit()

    response = client.get(f"/api/v1/activities/{activity_uuid}/timeline", headers=auth_headers)
    assert response.status_code == 200
    payload = response.json()
    assert isinstance(payload, list)
    assert len(payload) >= 2
    assert payload[0]["action"] == "REVIEW_APPROVE"
    assert payload[1]["action"] == "REVIEW_REJECT"
    assert payload[0]["actor"] == test_user.email


def test_activity_timeline_not_found(client, auth_headers):
    fake_uuid = str(uuid4())
    response = client.get(f"/api/v1/activities/{fake_uuid}/timeline", headers=auth_headers)
    assert response.status_code == 404


def test_patch_flags_sets_gps_mismatch(client, auth_headers, sample_activity_data):
    """PATCH /flags sets gps_mismatch and increments sync_version."""
    create = client.post("/api/v1/activities", json=sample_activity_data, headers=auth_headers)
    assert create.status_code == 201
    uuid = create.json()["uuid"]
    initial_sync = create.json()["sync_version"]

    response = client.patch(
        f"/api/v1/activities/{uuid}/flags",
        json={"gps_mismatch": True},
        headers=auth_headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["flags"]["gps_mismatch"] is True
    assert data["flags"]["catalog_changed"] is False
    assert data["sync_version"] == initial_sync + 1


def test_patch_flags_sets_catalog_changed(client, auth_headers, sample_activity_data):
    """PATCH /flags sets catalog_changed independently."""
    create = client.post("/api/v1/activities", json=sample_activity_data, headers=auth_headers)
    uuid = create.json()["uuid"]

    response = client.patch(
        f"/api/v1/activities/{uuid}/flags",
        json={"catalog_changed": True},
        headers=auth_headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["flags"]["catalog_changed"] is True
    assert data["flags"]["gps_mismatch"] is False


def test_patch_flags_partial_update_leaves_other_unchanged(client, auth_headers, sample_activity_data):
    """PATCH /flags with only one field does not reset the other."""
    create = client.post("/api/v1/activities", json=sample_activity_data, headers=auth_headers)
    uuid = create.json()["uuid"]

    # Set both flags
    client.patch(f"/api/v1/activities/{uuid}/flags",
                 json={"gps_mismatch": True, "catalog_changed": True},
                 headers=auth_headers)

    # Patch only gps_mismatch → catalog_changed should stay True
    response = client.patch(f"/api/v1/activities/{uuid}/flags",
                            json={"gps_mismatch": False},
                            headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["flags"]["gps_mismatch"] is False
    assert data["flags"]["catalog_changed"] is True


def test_patch_flags_not_found(client, auth_headers):
    """PATCH /flags on non-existent uuid returns 404."""
    response = client.patch(
        f"/api/v1/activities/{uuid4()}/flags",
        json={"gps_mismatch": True},
        headers=auth_headers,
    )
    assert response.status_code == 404


def test_patch_flags_requires_auth(client, sample_activity_data):
    """PATCH /flags without token returns 401."""
    response = client.patch(
        f"/api/v1/activities/{uuid4()}/flags",
        json={"gps_mismatch": True},
    )
    assert response.status_code == 401
