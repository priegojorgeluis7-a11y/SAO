"""Tests for catalog versions endpoints."""

from datetime import datetime, timezone
from uuid import uuid4

import pytest

pytestmark = pytest.mark.integration

from app.models.catalog import CatalogStatus, CatalogVersion
from app.models.project import Project, ProjectStatus
from app.models.role import Role
from app.models.user_role_scope import UserRoleScope


def _ensure_project(db, project_id: str, name: str):
    project = db.query(Project).filter(Project.id == project_id).first()
    if project is None:
        project = Project(
            id=project_id,
            name=name,
            status=ProjectStatus.ACTIVE,
            start_date=datetime.now().date(),
        )
        db.add(project)
        db.commit()
        db.refresh(project)
    return project


def _grant_scope(db, user_id, project_id: str | None = None):
    role = db.query(Role).filter(Role.name == "TEST_ROLE").first()
    if role is None:
        role = Role(name="TEST_ROLE", description="Test role")
        db.add(role)
        db.flush()

    scope = UserRoleScope(
        id=uuid4(),
        user_id=user_id,
        role_id=role.id,
        project_id=project_id,
    )
    db.add(scope)
    db.commit()


def test_catalog_versions_project_ids_returns_digest_map(client, db, test_user, auth_headers):
    _ensure_project(db, "TMQ", "Proyecto TMQ")
    _ensure_project(db, "TAP", "Proyecto TAP")
    _grant_scope(db, test_user.id, None)

    tmq_catalog = CatalogVersion(
        id=uuid4(),
        project_id="TMQ",
        version_number="1.2.3",
        status=CatalogStatus.PUBLISHED,
        hash="hash-tmq-123",
        published_at=datetime.now(timezone.utc),
        published_by_id=test_user.id,
    )
    db.add(tmq_catalog)
    db.commit()

    response = client.get(
        "/api/v1/catalog/versions?project_ids=TMQ,TAP",
        headers=auth_headers,
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["TMQ"]["version_id"] == str(tmq_catalog.id)
    assert payload["TMQ"]["version_number"] == "1.2.3"
    assert payload["TMQ"]["hash"] == "hash-tmq-123"
    assert payload["TAP"]["version_id"] is None
    assert payload["TAP"]["hash"] is None


def test_catalog_versions_requires_project_selector(client, auth_headers):
    response = client.get("/api/v1/catalog/versions", headers=auth_headers)
    assert response.status_code == 400
    assert "project_id or project_ids" in response.json()["detail"]
