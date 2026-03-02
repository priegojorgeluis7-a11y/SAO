from sqlalchemy import Column, String, Integer, DateTime, Text, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid

from app.models.base import BaseModel


class Evidence(BaseModel):
    __tablename__ = "evidences"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    # Activities in this backend are keyed by `uuid` (string)
    activity_id = Column(UUID(as_uuid=True), ForeignKey("activities.uuid", ondelete="CASCADE"), nullable=False, index=True)

    # Set only after upload-complete verifies object existence in GCS
    object_path = Column(Text, nullable=True)
    pending_object_path = Column(Text, nullable=True)

    mime_type = Column(String(255), nullable=False)
    size_bytes = Column(Integer, nullable=False)
    original_file_name = Column(String(255), nullable=True)
    caption = Column(Text, nullable=True)

    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    uploaded_at = Column(DateTime(timezone=True), nullable=True)

    activity = relationship("Activity", primaryjoin="Evidence.activity_id == Activity.uuid")
    creator = relationship("User", foreign_keys=[created_by])

    __table_args__ = (
        Index("idx_evidences_activity_created", "activity_id", "created_at"),
    )

    def __repr__(self):
        return f"<Evidence(id={self.id}, activity_id={self.activity_id}, uploaded={self.object_path is not None})>"
