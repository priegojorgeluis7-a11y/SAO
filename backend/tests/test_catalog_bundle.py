"""Tests for the sao.catalog.bundle.v1 endpoints:
  GET  /api/v1/catalog/bundle
  PATCH /api/v1/catalog/project-ops
  POST /api/v1/catalog/validate
  POST /api/v1/catalog/publish
  POST /api/v1/catalog/rollback
"""
from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient

from app.api.deps import get_current_user
from app.core.database import get_db
from app.main import app
from app.models.catalog_effective import (
    CatalogVersionCurrent,
    CatActivity,
    CatAttendee,
    CatProject,
    CatPurpose,
    CatResult,
    CatSubcategory,
    CatTopic,
    RelActivityTopic,
)


# ─── fixtures ─────────────────────────────────────────────────────────────────

@pytest.fixture(scope="function")
def auth_client(db, test_user):
    def override_get_db():
        yield db

    def override_get_current_user():
        return test_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user
    client = TestClient(app)
    yield client
    app.dependency_overrides.clear()


def seed_catalog(db, version_id: str = "v1", is_current: bool = True):
    """Minimal catalog seed with all required entities."""
    now = datetime.now(timezone.utc)

    db.add(CatalogVersionCurrent(
        version_id=version_id, is_current=is_current, created_at=now, changelog="test seed"
    ))
    db.add(CatProject(
        project_id="TMQ", name="Tren Mexico Queretaro", version_id=version_id,
        is_active=True, updated_at=now,
    ))
    db.add(CatActivity(
        activity_id="CAM", name="Caminamiento", description="Recorrido de campo",
        version_id=version_id, is_active=True, updated_at=now,
    ))
    db.add(CatActivity(
        activity_id="REU", name="Reunión", description="Coordinación",
        version_id=version_id, is_active=True, updated_at=now,
    ))
    db.add(CatSubcategory(
        subcategory_id="CAM_DDV", activity_id="CAM", name="Verificación de DDV",
        description=None, version_id=version_id, is_active=True, updated_at=now,
    ))
    db.add(CatPurpose(
        purpose_id="AFEC_VER_CAM", activity_id="CAM", subcategory_id="CAM_DDV",
        name="Verificación de afectaciones", version_id=version_id, is_active=True, updated_at=now,
    ))
    db.add(CatTopic(
        topic_id="TOP_GAL", type="Tecnico", name="Gálibos ferroviarios",
        description="Alturas/ancho", version_id=version_id, is_active=True, updated_at=now,
    ))
    db.add(RelActivityTopic(
        activity_id="CAM", topic_id="TOP_GAL", version_id=version_id,
        is_active=True, updated_at=now,
    ))
    db.add(CatResult(
        result_id="R01", name="Actividad realizada", category="Ejecución regular",
        severity_default=None, version_id=version_id, is_active=True, updated_at=now,
    ))
    db.add(CatAttendee(
        attendee_id="AST1", type="Dependencia", name="ARTF",
        description="Agencia Reguladora", version_id=version_id, is_active=True, updated_at=now,
    ))
    db.commit()


# ─── GET /catalog/bundle ──────────────────────────────────────────────────────

def test_bundle_returns_correct_schema(auth_client, db):
    seed_catalog(db)
    r = auth_client.get("/api/v1/catalog/bundle", params={"project_id": "TMQ"})
    assert r.status_code == 200
    data = r.json()
    assert data["schema"] == "sao.catalog.bundle.v1"
    assert data["meta"]["project_id"] == "TMQ"
    assert "etag" in data["meta"]
    assert data["meta"]["etag"].startswith("sha256:")


def test_bundle_has_activities_subcategories_etc(auth_client, db):
    seed_catalog(db)
    r = auth_client.get("/api/v1/catalog/bundle", params={"project_id": "TMQ"})
    assert r.status_code == 200
    effective = r.json()["effective"]
    entities = effective["entities"]
    assert len(entities["activities"]) == 2
    assert any(a["id"] == "CAM" for a in entities["activities"])
    assert any(a["id"] == "REU" for a in entities["activities"])
    assert len(entities["subcategories"]) == 1
    assert entities["subcategories"][0]["id"] == "CAM_DDV"
    assert len(entities["purposes"]) == 1
    assert len(entities["topics"]) == 1
    assert len(entities["results"]) == 1
    assert len(entities["assistants"]) == 1


