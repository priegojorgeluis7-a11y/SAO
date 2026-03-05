import pytest
from datetime import date, datetime, timezone
from uuid import uuid4

pytestmark = pytest.mark.integration

from app.core.security import get_password_hash
from app.models.activity import Activity, ExecutionState
from app.models.catalog import CATActivityType, CATEvidenceRule, CatalogStatus, CatalogVersion, EntityType
from app.models.evidence import Evidence
from app.models.front import Front
from app.models.observation import Observation
from app.models.project import Project, ProjectStatus
from app.models.reject_reason import RejectReason
from app.models.role import Role
from app.models.user import User, UserStatus
from app.models.user_role_scope import UserRoleScope


def _seed_reject_reasons(db):
    """Seed razones de rechazo de prueba en la DB de test."""
    reasons = [
        RejectReason(reason_code="FOTO_BORROSA", label="Foto borrosa o ilegible", severity="MED", requires_comment=False, is_active=True),
        RejectReason(reason_code="GPS_NO_COINCIDE", label="GPS no coincide con ubicación declarada", severity="HIGH", requires_comment=True, is_active=True),
        RejectReason(reason_code="FALTA_INFORMACION", label="Falta información requerida", severity="MED", requires_comment=True, is_active=True),
    ]
    for r in reasons:
        if db.query(RejectReason).filter(RejectReason.reason_code == r.reason_code).first() is None:
            db.add(r)
    db.commit()


def _create_user_with_role(db, *, email: str, role_name: str, project_id: str | None = None):
    role = db.query(Role).filter(Role.name == role_name).first()
    if role is None:
        role = Role(name=role_name, description=f"{role_name} role")
        db.add(role)
        db.flush()

    user = User(
        id=uuid4(),
        email=email,
        password_hash=get_password_hash("testpass123"),
        full_name=f"{role_name.title()} User",
        status=UserStatus.ACTIVE,
    )
    db.add(user)
    db.flush()

    scope = UserRoleScope(
        user_id=user.id,
        role_id=role.id,
        project_id=project_id,
        assigned_by_id=user.id,
    )
    db.add(scope)
    db.commit()
    db.refresh(user)
    return user


def _login_headers(client, email: str, password: str = "testpass123"):
    response = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert response.status_code == 200
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def _seed_activity_bundle(
    db,
    creator_user_id,
    *,
    with_evidence: bool = True,
    with_gps: bool = False,
    pk_start: int = 1200,
    pk_end: int | None = 1500,
):
    project = Project(id="TMQ", name="Test TMQ", status=ProjectStatus.ACTIVE, start_date=date.today())
    db.add(project)
    db.flush()

    front = Front(id=uuid4(), project_id=project.id, code="F1", name="Front 1", pk_start=0, pk_end=10000)
    db.add(front)
    db.flush()

    catalog = CatalogVersion(
        id=uuid4(),
        project_id=project.id,
        version_number="1.0.0",
        status=CatalogStatus.PUBLISHED,
        hash="hash-v1",
        published_at=datetime.now(timezone.utc),
        published_by_id=creator_user_id,
    )
    db.add(catalog)
    db.flush()

    activity = Activity(
        uuid=uuid4(),
        project_id=project.id,
        front_id=front.id,
        pk_start=pk_start,
        pk_end=pk_end,
        execution_state=ExecutionState.REVISION_PENDIENTE.value,
        created_by_user_id=creator_user_id,
        assigned_to_user_id=creator_user_id,
        catalog_version_id=catalog.id,
        activity_type_code="INSP_CIVIL",
        latitude="19.4326" if with_gps else None,
        longitude="-99.1332" if with_gps else None,
        title="Actividad de revisión",
        description="Cambio de catalogo en texto",
        sync_version=1,
    )
    db.add(activity)
    db.flush()

    evidence = None
    if with_evidence:
        evidence = Evidence(
            id=uuid4(),
            activity_id=activity.uuid,
            object_path="tmq/evidences/a.jpg",
            mime_type="image/jpeg",
            size_bytes=1024,
            original_file_name="a.jpg",
            caption="Evidencia principal",
            created_by=creator_user_id,
            uploaded_at=datetime.now(timezone.utc),
        )
        db.add(evidence)
    db.commit()

    return project, activity, evidence


