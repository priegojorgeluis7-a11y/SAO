from app.services.audit_redaction import sanitize_audit_details, sanitize_audit_details_json


def test_sanitize_audit_details_redacts_sensitive_fields():
    payload = {
        "preview": "texto sensible",
        "comment": "observacion confidencial",
        "ok": True,
        "nested": {
            "reviewed_text": "contenido largo",
            "count": 2,
        },
        "items": [
            {"extracted_fields": {"curp": "XXXX"}},
            {"value": 123},
        ],
    }

    sanitized = sanitize_audit_details(payload)

    assert sanitized is not None
    assert sanitized["preview"] == "[REDACTED]"
    assert sanitized["comment"] == "[REDACTED]"
    assert sanitized["ok"] is True
    assert sanitized["nested"]["reviewed_text"] == "[REDACTED]"
    assert sanitized["nested"]["count"] == 2
    assert sanitized["items"][0]["extracted_fields"] == "[REDACTED]"


def test_sanitize_audit_details_json_handles_invalid_json():
    raw = "{not-json}"
    serialized = sanitize_audit_details_json(raw)

    assert serialized is not None
    assert "[REDACTED]" in serialized
