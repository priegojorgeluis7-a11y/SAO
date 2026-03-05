from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import require_any_role
from app.core.database import get_db
from app.models.audit_log import AuditLog
from app.models.user import User
from app.schemas.audit import AuditLogOut

router = APIRouter(prefix="/audit", tags=["audit"])


@router.get("", response_model=list[AuditLogOut])
def list_audit_logs(
    actor_email: Optional[str] = Query(None),
    entity: Optional[str] = Query(None),
    action: Optional[str] = Query(None),
    _current_user: User = Depends(require_any_role(["ADMIN", "SUPERVISOR"])),
    db: Session = Depends(get_db),
):
    query = db.query(AuditLog)

    if actor_email and actor_email.strip():
        query = query.filter(AuditLog.actor_email.ilike(f"%{actor_email.strip()}%"))
    if entity and entity.strip():
        query = query.filter(AuditLog.entity == entity.strip().lower())
    if action and action.strip():
        query = query.filter(AuditLog.action == action.strip().upper())

    return query.order_by(AuditLog.created_at.desc()).limit(500).all()
