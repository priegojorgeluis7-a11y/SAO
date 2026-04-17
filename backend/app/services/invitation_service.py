from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import secrets
from typing import Any

from app.core.firestore import get_firestore_client

_INVITATION_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


@dataclass
class FirestoreInvitation:
    invite_id: str
    role: str
    created_by: str
    target_email: str | None
    expires_at: datetime
    used: bool
    used_by: str | None
    used_at: datetime | None
    created_at: datetime


def _parse_datetime(value: Any) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value)
        except ValueError:
            return None
    return None


def _normalize_email(value: str | None) -> str | None:
    normalized = str(value or "").strip().lower()
    return normalized or None


def _normalize_role(value: str | None) -> str:
    return str(value or "").strip().upper()


def _invitation_from_payload(payload: dict[str, Any], fallback_invite_id: str | None = None) -> FirestoreInvitation | None:
    invite_id = str(payload.get("invite_id") or fallback_invite_id or "").strip().upper()
    role = _normalize_role(payload.get("role"))
    if not invite_id or not role:
        return None

    created_at = _parse_datetime(payload.get("created_at")) or datetime.now(timezone.utc)
    expires_at = _parse_datetime(payload.get("expires_at")) or created_at
    used_at = _parse_datetime(payload.get("used_at"))

    return FirestoreInvitation(
        invite_id=invite_id,
        role=role,
        created_by=str(payload.get("created_by") or "").strip(),
        target_email=_normalize_email(payload.get("target_email")),
        expires_at=expires_at,
        used=bool(payload.get("used") or False),
        used_by=_normalize_email(payload.get("used_by")),
        used_at=used_at,
        created_at=created_at,
    )


def _generate_invite_id(length: int = 10) -> str:
    return "".join(secrets.choice(_INVITATION_ALPHABET) for _ in range(length))


def list_invitations() -> list[FirestoreInvitation]:
    client = get_firestore_client()
    docs = client.collection("invitations").stream()
    result: list[FirestoreInvitation] = []
    for doc in docs:
        invitation = _invitation_from_payload(doc.to_dict() or {}, fallback_invite_id=doc.id)
        if invitation is not None:
            result.append(invitation)
    result.sort(key=lambda item: item.created_at, reverse=True)
    return result


def create_invitation(
    *,
    role: str,
    created_by: str,
    target_email: str | None = None,
    expire_days: int = 7,
) -> FirestoreInvitation:
    client = get_firestore_client()
    normalized_role = _normalize_role(role)
    normalized_email = _normalize_email(target_email)
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(days=max(1, expire_days))

    invite_id = _generate_invite_id()
    for _ in range(5):
        snap = client.collection("invitations").document(invite_id).get()
        if not snap.exists:
            break
        invite_id = _generate_invite_id()

    payload: dict[str, Any] = {
        "invite_id": invite_id,
        "role": normalized_role,
        "created_by": str(created_by or "").strip(),
        "target_email": normalized_email,
        "expires_at": expires_at.isoformat(),
        "used": False,
        "used_by": None,
        "used_at": None,
        "created_at": now.isoformat(),
    }
    client.collection("invitations").document(invite_id).set(payload)

    invitation = _invitation_from_payload(payload)
    if invitation is None:
        raise RuntimeError("Failed to build invitation payload")
    return invitation


def validate_user_invitation(
    invite_code: str,
    role_name: str,
    email: str,
) -> FirestoreInvitation | None:
    normalized_code = str(invite_code or "").strip().upper()
    if not normalized_code:
        return None

    client = get_firestore_client()
    snap = client.collection("invitations").document(normalized_code).get()
    if not snap.exists:
        return None

    invitation = _invitation_from_payload(snap.to_dict() or {}, fallback_invite_id=normalized_code)
    if invitation is None:
        return None
    if invitation.used:
        return None
    if invitation.expires_at <= datetime.now(timezone.utc):
        return None
    if invitation.role != _normalize_role(role_name):
        return None

    normalized_email = _normalize_email(email)
    if invitation.target_email and invitation.target_email != normalized_email:
        return None

    return invitation


def mark_invitation_used(invite_id: str, used_by: str) -> None:
    normalized_invite_id = str(invite_id or "").strip().upper()
    if not normalized_invite_id:
        return

    client = get_firestore_client()
    client.collection("invitations").document(normalized_invite_id).set(
        {
            "used": True,
            "used_by": _normalize_email(used_by),
            "used_at": datetime.now(timezone.utc).isoformat(),
        },
        merge=True,
    )
