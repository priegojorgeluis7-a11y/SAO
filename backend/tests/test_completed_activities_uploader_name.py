from app.api.v1.completed_activities import _resolve_uploader_name


def test_resolve_uploader_name_uses_payload_name_first() -> None:
    payload = {
        "uploader_name": "Jesus Gaspar Rios",
        "uploaded_by": "user-123",
    }

    assert _resolve_uploader_name(payload, {"user-123": "Admin User"}, "user-123") == "Jesus Gaspar Rios"


def test_resolve_uploader_name_falls_back_to_users_map() -> None:
    payload = {"uploaded_by": "user-123"}

    assert _resolve_uploader_name(payload, {"user-123": "Admin User"}, "user-123") == "Admin User"


def test_resolve_uploader_name_returns_email_uid_when_available() -> None:
    payload = {"uploaded_by": "inspector@example.com"}

    assert _resolve_uploader_name(payload, {}, "inspector@example.com") == "inspector@example.com"


def test_resolve_uploader_name_falls_back_to_created_by_mapping() -> None:
    payload = {"created_by": "user-456"}

    assert _resolve_uploader_name(payload, {"user-456": "Fernanda Torres"}, "") == "Fernanda Torres"
