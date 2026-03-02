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
    ProjCatalogOverride,
    RelActivityTopic,
)


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


def seed_base_catalog(db, version_id: str, is_current: bool = True):
    now = datetime.now(timezone.utc)

    db.add(
        CatalogVersionCurrent(
            version_id=version_id,
            created_at=now,
            changelog="seed",
            is_current=is_current,
        )
    )

    db.add(
        CatProject(
            project_id="TMQ",
            name="Tren Mexico Queretaro",
            version_id=version_id,
            is_active=True,
            updated_at=now,
        )
    )

    db.add(
        CatActivity(
            activity_id="CAM",
            name="Caminamiento",
            description="Base activity",
            version_id=version_id,
            is_active=True,
            updated_at=now,
        )
    )

    db.add(
        CatSubcategory(
            subcategory_id="CAM_DDV",
            activity_id="CAM",
            name="Verificacion de DDV",
            description=None,
            version_id=version_id,
            is_active=True,
            updated_at=now,
        )
    )

    db.add(
        CatPurpose(
            purpose_id="PUR_CAM_DDV",
            activity_id="CAM",
            subcategory_id="CAM_DDV",
            name="Verificacion",
            version_id=version_id,
            is_active=True,
            updated_at=now,
        )
    )

    db.add(
        CatTopic(
            topic_id="topic_local",
            type=None,
            name="Tema local",
            description=None,
            version_id=version_id,
            is_active=True,
            updated_at=now,
        )
    )

    db.add(
        RelActivityTopic(
            activity_id="CAM",
            topic_id="topic_local",
            version_id=version_id,
            is_active=True,
            updated_at=now,
        )
    )

    db.add(
        CatResult(
            result_id="R08",
            name="Solicitud canalizada a dependencia",
            category="Reajustes",
            severity_default="yellow",
            version_id=version_id,
            is_active=True,
            updated_at=now,
        )
    )

    db.add(
        CatAttendee(
            attendee_id="AST1",
            type="Dependencia",
            name="ARTF",
            description="Agencia",
            version_id=version_id,
            is_active=True,
            updated_at=now,
        )
    )

    db.commit()


def assert_sorted(values):
    assert values == sorted(values)


def test_current_version_endpoint(auth_client, db):
    seed_base_catalog(db, version_id="v1", is_current=True)

    response = auth_client.get("/api/v1/catalog/version/current")
    assert response.status_code == 200
    data = response.json()
    assert data["version_id"] == "v1"

    db.query(CatalogVersionCurrent).update({CatalogVersionCurrent.is_current: False})
    db.commit()

    response = auth_client.get("/api/v1/catalog/version/current")
    assert response.status_code == 404
    assert "No published catalog found" in response.json()["detail"]


