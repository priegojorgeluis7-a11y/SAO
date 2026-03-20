import json
import logging
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from app.core.firestore import get_firestore_client


logger = logging.getLogger(__name__)


def write_firestore_audit_log(
    *,
    action: str,
    entity: str,
    entity_id: str,
    actor: Any | None,
    details: dict | None = None,
) -> None:
    """Write an audit log entry directly to Firestore (Firestore-only path).

    Best-effort: exceptions are logged but never propagated so that a
    failed audit write never aborts the main request.
    """
    try:
        actor_id = str(getattr(actor, "id", "") or "")
        actor_email = str(getattr(actor, "email", "") or "")
        doc = {
            "id": str(uuid4()),
            "created_at": datetime.now(timezone.utc),
            "actor_id": actor_id or None,
            "actor_email": actor_email or None,
            "action": action,
            "entity": entity,
            "entity_id": entity_id,
            "details_json": json.dumps(details or {}),
        }
        get_firestore_client().collection("audit_logs").document(doc["id"]).set(doc)
    except Exception:
        logger.warning(
            "write_firestore_audit_log failed action=%s entity=%s entity_id=%s",
            action, entity, entity_id,
            exc_info=True,
        )
