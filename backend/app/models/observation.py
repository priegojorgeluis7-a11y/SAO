import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, ForeignKey, String, Text, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.models.base import BaseModel


class Observation(BaseModel):
    __tablename__ = "observations"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    sync_version = Column(Integer, nullable=False, default=0, index=True)
    deleted_at = Column(DateTime, nullable=True, index=True)
    project_id = Column(String(10), ForeignKey("projects.id", ondelete="CASCADE"), nullable=False, index=True)
    activity_id = Column(UUID(as_uuid=True), ForeignKey("activities.uuid", ondelete="CASCADE"), nullable=False, index=True)
    assignee_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    tags_json = Column(Text, nullable=True)
    message = Column(Text, nullable=False)
    severity = Column(String(10), nullable=False, default="MED")
    due_date = Column(DateTime(timezone=True), nullable=True)
    status = Column(String(16), nullable=False, default="OPEN", index=True)
    resolved_at = Column(DateTime(timezone=True), nullable=True)

    assignee_user = relationship("User", foreign_keys=[assignee_user_id])
    project = relationship("Project", foreign_keys=[project_id])
    activity = relationship("Activity", foreign_keys=[activity_id])

    def increment_sync_version(self):
        self.sync_version += 1

    def is_deleted(self) -> bool:
        return self.deleted_at is not None

    def soft_delete(self):
        self.deleted_at = datetime.now(timezone.utc)
        self.increment_sync_version()