def _seed_checklist_rule_for_activity(db, activity: Activity, *, min_photos: int, requires_gps: bool):
    activity_type = CATActivityType(
        id=uuid4(),
        version_id=activity.catalog_version_id,
        code=activity.activity_type_code,
        name="Inspección Civil",
        is_active=True,
    )
    db.add(activity_type)
    db.flush()

    rule = CATEvidenceRule(
        id=uuid4(),
        version_id=activity.catalog_version_id,
        entity_type=EntityType.ACTIVITY,
        type_id=activity_type.id,
        min_photos=min_photos,
        requires_gps=requires_gps,
    )
    db.add(rule)
    db.commit()


def test_review_queue_and_detail(client, db):
    reviewer = _create_user_with_role(db, email="reviewer@example.com", role_name="SUPERVISOR", project_id="TMQ")
    headers = _login_headers(client, reviewer.email)
    _, activity, _ = _seed_activity_bundle(db, reviewer.id)

    queue_response = client.get("/api/v1/review/queue?project_id=TMQ", headers=headers)
    assert queue_response.status_code == 200
    queue_data = queue_response.json()
    assert "items" in queue_data
    assert len(queue_data["items"]) >= 1
    assert any(item["id"] == str(activity.uuid) for item in queue_data["items"])

    detail_response = client.get(f"/api/v1/review/activity/{activity.uuid}", headers=headers)
    assert detail_response.status_code == 200
    detail_data = detail_response.json()
    assert detail_data["id"] == str(activity.uuid)
    assert detail_data["project_id"] == "TMQ"


def test_review_decision_reject_creates_observation(client, db):
    supervisor = _create_user_with_role(db, email="supervisor@example.com", role_name="SUPERVISOR", project_id="TMQ")
    headers = _login_headers(client, supervisor.email)
    _, activity, _ = _seed_activity_bundle(db, supervisor.id)
    _seed_reject_reasons(db)

    decision_payload = {
        "decision": "REJECT",
        "reject_reason_code": "FALTA_INFORMACION",
        "comment": "Falta evidencia contextual",
        "field_resolutions": [],
        "apply_to_similar": False,
    }
    response = client.post(f"/api/v1/review/activity/{activity.uuid}/decision", json=decision_payload, headers=headers)
    assert response.status_code == 200
    assert response.json()["ok"] is True
    assert response.json()["status"] == "RECHAZADO"

    created_obs = db.query(Observation).filter(Observation.activity_id == activity.uuid).all()
    assert len(created_obs) == 1
    assert created_obs[0].status == "OPEN"


def test_mobile_observations_resolve(client, db):
    operativo = _create_user_with_role(db, email="operativo@example.com", role_name="OPERATIVO", project_id="TMQ")
    headers = _login_headers(client, operativo.email)
    _, activity, _ = _seed_activity_bundle(db, operativo.id)

    create_payload = {
        "project_id": "TMQ",
        "activity_id": str(activity.uuid),
        "assignee_user_id": str(operativo.id),
        "tags": ["review", "gps"],
        "message": "Corrige coordenadas",
        "severity": "HIGH",
    }
    create_response = client.post("/api/v1/observations", json=create_payload, headers=headers)
    assert create_response.status_code == 201
    observation_id = create_response.json()["id"]

    list_response = client.get("/api/v1/mobile/observations?status=open", headers=headers)
    assert list_response.status_code == 200
    listed_ids = [row["id"] for row in list_response.json()]
    assert observation_id in listed_ids

    resolve_response = client.post(f"/api/v1/mobile/observations/{observation_id}/resolve", headers=headers)
    assert resolve_response.status_code == 200
    assert resolve_response.json()["ok"] is True


def test_reject_playbook_reads_from_db(client, db):
    reviewer = _create_user_with_role(db, email="playbook@example.com", role_name="SUPERVISOR", project_id="TMQ")
    headers = _login_headers(client, reviewer.email)
    _seed_reject_reasons(db)

    response = client.get("/api/v1/review/reject-playbook", headers=headers)
    assert response.status_code == 200
    payload = response.json()
    assert "items" in payload
    codes = {item["reason_code"] for item in payload["items"]}
    assert "FOTO_BORROSA" in codes
    assert "GPS_NO_COINCIDE" in codes
    assert "FALTA_INFORMACION" in codes


