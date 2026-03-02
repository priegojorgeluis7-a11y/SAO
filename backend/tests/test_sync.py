"""Tests for sync endpoints"""
import pytest
from datetime import datetime, timezone
from uuid import uuid4

from app.models.project import Project, ProjectStatus
from app.models.front import Front
from app.models.catalog import CatalogVersion, CatalogStatus
from app.models.role import Role
from app.models.user_role_scope import UserRoleScope


def _build_activity_payload(
    *,
    project_id: str,
    front_id: str,
    created_by_user_id: str,
    catalog_version_id: str,
    pk_start: int,
    pk_end: int,
    activity_uuid: str | None = None,
    title: str = "Test Activity",
    execution_state: str = "PENDIENTE",
    description: str | None = None,
    latitude: str | None = None,
    longitude: str | None = None,
    deleted_at=None,
):
    """Build a valid activity payload for activities or sync endpoints."""
    return {
        "uuid": activity_uuid or str(uuid4()),
        "project_id": project_id,
        "front_id": front_id,
        "pk_start": pk_start,
        "pk_end": pk_end,
        "execution_state": execution_state,
        "assigned_to_user_id": None,
        "created_by_user_id": created_by_user_id,
        "catalog_version_id": catalog_version_id,
        "activity_type_code": "INSP_CIVIL",
        "title": title,
        "description": description,
        "latitude": latitude,
        "longitude": longitude,
        "deleted_at": deleted_at,
    }


def _push_request(project_id: str, activity_payload: dict) -> dict:
    """Build sync push request body for a single activity item."""
    return {"project_id": project_id, "activities": [activity_payload]}


@pytest.fixture
def test_role(db):
    """Create test role"""
    role = Role(
        id=99,
        name="TEST_ROLE",
        description="Test role for sync tests"
    )
    db.add(role)
    db.commit()
    db.refresh(role)
    return role


@pytest.fixture
def test_project_tmq(db):
    """Create test project TMQ"""
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
def test_user_scope_tmq(db, test_user, test_role, test_project_tmq):
    """Grant test user access to TMQ project"""
    scope = UserRoleScope(
        id=uuid4(),
        user_id=test_user.id,
        role_id=test_role.id,
        project_id=test_project_tmq.id,
    )
    db.add(scope)
    db.commit()
    db.refresh(scope)
    return scope


@pytest.fixture
def test_front_tmq(db, test_project_tmq):
    """Create test front for TMQ project"""
    front = Front(
        id=uuid4(),
        code="F1",
        name="Front 1",
        project_id=test_project_tmq.id,
        pk_start=0,
        pk_end=50000,
    )
    db.add(front)
    db.commit()
    db.refresh(front)
    return front


