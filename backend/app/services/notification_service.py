"""In-app notification service.

Creates and retrieves in-app notifications stored in the Firestore
``user_notifications`` collection.  This is distinct from FCM push
notifications (handled in push_notification_service.py) — these records
back the in-app notification center visible inside the mobile and desktop
clients.

Collection structure:
  user_notifications/{notification_id}
    recipient_user_id: str   (UUID)
    type: str                (new_assignment | co_responsable_added | assignment_transferred)
    activity_id: str
    activity_title: str
    project_id: str
    from_user_id: str | None
    from_user_name: str | None
    status: str              (unread | read | accepted | declined)
    requires_acceptance: bool
    created_at: datetime (ISO)
    read_at: datetime | None
    responded_at: datetime | None
    metadata: dict
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from uuid import uuid4
from typing import Any

from app.core.firestore import get_firestore_client
from app.schemas.notification import UserNotificationItem

logger = logging.getLogger(__name__)

_COLLECTION = "user_notifications"


def create_user_notification(
    *,
    recipient_user_id: str,
    notification_type: str,
    activity_id: str,
    activity_title: str,
    project_id: str,
    from_user_id: str | None = None,
    from_user_name: str | None = None,
    requires_acceptance: bool = False,
    metadata: dict[str, Any] | None = None,
) -> str:
    """Create an in-app notification for a user.

    Returns the generated notification ID.
    Silently swallows errors so a notification failure never breaks the
    primary assignment/transfer flow.
    """
    notif_id = str(uuid4())
    now = datetime.now(timezone.utc)
    payload: dict[str, Any] = {
        "id": notif_id,
        "recipient_user_id": str(recipient_user_id or "").strip(),
        "type": str(notification_type or "").strip(),
        "activity_id": str(activity_id or "").strip(),
        "activity_title": str(activity_title or "").strip(),
        "project_id": str(project_id or "").strip().upper(),
        "from_user_id": str(from_user_id or "").strip() or None,
        "from_user_name": str(from_user_name or "").strip() or None,
        "status": "unread",
        "requires_acceptance": bool(requires_acceptance),
        "created_at": now.isoformat(),
        "read_at": None,
        "responded_at": None,
        "metadata": metadata or {},
    }
    try:
        get_firestore_client().collection(_COLLECTION).document(notif_id).set(payload)
        logger.info(
            "USER_NOTIFICATION_CREATED id=%s type=%s recipient=%s activity=%s",
            notif_id,
            notification_type,
            recipient_user_id,
            activity_id,
        )
    except Exception:
        logger.exception(
            "USER_NOTIFICATION_CREATE_FAILED type=%s recipient=%s",
            notification_type,
            recipient_user_id,
        )
    return notif_id


def get_user_notifications(
    *,
    user_id: str,
    limit: int = 50,
    unread_only: bool = False,
) -> list[UserNotificationItem]:
    """Fetch in-app notifications for a user, newest first."""
    normalized_user = str(user_id or "").strip()
    if not normalized_user:
        return []

    try:
        client = get_firestore_client()
        query = (
            client.collection(_COLLECTION)
            .where("recipient_user_id", "==", normalized_user)
            .order_by("created_at", direction="DESCENDING")
            .limit(limit)
        )
        if unread_only:
            query = (
                client.collection(_COLLECTION)
                .where("recipient_user_id", "==", normalized_user)
                .where("status", "==", "unread")
                .order_by("created_at", direction="DESCENDING")
                .limit(limit)
            )

        items: list[UserNotificationItem] = []
        for doc in query.stream():
            data = doc.to_dict() or {}
            try:
                items.append(_doc_to_item(doc.id, data))
            except Exception:
                logger.warning("Skipping malformed notification doc id=%s", doc.id)
        return items
    except Exception:
        logger.exception("GET_USER_NOTIFICATIONS_FAILED user=%s", user_id)
        return []


def mark_notification_read(*, notification_id: str, user_id: str) -> bool:
    """Mark a single notification as read.  Returns True on success."""
    try:
        client = get_firestore_client()
        ref = client.collection(_COLLECTION).document(notification_id)
        snap = ref.get()
        if not snap.exists:
            return False
        data = snap.to_dict() or {}
        if data.get("recipient_user_id") != user_id:
            return False  # safety check
        now = datetime.now(timezone.utc)
        ref.set({"status": "read", "read_at": now.isoformat()}, merge=True)
        return True
    except Exception:
        logger.exception("MARK_NOTIFICATION_READ_FAILED id=%s", notification_id)
        return False


def mark_all_notifications_read(*, user_id: str) -> int:
    """Mark all unread notifications as read.  Returns count updated."""
    normalized_user = str(user_id or "").strip()
    if not normalized_user:
        return 0
    try:
        client = get_firestore_client()
        now = datetime.now(timezone.utc)
        docs = list(
            client.collection(_COLLECTION)
            .where("recipient_user_id", "==", normalized_user)
            .where("status", "==", "unread")
            .stream()
        )
        for doc in docs:
            doc.reference.set(
                {"status": "read", "read_at": now.isoformat()}, merge=True
            )
        return len(docs)
    except Exception:
        logger.exception("MARK_ALL_READ_FAILED user=%s", user_id)
        return 0


def update_notification_response(
    *,
    notification_id: str,
    user_id: str,
    response: str,  # "accepted" | "declined"
) -> bool:
    """Record the user's accept/decline response on a notification."""
    try:
        client = get_firestore_client()
        ref = client.collection(_COLLECTION).document(notification_id)
        snap = ref.get()
        if not snap.exists:
            return False
        data = snap.to_dict() or {}
        if data.get("recipient_user_id") != user_id:
            return False
        now = datetime.now(timezone.utc)
        ref.set(
            {
                "status": response,
                "responded_at": now.isoformat(),
                "read_at": now.isoformat(),
            },
            merge=True,
        )
        return True
    except Exception:
        logger.exception("UPDATE_NOTIFICATION_RESPONSE_FAILED id=%s", notification_id)
        return False


def _doc_to_item(doc_id: str, data: dict[str, Any]) -> UserNotificationItem:
    from app.core.utils import parse_firestore_dt

    def _parse_dt(v: Any) -> datetime | None:
        return parse_firestore_dt(v)

    return UserNotificationItem(
        id=str(data.get("id") or doc_id),
        type=str(data.get("type") or ""),
        activity_id=str(data.get("activity_id") or ""),
        activity_title=str(data.get("activity_title") or ""),
        project_id=str(data.get("project_id") or ""),
        from_user_id=str(data.get("from_user_id") or "") or None,
        from_user_name=str(data.get("from_user_name") or "") or None,
        status=str(data.get("status") or "unread"),
        requires_acceptance=bool(data.get("requires_acceptance", False)),
        created_at=_parse_dt(data.get("created_at")) or datetime.now(timezone.utc),
        read_at=_parse_dt(data.get("read_at")),
        responded_at=_parse_dt(data.get("responded_at")),
        metadata=data.get("metadata") or {},
    )