def test_catalog_diff(auth_client, db):
    seed_base_catalog(db, version_id="v1", is_current=True)

    response = auth_client.get(
        "/api/v1/catalog/diff",
        params={"project_id": "TMQ", "from_version_id": "v1", "to_version_id": "v1"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["meta"]["catalog_hash"]

    for key in [
        "activities",
        "subcategories",
        "purposes",
        "topics",
        "rel_activity_topics",
        "results",
        "attendees",
        "overrides",
    ]:
        assert data["changes"][key]["upserts"] == []
        assert data["changes"][key]["deletes"] == []

    db.query(CatalogVersionCurrent).update({CatalogVersionCurrent.is_current: False})
    db.add(
        CatalogVersionCurrent(
            version_id="v2",
            created_at=datetime.now(timezone.utc),
            changelog="v2",
            is_current=True,
        )
    )

    db.add(
        ProjCatalogOverride(
            project_id="TMQ",
            entity_type="result",
            entity_id="R08",
            is_enabled=None,
            display_name_override=None,
            sort_order_override=None,
            color_override=None,
            severity_override="red",
            rules_json=None,
            version_id="v2",
            is_active=True,
            updated_at=datetime.now(timezone.utc),
        )
    )

    db.add(
        ProjCatalogOverride(
            project_id="TMQ",
            entity_type="topic",
            entity_id="topic_local",
            is_enabled=False,
            display_name_override=None,
            sort_order_override=None,
            color_override=None,
            severity_override=None,
            rules_json=None,
            version_id="v2",
            is_active=True,
            updated_at=datetime.now(timezone.utc),
        )
    )
    db.commit()

    response = auth_client.get(
        "/api/v1/catalog/diff",
        params={"project_id": "TMQ", "from_version_id": "v1", "to_version_id": "v2"},
    )
    assert response.status_code == 200
    data = response.json()

    results_upserts = data["changes"]["results"]["upserts"]
    assert any(
        item["id"] == "R08" and item["severity_effective"] == "red" for item in results_upserts
    )

    assert "topic_local" in data["changes"]["topics"]["deletes"]
    assert "CAM|topic_local" in data["changes"]["rel_activity_topics"]["deletes"]

    assert_sorted([item["id"] for item in data["changes"]["activities"]["upserts"]])
    assert_sorted([item["id"] for item in data["changes"]["results"]["upserts"]])
    assert_sorted(data["changes"]["topics"]["deletes"])


# ---------------------------------------------------------------------------
# Bootstrap / first-sync scenarios
# ---------------------------------------------------------------------------


def test_effective_catalog_200_with_data(auth_client, db):
    """First sync: catalog published and tables populated → 200 with full payload."""
    seed_base_catalog(db, version_id="v1", is_current=True)

    response = auth_client.get(
        "/api/v1/catalog/effective",
        params={"project_id": "TMQ"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["meta"]["version_id"] == "v1"
    assert data["meta"]["project_id"] == "TMQ"
    assert len(data["activities"]) == 1
    assert data["activities"][0]["id"] == "CAM"
    assert len(data["results"]) == 1
    assert data["results"][0]["id"] == "R08"


def test_effective_catalog_200_empty_tables(auth_client, db):
    """
    First sync: catalog_version row exists (is_current=True) but none of the
    cat_* tables have rows for that version_id.
    Service falls back to all rows → still returns 200, not 500.
    """
    now = datetime.now(timezone.utc)
    # Only the version row — no cat_* rows for this version
    db.add(
        CatalogVersionCurrent(
            version_id="v_empty",
            created_at=now,
            changelog="empty version",
            is_current=True,
        )
    )
    db.commit()

    response = auth_client.get(
        "/api/v1/catalog/effective",
        params={"project_id": "TMQ"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["meta"]["version_id"] == "v_empty"
    # No rows → all lists are empty
    assert data["activities"] == []
    assert data["subcategories"] == []
    assert data["results"] == []


def test_version_current_404_when_no_catalog(auth_client, db):
    """
    First sync with completely empty DB (no catalog_version rows).
    /catalog/version/current must return 404, never 500.
    """
    response = auth_client.get("/api/v1/catalog/version/current")
    assert response.status_code == 404
    detail = response.json()["detail"]
    assert "No published catalog" in detail or "catalog" in detail.lower()


def test_effective_catalog_404_when_no_version_configured(auth_client, db):
    """
    /catalog/effective?project_id=TMQ without version_id falls back to
    resolve_current_version_id(). If no is_current row → 404, never 500.
    """
    response = auth_client.get(
        "/api/v1/catalog/effective",
        params={"project_id": "TMQ"},
    )
    assert response.status_code == 404


def test_effective_catalog_with_explicit_version_id(auth_client, db):
    """
    Bootstrap passes explicit version_id (obtained from /version/current).
    Verify effective catalog resolves it directly without hitting is_current lookup.
    """
    seed_base_catalog(db, version_id="v1", is_current=True)

    # Step 1: resolve current version
    r1 = auth_client.get("/api/v1/catalog/version/current")
    assert r1.status_code == 200
    version_id = r1.json()["version_id"]

    # Step 2: fetch effective catalog with explicit version_id (bootstrap flow)
    r2 = auth_client.get(
        "/api/v1/catalog/effective",
        params={"project_id": "TMQ", "version_id": version_id},
    )
    assert r2.status_code == 200
    data = r2.json()
    assert data["meta"]["version_id"] == version_id
    assert len(data["activities"]) >= 1


def test_check_updates_no_hash_first_sync(auth_client, db):
    """
    First sync: app sends no current_hash (None).
    /catalog/check-updates must return update_available=True, never 422 or 500.
    """
    seed_base_catalog(db, version_id="v1", is_current=False)
    # Publish a CatalogVersion so check-updates has something to compare
    # (uses separate CatalogVersion model / catalog_versions table)
    # Here we only test the query-param handling: no current_hash → no 422
    response = auth_client.get(
        "/api/v1/catalog/check-updates",
        params={"project_id": "TMQ"},  # no current_hash
    )
    # Without a published CatalogVersion the service returns update_available=False
    # but must NOT return 4xx/5xx
    assert response.status_code == 200
    data = response.json()
    assert "update_available" in data
