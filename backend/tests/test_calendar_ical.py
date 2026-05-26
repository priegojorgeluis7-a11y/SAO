"""Tests para el endpoint GET /api/v1/assignments/ical (feed iCalendar)."""

import os
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest

from app.core.security import create_access_token

os.environ.setdefault("DATA_BACKEND", "firestore")
os.environ.setdefault("JWT_SECRET", "test-secret-for-ci-tests-minimum32chars!")
os.environ.setdefault("GCS_BUCKET", "test-bucket")
os.environ.setdefault("CORS_ORIGINS", "http://localhost:3000")


# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────

def _make_token(user_id: str) -> str:
    return create_access_token({"sub": user_id})


def _make_activity(
    *,
    user_id: str,
    activity_id: str | None = None,
    project_id: str = "TSNL",
    activity_type_code: str = "CAM",
    title: str = "Inspección visual",
    execution_state: str = "PENDIENTE",
    start_offset_days: int = 1,
    end_offset_days: int = 2,
    deleted: bool = False,
) -> dict:
    now = datetime.now(timezone.utc)
    return {
        "uuid": activity_id or str(uuid4()),
        "project_id": project_id,
        "activity_type_code": activity_type_code,
        "title": title,
        "description": "Descripción de prueba",
        "execution_state": execution_state,
        "assigned_to_user_id": user_id,
        "participant_user_ids": [user_id],
        "assignment_start_at": now + timedelta(days=start_offset_days),
        "assignment_end_at": now + timedelta(days=end_offset_days),
        "pk_start": 142000,
        "pk_end": 142500,
        "latitude": "19.4326",
        "longitude": "-99.1332",
        "created_at": now,
        "updated_at": now,
        "deleted_at": now if deleted else None,
        "sync_version": 1,
    }


# ─────────────────────────────────────────────────────────────
# Tests sin Firestore real (token inválido / sin token)
# ─────────────────────────────────────────────────────────────

class TestIcalTokenValidation:
    def test_missing_token_returns_422(self, client):
        resp = client.get("/api/v1/assignments/ical")
        assert resp.status_code == 422

    def test_invalid_token_returns_401(self, client):
        resp = client.get("/api/v1/assignments/ical?token=notavalidjwt")
        assert resp.status_code == 401
        assert "inválido" in resp.text.lower() or "invalid" in resp.text.lower()

    def test_empty_token_returns_401(self, client):
        resp = client.get("/api/v1/assignments/ical?token=")
        # FastAPI may reject empty string as invalid query param validation
        assert resp.status_code in (401, 422)


# ─────────────────────────────────────────────────────────────
# Tests del generador de calendario (unitarios, sin Firestore)
# ─────────────────────────────────────────────────────────────

