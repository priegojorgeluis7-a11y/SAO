import json as _json
import uuid as _uuid_mod
from datetime import datetime, timezone
from typing import Any, Optional

from fastapi import APIRouter, Depends, Query

from app.api.deps import require_any_role
from app.core.firestore import get_firestore_client
from app.schemas.audit import AuditLogOut
from app.services.audit_redaction import sanitize_audit_details_json

router = APIRouter(prefix="/audit", tags=["audit"])

_EPOCH = datetime(2020, 1, 1, tzinfo=timezone.utc)


@router.get("", response_model=list[AuditLogOut])
def list_audit_logs(
    actor_email: Optional[str] = Query(None),
    entity: Optional[str] = Query(None),
    action: Optional[str] = Query(None),
    _current_user: Any = Depends(require_any_role(["ADMIN", "SUPERVISOR"])),
):
    client = get_firestore_client()
    actor_q = actor_email.strip().lower() if actor_email and actor_email.strip() else None
    entity_q = entity.strip().lower() if entity and entity.strip() else None
    action_q = action.strip().upper() if action and action.strip() else None

    # Push the most selective equality filter to Firestore (single-field index,
    # auto-created). Only one server-side .where() to avoid composite index.
    # Remaining filters are applied Python-side below.
    query = client.collection("audit_logs")
    if entity_q:
        query = query.where("entity", "==", entity_q)
    elif action_q:
        query = query.where("action", "==", action_q)
    # Limit server-side to avoid pulling thousands of docs for every request.
    # Python-side sort + truncation to 500 handles final ordering.
    raw_docs = [d.to_dict() or {} for d in query.limit(500).stream()]

    result: list[AuditLogOut] = []
    for doc in raw_docs:
        if actor_q and actor_q not in str(doc.get("actor_email") or "").lower():
            continue
        if entity_q and str(doc.get("entity") or "").lower() != entity_q:
            continue
        if action_q and str(doc.get("action") or "").upper() != action_q:
            continue
        try:
            log_id_raw = doc.get("id")
            log_id = _uuid_mod.UUID(str(log_id_raw)) if log_id_raw else _uuid_mod.uuid4()
            actor_id_raw = doc.get("actor_id")
            actor_id = _uuid_mod.UUID(str(actor_id_raw)) if actor_id_raw else None
            details = doc.get("details_json")
            if isinstance(details, dict):
                details = _json.dumps(details)
            result.append(AuditLogOut(
                id=log_id,
                created_at=doc.get("created_at") or _EPOCH,
                actor_id=actor_id,
                actor_email=doc.get("actor_email"),
                action=str(doc.get("action") or ""),
                entity=str(doc.get("entity") or ""),
                entity_id=str(doc.get("entity_id") or ""),
                details_json=sanitize_audit_details_json(details),
            ))
        except Exception:
            pass

    result.sort(key=lambda r: r.created_at, reverse=True)
    return result[:500]