def test_admin_can_create_reject_reason(client, db):
    admin = _create_user_with_role(db, email="admin-reasons@example.com", role_name="ADMIN", project_id="TMQ")
    headers = _login_headers(client, admin.email)

    response = client.post(
        "/api/v1/review/reject-reasons",
        json={
            "reason_code": "DOC_INCOMPLETA",
            "label": "Documentación incompleta",
            "severity": "MED",
            "requires_comment": True,
        },
        headers=headers,
    )

    assert response.status_code == 200
    created = response.json()
    assert created["reason_code"] == "DOC_INCOMPLETA"
    assert created["requires_comment"] is True

    playbook = client.get("/api/v1/review/reject-playbook", headers=headers)
    codes = {item["reason_code"] for item in playbook.json()["items"]}
    assert "DOC_INCOMPLETA" in codes


def test_non_admin_cannot_create_reject_reason(client, db):
    supervisor = _create_user_with_role(db, email="no-admin-reasons@example.com", role_name="SUPERVISOR", project_id="TMQ")
    headers = _login_headers(client, supervisor.email)

    response = client.post(
        "/api/v1/review/reject-reasons",
        json={
            "reason_code": "NO_PERM",
            "label": "No debería crearse",
            "severity": "LOW",
            "requires_comment": False,
        },
        headers=headers,
    )

    assert response.status_code == 403


def test_review_reject_requires_valid_reason_code(client, db):
    supervisor = _create_user_with_role(db, email="reject-validate@example.com", role_name="SUPERVISOR", project_id="TMQ")
    headers = _login_headers(client, supervisor.email)
    _, activity, _ = _seed_activity_bundle(db, supervisor.id)
    _seed_reject_reasons(db)

    # Sin código de razón → 400
    response = client.post(
        f"/api/v1/review/activity/{activity.uuid}/decision",
        json={"decision": "REJECT", "field_resolutions": []},
        headers=headers,
    )
    assert response.status_code == 400

    # Código inválido → 422
    response = client.post(
        f"/api/v1/review/activity/{activity.uuid}/decision",
        json={"decision": "REJECT", "reject_reason_code": "INEXISTENTE", "field_resolutions": []},
        headers=headers,
    )
    assert response.status_code == 422

    # Código válido → 200
    response = client.post(
        f"/api/v1/review/activity/{activity.uuid}/decision",
        json={"decision": "REJECT", "reject_reason_code": "FOTO_BORROSA", "field_resolutions": []},
        headers=headers,
    )
    assert response.status_code == 200
    assert response.json()["status"] == "RECHAZADO"


def test_review_reject_requires_comment_when_reason_demands_it(client, db):
    supervisor = _create_user_with_role(db, email="reject-comment-required@example.com", role_name="SUPERVISOR", project_id="TMQ")
    headers = _login_headers(client, supervisor.email)
    _, activity, _ = _seed_activity_bundle(db, supervisor.id)
    _seed_reject_reasons(db)

    response = client.post(
        f"/api/v1/review/activity/{activity.uuid}/decision",
        json={
            "decision": "REJECT",
            "reject_reason_code": "GPS_NO_COINCIDE",
            "field_resolutions": [],
        },
        headers=headers,
    )

    assert response.status_code == 400
    assert "requires comment" in response.json()["detail"]


def test_review_approve_returns_422_when_checklist_incomplete(client, db):
    supervisor = _create_user_with_role(db, email="checklist@example.com", role_name="SUPERVISOR", project_id="TMQ")
    headers = _login_headers(client, supervisor.email)
    _, activity, _ = _seed_activity_bundle(db, supervisor.id, with_evidence=False, with_gps=False)
    _seed_checklist_rule_for_activity(db, activity, min_photos=1, requires_gps=True)

    response = client.post(
        f"/api/v1/review/activity/{activity.uuid}/decision",
        json={
            "decision": "APPROVE",
            "field_resolutions": [],
        },
        headers=headers,
    )

    assert response.status_code == 422
    detail = response.json()["detail"]
    assert detail["error"] == "CHECKLIST_INCOMPLETE"
    assert "photo_min_1" in detail["missing_items"]
    assert "gps_required" in detail["missing_items"]