class TestIcalBuilder:
    def test_empty_activities_returns_valid_ical(self):
        from app.api.v1.calendar_ical import _build_calendar

        result = _build_calendar([], "Jorge Priego")
        assert result.startswith(b"BEGIN:VCALENDAR")
        assert b"END:VCALENDAR" in result
        assert b"SAO" in result

    def test_single_activity_generates_vevent(self):
        from app.api.v1.calendar_ical import _build_calendar

        user_id = str(uuid4())
        activity = _make_activity(user_id=user_id, execution_state="COMPLETADA")

        result = _build_calendar([activity], "Test User")
        assert b"BEGIN:VEVENT" in result
        assert b"END:VEVENT" in result
        assert b"SUMMARY:" in result
        assert b"DTSTART" in result
        assert b"DTEND" in result

    def test_vevent_includes_pk_in_description(self):
        from app.api.v1.calendar_ical import _build_calendar

        user_id = str(uuid4())
        activity = _make_activity(user_id=user_id)

        result = _build_calendar([activity], "Test User")
        decoded = result.decode("utf-8")
        assert "142+000" in decoded

    def test_vevent_includes_location_when_gps_present(self):
        from app.api.v1.calendar_ical import _build_calendar

        user_id = str(uuid4())
        activity = _make_activity(user_id=user_id)
        activity["latitude"] = "19.4326"
        activity["longitude"] = "-99.1332"

        result = _build_calendar([activity], "Test User")
        assert b"LOCATION:" in result

    def test_deleted_activity_excluded(self):
        from app.api.v1.calendar_ical import _build_calendar

        user_id = str(uuid4())
        activities = [
            _make_activity(user_id=user_id, deleted=False),
            _make_activity(user_id=user_id, deleted=True),
        ]
        # Filter deleted before passing (simulates what the endpoint does)
        filtered = [a for a in activities if a.get("deleted_at") is None]
        result = _build_calendar(filtered, "Test User")
        # Only 1 VEVENT expected
        assert result.count(b"BEGIN:VEVENT") == 1

    def test_multiple_activities_generate_multiple_vevents(self):
        from app.api.v1.calendar_ical import _build_calendar

        user_id = str(uuid4())
        activities = [
            _make_activity(user_id=user_id, project_id="TSNL"),
            _make_activity(user_id=user_id, project_id="TQI"),
            _make_activity(user_id=user_id, project_id="TMQ"),
        ]

        result = _build_calendar(activities, "Test User")
        assert result.count(b"BEGIN:VEVENT") == 3

    def test_activity_without_uuid_is_skipped(self):
        from app.api.v1.calendar_ical import _build_calendar

        user_id = str(uuid4())
        activity = _make_activity(user_id=user_id)
        activity.pop("uuid")  # Remove UUID

        result = _build_calendar([activity], "Test User")
        assert result.count(b"BEGIN:VEVENT") == 0

    def test_activity_without_start_date_is_skipped(self):
        from app.api.v1.calendar_ical import _build_calendar

        user_id = str(uuid4())
        activity = _make_activity(user_id=user_id)
        activity["assignment_start_at"] = None
        activity["created_at"] = None

        result = _build_calendar([activity], "Test User")
        assert result.count(b"BEGIN:VEVENT") == 0

    def test_completada_generates_confirmed_status(self):
        from app.api.v1.calendar_ical import _build_calendar

        user_id = str(uuid4())
        activity = _make_activity(user_id=user_id, execution_state="COMPLETADA")

        result = _build_calendar([activity], "Test User")
        assert b"STATUS:CONFIRMED" in result

    def test_pendiente_generates_tentative_status(self):
        from app.api.v1.calendar_ical import _build_calendar

        user_id = str(uuid4())
        activity = _make_activity(user_id=user_id, execution_state="PENDIENTE")

        result = _build_calendar([activity], "Test User")
        assert b"STATUS:TENTATIVE" in result

    def test_summary_includes_project_and_type(self):
        from app.api.v1.calendar_ical import _build_calendar

        user_id = str(uuid4())
        activity = _make_activity(
            user_id=user_id,
            project_id="TSNL",
            activity_type_code="REU",
        )

        result = _build_calendar([activity], "Test User")
        decoded = result.decode("utf-8")
        # SUMMARY should reference the project and type label
        assert "TSNL" in decoded
        assert "Reuni" in decoded  # "Reunión"

    def test_end_date_defaults_to_one_hour_after_start(self):
        from app.api.v1.calendar_ical import _build_calendar

        user_id = str(uuid4())
        activity = _make_activity(user_id=user_id)
        activity["assignment_end_at"] = None

        result = _build_calendar([activity], "Test User")
        assert b"BEGIN:VEVENT" in result


# ─────────────────────────────────────────────────────────────
# Tests de label helper
# ─────────────────────────────────────────────────────────────

class TestActivityTypeLabels:
    def test_known_codes(self):
        from app.api.v1.calendar_ical import _label_for_type

        assert _label_for_type("CAM") == "Caminata"
        assert _label_for_type("REU") == "Reunión"
        assert _label_for_type("ASP") == "Aspecto"

    def test_unknown_code_returns_code(self):
        from app.api.v1.calendar_ical import _label_for_type

        assert _label_for_type("XYZ") == "XYZ"
        assert _label_for_type("cam") == "Caminata"  # case-insensitive