@pytest.fixture
def test_catalog_tmq(db, test_user, test_project_tmq):
    """Create test catalog for TMQ project"""
    catalog = CatalogVersion(
        id=uuid4(),
        project_id=test_project_tmq.id,
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


def test_sync_pull_basic(client, auth_headers, test_project_tmq, test_front_tmq, test_catalog_tmq, test_user, test_user_scope_tmq):
    """Test basic sync pull functionality"""
    # Create 3 activities
    activity_uuids = []
    for i in range(3):
        activity_data = _build_activity_payload(
            project_id=test_project_tmq.id,
            front_id=str(test_front_tmq.id),
            created_by_user_id=str(test_user.id),
            catalog_version_id=str(test_catalog_tmq.id),
            pk_start=10000 + (i * 1000),
            pk_end=10500 + (i * 1000),
            title=f"Activity {i}",
        )
        response = client.post("/api/v1/activities", json=activity_data, headers=auth_headers)
        assert response.status_code == 201
        activity_uuids.append(response.json()["uuid"])
    
    # Pull all activities (since_version = 0)
    pull_request = {
        "project_id": test_project_tmq.id,
        "since_version": 0,
        "limit": 500
    }
    response = client.post("/api/v1/sync/pull", json=pull_request, headers=auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    assert "current_version" in data
    assert "activities" in data
    assert len(data["activities"]) == 3
    assert data["current_version"] == 1  # All activities start at sync_version 1
    
    # Verify activities are in ascending sync_version order
    for activity in data["activities"]:
        assert activity["sync_version"] == 1
        assert activity["deleted_at"] is None


def test_sync_pull_with_updates_and_deletes(client, auth_headers, test_project_tmq, test_front_tmq, test_catalog_tmq, test_user, test_user_scope_tmq):
    """Test sync pull after updates and deletes"""
    # Create 3 activities
    activity_uuids = []
    for i in range(3):
        activity_data = _build_activity_payload(
            project_id=test_project_tmq.id,
            front_id=str(test_front_tmq.id),
            created_by_user_id=str(test_user.id),
            catalog_version_id=str(test_catalog_tmq.id),
            pk_start=20000 + (i * 1000),
            pk_end=20500 + (i * 1000),
            title=f"Activity {i}",
        )
        response = client.post("/api/v1/activities", json=activity_data, headers=auth_headers)
        assert response.status_code == 201
        activity_uuids.append(response.json()["uuid"])
    
    # Pull initial state (all 3 activities with sync_version = 1)
    pull_request = {
        "project_id": test_project_tmq.id,
        "since_version": 0,
        "limit": 500
    }
    response = client.post("/api/v1/sync/pull", json=pull_request, headers=auth_headers)
    assert response.status_code == 200
    initial_data = response.json()
    assert len(initial_data["activities"]) == 3
    assert initial_data["current_version"] == 1
    
    # Update first activity (sync_version becomes 2)
    update_data = {"execution_state": "EN_CURSO", "title": "Updated Activity 0"}
    response = client.put(f"/api/v1/activities/{activity_uuids[0]}", json=update_data, headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["sync_version"] == 2
    
    # Delete second activity (sync_version becomes 2)
    response = client.delete(f"/api/v1/activities/{activity_uuids[1]}", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["sync_version"] == 2
    assert response.json()["deleted_at"] is not None
    
    # Pull changes since version 1 (should return 2 activities: updated and deleted)
    pull_request = {
        "project_id": test_project_tmq.id,
        "since_version": 1,
        "limit": 500
    }
    response = client.post("/api/v1/sync/pull", json=pull_request, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    
    # Should return 2 activities with sync_version > 1
    assert len(data["activities"]) == 2
    assert data["current_version"] == 2
    
    # Verify activities are in ascending sync_version order
    assert all(act["sync_version"] == 2 for act in data["activities"])
    
    # Verify one is updated and one is deleted
    updated_activity = next((a for a in data["activities"] if a["uuid"] == activity_uuids[0]), None)
    deleted_activity = next((a for a in data["activities"] if a["uuid"] == activity_uuids[1]), None)
    
    assert updated_activity is not None
    assert updated_activity["execution_state"] == "EN_CURSO"
    assert updated_activity["title"] == "Updated Activity 0"
    assert updated_activity["deleted_at"] is None
    
    assert deleted_activity is not None
    assert deleted_activity["deleted_at"] is not None  # Soft deleted


def test_sync_pull_empty_result(client, auth_headers, test_project_tmq, test_user_scope_tmq):
    """Test sync pull when no activities match"""
    # Pull with since_version = 100 (no activities have this version)
    pull_request = {
        "project_id": test_project_tmq.id,
        "since_version": 100,
        "limit": 500
    }
    response = client.post("/api/v1/sync/pull", json=pull_request, headers=auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    assert len(data["activities"]) == 0
    assert data["current_version"] == 100  # Should return since_version when no results


def test_sync_pull_limit(client, auth_headers, test_project_tmq, test_front_tmq, test_catalog_tmq, test_user, test_user_scope_tmq):
    """Test sync pull respects limit parameter"""
    # Create 5 activities
    for i in range(5):
        activity_data = _build_activity_payload(
            project_id=test_project_tmq.id,
            front_id=str(test_front_tmq.id),
            created_by_user_id=str(test_user.id),
            catalog_version_id=str(test_catalog_tmq.id),
            pk_start=30000 + (i * 1000),
            pk_end=30500 + (i * 1000),
            title=f"Activity {i}",
        )
        response = client.post("/api/v1/activities", json=activity_data, headers=auth_headers)
        assert response.status_code == 201
    
    # Pull with limit = 3
    pull_request = {
        "project_id": test_project_tmq.id,
        "since_version": 0,
        "limit": 3
    }
    response = client.post("/api/v1/sync/pull", json=pull_request, headers=auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    assert len(data["activities"]) == 3  # Respects limit


def test_sync_pull_requires_auth(client, test_project_tmq):
    """Test that sync pull requires authentication"""
    pull_request = {
        "project_id": test_project_tmq.id,
        "since_version": 0,
        "limit": 500
    }
    response = client.post("/api/v1/sync/pull", json=pull_request)
    
    assert response.status_code == 401  # Unauthorized


def test_sync_pull_ascending_order(client, auth_headers, test_project_tmq, test_front_tmq, test_catalog_tmq, test_user, test_user_scope_tmq):
    """Test that activities are returned in ascending sync_version order"""
    # Create 3 activities
    activity_uuids = []
    for i in range(3):
        activity_data = {
            "uuid": str(uuid4()),
            "project_id": test_project_tmq.id,
            "front_id": str(test_front_tmq.id),
            "pk_start": 40000 + (i * 1000),
            "pk_end": 40500 + (i * 1000),
            "execution_state": "PENDIENTE",
            "assigned_to_user_id": None,
            "created_by_user_id": str(test_user.id),
            "catalog_version_id": str(test_catalog_tmq.id),
            "activity_type_code": "INSP_CIVIL",
            "title": f"Activity {i}",
        }
        response = client.post("/api/v1/activities", json=activity_data, headers=auth_headers)
        assert response.status_code == 201
        activity_uuids.append(response.json()["uuid"])
    
    # Update activities in different order to create different sync_versions
    # Update activity 2 (becomes sync_version 2)
    response = client.put(f"/api/v1/activities/{activity_uuids[2]}", json={"title": "Updated 2"}, headers=auth_headers)
    assert response.status_code == 200
    
    # Update activity 0 (becomes sync_version 2)
    response = client.put(f"/api/v1/activities/{activity_uuids[0]}", json={"title": "Updated 0"}, headers=auth_headers)
    assert response.status_code == 200
    
    # Update activity 1 (becomes sync_version 2)
    response = client.put(f"/api/v1/activities/{activity_uuids[1]}", json={"title": "Updated 1"}, headers=auth_headers)
    assert response.status_code == 200
    
    # Pull all changes since version 1
    pull_request = {
        "project_id": test_project_tmq.id,
        "since_version": 1,
        "limit": 500
    }
    response = client.post("/api/v1/sync/pull", json=pull_request, headers=auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    assert len(data["activities"]) == 3
    
    # Verify ascending order by sync_version
    sync_versions = [act["sync_version"] for act in data["activities"]]
    assert sync_versions == sorted(sync_versions)  # Should be in ascending order


def test_sync_push_new_activity(client, auth_headers, test_project_tmq, test_front_tmq, test_catalog_tmq, test_user, test_user_scope_tmq):
    """Test pushing a new activity returns CREATED status"""
    activity_uuid = str(uuid4())

    activity_payload = _build_activity_payload(
        project_id=test_project_tmq.id,
        front_id=str(test_front_tmq.id),
        created_by_user_id=str(test_user.id),
        catalog_version_id=str(test_catalog_tmq.id),
        activity_uuid=activity_uuid,
        pk_start=50000,
        pk_end=50500,
        title="New Activity",
        description="Test description",
    )
    activity_payload["server_id"] = None
    push_request = _push_request(test_project_tmq.id, activity_payload)
    
    response = client.post("/api/v1/sync/push", json=push_request, headers=auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    assert "results" in data
    assert len(data["results"]) == 1
    
    result = data["results"][0]
    assert result["uuid"] == activity_uuid
    assert result["status"] == "CREATED"
    assert result["server_id"] is not None  # Server assigned an ID
    assert result["sync_version"] == 1  # New activities start at sync_version 1


def test_sync_push_unchanged_activity(client, auth_headers, test_project_tmq, test_front_tmq, test_catalog_tmq, test_user, test_user_scope_tmq):
    """Test pushing an identical activity returns UNCHANGED status"""
    activity_uuid = str(uuid4())

    activity_payload = _build_activity_payload(
        project_id=test_project_tmq.id,
        front_id=str(test_front_tmq.id),
        created_by_user_id=str(test_user.id),
        catalog_version_id=str(test_catalog_tmq.id),
        activity_uuid=activity_uuid,
        pk_start=60000,
        pk_end=60500,
        title="Unchanged Activity",
        description="Test description",
    )
    activity_payload["server_id"] = None
    push_request = _push_request(test_project_tmq.id, activity_payload)
    
    response = client.post("/api/v1/sync/push", json=push_request, headers=auth_headers)
    assert response.status_code == 200
    first_result = response.json()["results"][0]
    assert first_result["status"] == "CREATED"
    server_id = first_result["server_id"]
    
    # Second push: push same activity with identical data
    push_request["activities"][0]["server_id"] = server_id
    
    response = client.post("/api/v1/sync/push", json=push_request, headers=auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    assert len(data["results"]) == 1
    
    result = data["results"][0]
    assert result["uuid"] == activity_uuid
    assert result["status"] == "UNCHANGED"
    assert result["server_id"] == server_id
    assert result["sync_version"] == 1  # Should NOT increment for unchanged


def test_sync_push_updated_activity(client, auth_headers, test_project_tmq, test_front_tmq, test_catalog_tmq, test_user, test_user_scope_tmq):
    """Test pushing an updated activity returns UPDATED and increments sync_version"""
    activity_uuid = str(uuid4())

    activity_payload = _build_activity_payload(
        project_id=test_project_tmq.id,
        front_id=str(test_front_tmq.id),
        created_by_user_id=str(test_user.id),
        catalog_version_id=str(test_catalog_tmq.id),
        activity_uuid=activity_uuid,
        pk_start=70000,
        pk_end=70500,
        title="Original Title",
        description="Original description",
    )
    activity_payload["server_id"] = None
    push_request = _push_request(test_project_tmq.id, activity_payload)
    
    response = client.post("/api/v1/sync/push", json=push_request, headers=auth_headers)
    assert response.status_code == 200
    first_result = response.json()["results"][0]
    assert first_result["status"] == "CREATED"
    assert first_result["sync_version"] == 1
    server_id = first_result["server_id"]
    
    # Second push: update execution_state
    push_request["activities"][0]["server_id"] = server_id
    push_request["activities"][0]["execution_state"] = "EN_CURSO"
    push_request["activities"][0]["title"] = "Updated Title"
    
    response = client.post("/api/v1/sync/push", json=push_request, headers=auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    assert len(data["results"]) == 1
    
    result = data["results"][0]
    assert result["uuid"] == activity_uuid
    assert result["status"] == "UPDATED"
    assert result["server_id"] == server_id
    assert result["sync_version"] == 2  # Should increment from 1 to 2


def test_sync_push_conflict_deleted_activity(client, auth_headers, test_project_tmq, test_front_tmq, test_catalog_tmq, test_user, test_user_scope_tmq):
    """Test pushing an update for a deleted activity returns CONFLICT"""
    activity_uuid = str(uuid4())
    
    # Create activity via activities endpoint
    activity_data = {
        "uuid": activity_uuid,
        "project_id": test_project_tmq.id,
        "front_id": str(test_front_tmq.id),
        "pk_start": 80000,
        "pk_end": 80500,
        "execution_state": "PENDIENTE",
        "assigned_to_user_id": None,
        "created_by_user_id": str(test_user.id),
        "catalog_version_id": str(test_catalog_tmq.id),
        "activity_type_code": "INSP_CIVIL",
        "title": "To Be Deleted",
    }
    response = client.post("/api/v1/activities", json=activity_data, headers=auth_headers)
    assert response.status_code == 201
    
    # Delete the activity
    response = client.delete(f"/api/v1/activities/{activity_uuid}", headers=auth_headers)
    assert response.status_code == 200
    deleted_data = response.json()
    assert deleted_data["deleted_at"] is not None
    server_id = deleted_data["server_id"]
    sync_version_after_delete = deleted_data["sync_version"]
    
    # Try to push an update for the deleted activity
    push_request = {
        "project_id": test_project_tmq.id,
        "activities": [
            {
                "uuid": activity_uuid,
                "server_id": server_id,
                "project_id": test_project_tmq.id,
                "front_id": str(test_front_tmq.id),
                "pk_start": 80000,
                "pk_end": 80500,
                "execution_state": "EN_CURSO",  # Trying to update
                "assigned_to_user_id": None,
                "created_by_user_id": str(test_user.id),
                "catalog_version_id": str(test_catalog_tmq.id),
                "activity_type_code": "INSP_CIVIL",
                "title": "Updated After Delete",
                "description": None,
                "latitude": None,
                "longitude": None,
                "deleted_at": None,  # Client doesn't know it's deleted
            }
        ]
    }
    
    response = client.post("/api/v1/sync/push", json=push_request, headers=auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    assert len(data["results"]) == 1
    
    result = data["results"][0]
    assert result["uuid"] == activity_uuid
    assert result["status"] == "CONFLICT"  # Cannot update deleted activity
    assert result["server_id"] == server_id
    assert result["sync_version"] == sync_version_after_delete  # Unchanged


def test_sync_push_requires_auth(client, test_project_tmq, test_front_tmq, test_catalog_tmq, test_user):
    """Test that sync push requires authentication"""
    push_request = {
        "project_id": test_project_tmq.id,
        "activities": [
            {
                "uuid": str(uuid4()),
                "server_id": None,
                "project_id": test_project_tmq.id,
                "front_id": str(test_front_tmq.id),
                "pk_start": 90000,
                "pk_end": 90500,
                "execution_state": "PENDIENTE",
                "assigned_to_user_id": None,
                "created_by_user_id": str(test_user.id),
                "catalog_version_id": str(test_catalog_tmq.id),
                "activity_type_code": "INSP_CIVIL",
                "title": "Test",
                "description": None,
                "latitude": None,
                "longitude": None,
                "deleted_at": None,
            }
        ]
    }
    
    response = client.post("/api/v1/sync/push", json=push_request)
    
    assert response.status_code == 401  # Unauthorized


def test_sync_pull_project_access_denied(client, auth_headers, test_project_tmq):
    """Test that sync pull denies access when user has no scope for project"""
    # Note: test_user does NOT have test_user_scope_tmq, so no access to TMQ project
    pull_request = {
        "project_id": test_project_tmq.id,
        "since_version": 0,
        "limit": 500
    }
    
    response = client.post("/api/v1/sync/pull", json=pull_request, headers=auth_headers)
    
    assert response.status_code == 403  # Forbidden
    assert "does not have access to project" in response.json()["detail"]


def test_sync_push_project_access_denied(client, auth_headers, test_project_tmq, test_front_tmq, test_catalog_tmq, test_user):
    """Test that sync push denies access when user has no scope for project"""
    # Note: test_user does NOT have test_user_scope_tmq, so no access to TMQ project
    push_request = {
        "project_id": test_project_tmq.id,
        "activities": [
            {
                "uuid": str(uuid4()),
                "server_id": None,
                "project_id": test_project_tmq.id,
                "front_id": str(test_front_tmq.id),
                "pk_start": 90000,
                "pk_end": 90500,
                "execution_state": "PENDIENTE",
                "assigned_to_user_id": None,
                "created_by_user_id": str(test_user.id),
                "catalog_version_id": str(test_catalog_tmq.id),
                "activity_type_code": "INSP_CIVIL",
                "title": "Test",
                "description": None,
                "latitude": None,
                "longitude": None,
                "deleted_at": None,
            }
        ]
    }
    
    response = client.post("/api/v1/sync/push", json=push_request, headers=auth_headers)
    
    assert response.status_code == 403  # Forbidden
    assert "does not have access to project" in response.json()["detail"]


def test_sync_pull_with_until_version(client, auth_headers, test_project_tmq, test_front_tmq, test_catalog_tmq, test_user, test_user_scope_tmq):
    """Test sync pull with until_version parameter"""
    # Create 3 activities (all at sync_version=1)
    activity_uuids = []
    for i in range(3):
        activity_data = {
            "uuid": str(uuid4()),
            "project_id": test_project_tmq.id,
            "front_id": str(test_front_tmq.id),
            "pk_start": 100000 + (i * 1000),
            "pk_end": 100500 + (i * 1000),
            "execution_state": "PENDIENTE",
            "assigned_to_user_id": None,
            "created_by_user_id": str(test_user.id),
            "catalog_version_id": str(test_catalog_tmq.id),
            "activity_type_code": "INSP_CIVIL",
            "title": f"Activity {i}",
        }
        response = client.post("/api/v1/activities", json=activity_data, headers=auth_headers)
        assert response.status_code == 201
        activity_uuids.append(response.json()["uuid"])
    
    # Update first activity (sync_version becomes 2)
    response = client.put(f"/api/v1/activities/{activity_uuids[0]}", json={"title": "Updated 0"}, headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["sync_version"] == 2
    
    # Update second activity (sync_version becomes 2)
    response = client.put(f"/api/v1/activities/{activity_uuids[1]}", json={"title": "Updated 1"}, headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["sync_version"] == 2
    
    # Pull with until_version=1 (should only get activity that hasn't been updated)
    pull_request = {
        "project_id": test_project_tmq.id,
        "since_version": 0,
        "until_version": 1,
        "limit": 500
    }
    response = client.post("/api/v1/sync/pull", json=pull_request, headers=auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    assert len(data["activities"]) == 1  # Only activity with sync_version=1
    assert data["activities"][0]["uuid"] == activity_uuids[2]  # Third activity unchanged
    assert data["activities"][0]["sync_version"] == 1
    assert data["current_version"] == 1
    
    # Pull with until_version=2 (should get all 3)
    pull_request = {
        "project_id": test_project_tmq.id,
        "since_version": 0,
        "until_version": 2,
        "limit": 500
    }
    response = client.post("/api/v1/sync/pull", json=pull_request, headers=auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    assert len(data["activities"]) == 3
    assert data["current_version"] == 2
    
    # Verify sync_versions: 1 unchanged, 2 updated
    sync_versions = [act["sync_version"] for act in data["activities"]]
    assert sync_versions.count(1) == 1
    assert sync_versions.count(2) == 2