def test_bundle_activity_fields_use_bundle_spec(auth_client, db):
    """Activities must use 'active' and 'order', not 'is_active'/'sort_order'."""
    seed_catalog(db)
    r = auth_client.get("/api/v1/catalog/bundle", params={"project_id": "TMQ"})
    assert r.status_code == 200
    act = r.json()["effective"]["entities"]["activities"][0]
    assert "active" in act
    assert "order" in act
    assert "is_active" not in act
    assert "sort_order" not in act


def test_bundle_without_editor_has_no_editor_key(auth_client, db):
    seed_catalog(db)
    r = auth_client.get("/api/v1/catalog/bundle", params={"project_id": "TMQ"})
    assert r.status_code == 200
    data = r.json()
    assert "editor" not in data or data["editor"] is None


def test_bundle_with_include_editor_has_layers(auth_client, db):
    seed_catalog(db)
    r = auth_client.get(
        "/api/v1/catalog/bundle",
        params={"project_id": "TMQ", "include_editor": "true"},
    )
    assert r.status_code == 200
    editor = r.json().get("editor")
    assert editor is not None
    assert "layers" in editor
    assert "base" in editor["layers"]
    assert "project" in editor["layers"]
    assert editor["validation"]["status"] == "ok"


def test_bundle_relations_have_active_field(auth_client, db):
    seed_catalog(db)
    r = auth_client.get("/api/v1/catalog/bundle", params={"project_id": "TMQ"})
    assert r.status_code == 200
    rels = r.json()["effective"]["relations"]["activity_to_topics_suggested"]
    assert len(rels) == 1
    assert rels[0]["activity_id"] == "CAM"
    assert rels[0]["topic_id"] == "TOP_GAL"
    assert "active" in rels[0]


def test_catalog_workflow_endpoint_returns_workflow_dict(auth_client, db):
    seed_catalog(db)
    r = auth_client.get("/api/v1/catalog/workflow", params={"project_id": "TMQ"})
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, dict)


def test_bundle_includes_color_tokens_and_form_fields(auth_client, db):
    seed_catalog(db)
    r = auth_client.get("/api/v1/catalog/bundle", params={"project_id": "TMQ"})
    assert r.status_code == 200

    effective = r.json()["effective"]
    assert "color_tokens" in effective
    assert isinstance(effective["color_tokens"], dict)
    assert "form_fields" in effective
    assert isinstance(effective["form_fields"], list)


# ─── PATCH /catalog/project-ops ───────────────────────────────────────────────

def test_project_ops_patch_activity_name(auth_client, db):
    seed_catalog(db)
    r = auth_client.patch(
        "/api/v1/catalog/project-ops",
        params={"project_id": "TMQ"},
        json={"ops": [
            {"op": "patch", "entity": "activities", "id": "CAM",
             "data": {"name": "Caminamiento Editado"}}
        ]},
    )
    assert r.status_code == 200
    activities = r.json()["effective"]["entities"]["activities"]
    cam = next(a for a in activities if a["id"] == "CAM")
    assert cam["name"] == "Caminamiento Editado"


def test_project_ops_deactivate_activity(auth_client, db):
    seed_catalog(db)
    r = auth_client.patch(
        "/api/v1/catalog/project-ops",
        params={"project_id": "TMQ"},
        json={"ops": [
            {"op": "deactivate", "entity": "activities", "id": "REU", "data": {}}
        ]},
    )
    assert r.status_code == 200
    activities = r.json()["effective"]["entities"]["activities"]
    reu = next(a for a in activities if a["id"] == "REU")
    assert reu["active"] is False


# ─── POST /catalog/validate ───────────────────────────────────────────────────

def test_validate_returns_ok_for_clean_catalog(auth_client, db):
    seed_catalog(db)
    r = auth_client.post("/api/v1/catalog/validate", params={"project_id": "TMQ"})
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "ok"
    assert data["issues"] == []


# ─── POST /catalog/publish ────────────────────────────────────────────────────

