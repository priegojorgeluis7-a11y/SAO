import json
import logging

from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.models.audit_log import AuditLog
from app.models.user import User


logger = logging.getLogger(__name__)


def write_audit_log(
    db: Session,
    *,
    action: str,
    entity: str,
    entity_id: str,
    actor: User | None,
    details: dict | None = None,
) -> AuditLog | None:
    log = AuditLog(
        actor_id=actor.id if actor else None,
        actor_email=actor.email if actor else None,
        action=action,
        entity=entity,
        entity_id=entity_id,
        details_json=json.dumps(details or {}),
    )

    try:
        with db.begin_nested():
            db.add(log)
            db.flush([log])
        return log
    except SQLAlchemyError:
        logger.warning(
            "Skipping audit log because persistence is unavailable",
            exc_info=True,
        )
        return None
