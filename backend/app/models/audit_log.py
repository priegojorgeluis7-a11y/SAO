import uuid

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.models.base import BaseModel


class AuditLog(BaseModel):
    __tablename__ = "audit_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    sync_version = Column(Integer, default=0, nullable=False, index=True)
    deleted_at = Column(DateTime, nullable=True, index=True)
    actor_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    actor_email = Column(String(255), nullable=True)
    action = Column(String(64), nullable=False, index=True)
    entity = Column(String(64), nullable=False, index=True)
    entity_id = Column(String(128), nullable=False, index=True)
    details_json = Column(Text, nullable=True)

    actor = relationship("User", foreign_keys=[actor_id])