def test_publish_creates_new_current_version(auth_client, db):
    seed_catalog(db, version_id="v1")
    r = auth_client.post("/api/v1/catalog/publish", params={"project_id": "TMQ"})
    assert r.status_code == 200
    data = r.json()
    assert "version_id" in data
    assert data["status"] == "published"
    assert "TMQ@" in data["version_id"]

    # Only one version should be current
    current_rows = (
        db.query(CatalogVersionCurrent)
        .filter(CatalogVersionCurrent.is_current.is_(True))
        .all()
    )
    assert len(current_rows) == 1
    assert current_rows[0].version_id == data["version_id"]


# ─── POST /catalog/rollback ───────────────────────────────────────────────────

def test_rollback_restores_previous_version(auth_client, db):
    seed_catalog(db, version_id="v-old")
    # Publish to create a new version
    publish_r = auth_client.post("/api/v1/catalog/publish", params={"project_id": "TMQ"})
    assert publish_r.status_code == 200

    # Rollback to v-old
    r = auth_client.post(
        "/api/v1/catalog/rollback",
        params={"project_id": "TMQ"},
        json={"to_effective_version": "v-old"},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["version_id"] == "v-old"

    # v-old should now be current
    row = (
        db.query(CatalogVersionCurrent)
        .filter(CatalogVersionCurrent.version_id == "v-old")
        .first()
    )
    assert row is not None
    assert row.is_current is True


def test_rollback_returns_404_for_unknown_version(auth_client, db):
    seed_catalog(db)
    r = auth_client.post(
        "/api/v1/catalog/rollback",
        params={"project_id": "TMQ"},
        json={"to_effective_version": "version-does-not-exist"},
    )
    assert r.status_code == 404


# ─── payload alias (Desktop compatibility) ────────────────────────────────────

def test_project_ops_accepts_payload_key_as_alias_for_data(auth_client, db):
    """Desktop clients send 'payload' instead of 'data' — must be accepted."""
    seed_catalog(db)
    r = auth_client.patch(
        "/api/v1/catalog/project-ops",
        params={"project_id": "TMQ"},
        json={"ops": [
            # Desktop format: key is 'payload', not 'data'
            {"op": "patch", "entity": "activities", "id": "CAM",
             "payload": {"name": "Caminamiento via payload key"}}
        ]},
    )
    assert r.status_code == 200
    activities = r.json()["effective"]["entities"]["activities"]
    cam = next(a for a in activities if a["id"] == "CAM")
    assert cam["name"] == "Caminamiento via payload key"


def test_project_ops_delete_deactivates_activity(auth_client, db):
    """Desktop sends op='delete' which must deactivate the entity."""
    seed_catalog(db)
    r = auth_client.patch(
        "/api/v1/catalog/project-ops",
        params={"project_id": "TMQ"},
        json={"ops": [
            {"op": "delete", "entity": "activities", "id": "REU"}
        ]},
    )
    assert r.status_code == 200
    activities = r.json()["effective"]["entities"]["activities"]
    reu = next(a for a in activities if a["id"] == "REU")
    assert reu["active"] is False


def test_project_ops_patch_is_project_scoped_for_shared_base(auth_client, db):
    seed_catalog(db)
    now = datetime.now(timezone.utc)
    db.add(CatProject(project_id="TAP", name="TAP", version_id="v1", is_active=True, updated_at=now))
    db.commit()

    patched = auth_client.patch(
        "/api/v1/catalog/project-ops",
        params={"project_id": "TAP"},
        json={"ops": [
            {
                "op": "patch",
                "entity": "activities",
                "id": "CAM",
                "data": {"name": "Caminamiento TAP"},
            }
        ]},
    )
    assert patched.status_code == 200

    tmq_bundle = auth_client.get("/api/v1/catalog/bundle", params={"project_id": "TMQ"})
    tap_bundle = auth_client.get("/api/v1/catalog/bundle", params={"project_id": "TAP"})

    assert tmq_bundle.status_code == 200
    assert tap_bundle.status_code == 200

    tmq_cam = next(
        a for a in tmq_bundle.json()["effective"]["entities"]["activities"] if a["id"] == "CAM"
    )
    tap_cam = next(
        a for a in tap_bundle.json()["effective"]["entities"]["activities"] if a["id"] == "CAM"
    )

    assert tmq_cam["name"] == "Caminamiento"
    assert tap_cam["name"] == "Caminamiento TAP"
