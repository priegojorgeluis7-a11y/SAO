from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class AuditLogOut(BaseModel):
    id: UUID
    created_at: datetime
    actor_id: UUID | None = None
    actor_email: str | None = None
    actor_name: str | None = None
    actor_role: str | None = None
    action: str
    entity: str
    entity_id: str
    details_json: str | None = None

    model_config = ConfigDict(from_attributes=True)