def test_review_approve_succeeds_when_checklist_complete(client, db):
    supervisor = _create_user_with_role(db, email="checklist-ok@example.com", role_name="SUPERVISOR", project_id="TMQ")
    headers = _login_headers(client, supervisor.email)
    _, activity, _ = _seed_activity_bundle(db, supervisor.id, with_evidence=True, with_gps=True)
    _seed_checklist_rule_for_activity(db, activity, min_photos=1, requires_gps=True)

    response = client.post(
        f"/api/v1/review/activity/{activity.uuid}/decision",
        json={
            "decision": "APPROVE",
            "field_resolutions": [],
        },
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["ok"] is True
    assert response.json()["status"] == "APROBADO"


def test_review_queue_marks_gps_critical_when_rule_requires_gps_and_coordinates_missing(client, db):
    reviewer = _create_user_with_role(db, email="gps-critical@example.com", role_name="SUPERVISOR", project_id="TMQ")
    headers = _login_headers(client, reviewer.email)
    _, activity, _ = _seed_activity_bundle(db, reviewer.id, with_evidence=True, with_gps=False)
    _seed_checklist_rule_for_activity(db, activity, min_photos=1, requires_gps=True)

    response = client.get("/api/v1/review/queue?project_id=TMQ", headers=headers)
    assert response.status_code == 200
    items = response.json()["items"]
    queue_item = next(item for item in items if item["id"] == str(activity.uuid))

    assert queue_item["gps_critical"] is True
    assert queue_item["checklist_incomplete"] is True
    assert queue_item["has_conflicts"] is True


def test_review_queue_marks_gps_critical_when_pk_is_outside_front_range(client, db):
    reviewer = _create_user_with_role(db, email="gps-pk@example.com", role_name="SUPERVISOR", project_id="TMQ")
    headers = _login_headers(client, reviewer.email)
    _, activity, _ = _seed_activity_bundle(
        db,
        reviewer.id,
        with_evidence=True,
        with_gps=True,
        pk_start=12001,
        pk_end=13000,
    )

    response = client.get("/api/v1/review/queue?project_id=TMQ", headers=headers)
    assert response.status_code == 200
    items = response.json()["items"]
    queue_item = next(item for item in items if item["id"] == str(activity.uuid))

    assert queue_item["gps_critical"] is True
    assert queue_item["checklist_incomplete"] is True
    assert queue_item["has_conflicts"] is True


def test_review_queue_marks_checklist_incomplete_when_evidence_count_below_minimum(client, db):
    reviewer = _create_user_with_role(db, email="photo-min@example.com", role_name="SUPERVISOR", project_id="TMQ")
    headers = _login_headers(client, reviewer.email)
    _, activity, _ = _seed_activity_bundle(db, reviewer.id, with_evidence=True, with_gps=True)
    _seed_checklist_rule_for_activity(db, activity, min_photos=2, requires_gps=False)

    response = client.get("/api/v1/review/queue?project_id=TMQ", headers=headers)
    assert response.status_code == 200
    items = response.json()["items"]
    queue_item = next(item for item in items if item["id"] == str(activity.uuid))

    assert queue_item["missing_evidence"] is True
    assert queue_item["checklist_incomplete"] is True
    assert queue_item["has_conflicts"] is True


def test_review_reject_fails_when_reasons_catalog_is_empty(client, db):
    supervisor = _create_user_with_role(db, email="reject-empty@example.com", role_name="SUPERVISOR", project_id="TMQ")
    headers = _login_headers(client, supervisor.email)
    _, activity, _ = _seed_activity_bundle(db, supervisor.id)

    # No seed_reject_reasons() on purpose: endpoint must rely only on DB-configured reasons.
    response = client.post(
        f"/api/v1/review/activity/{activity.uuid}/decision",
        json={"decision": "REJECT", "reject_reason_code": "PHOTO_BLUR", "field_resolutions": []},
        headers=headers,
    )

    assert response.status_code == 422
    assert "not found or inactive" in str(response.json()["detail"])


def test_review_reject_accepts_runtime_created_reason(client, db):
    admin = _create_user_with_role(db, email="reject-runtime-admin@example.com", role_name="ADMIN", project_id="TMQ")
    admin_headers = _login_headers(client, admin.email)
    _, activity, _ = _seed_activity_bundle(db, admin.id)

    create_reason = client.post(
        "/api/v1/review/reject-reasons",
        json={
            "reason_code": "NUEVA_REGLA_QA",
            "label": "Regla QA creada en runtime",
            "severity": "MED",
            "requires_comment": True,
        },
        headers=admin_headers,
    )
    assert create_reason.status_code == 200

    reject_response = client.post(
        f"/api/v1/review/activity/{activity.uuid}/decision",
        json={
            "decision": "REJECT",
            "reject_reason_code": "NUEVA_REGLA_QA",
            "comment": "Aplicando regla dinámica",
            "field_resolutions": [],
        },
        headers=admin_headers,
    )
    assert reject_response.status_code == 200
    assert reject_response.json()["status"] == "RECHAZADO"
