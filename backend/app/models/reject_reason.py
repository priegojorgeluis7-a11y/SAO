from sqlalchemy import Boolean, Column, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID

from app.models.base import BaseModel


class RejectReason(BaseModel):
    __tablename__ = "reject_reasons"

    reason_code = Column(String(64), primary_key=True)
    label = Column(String(255), nullable=False)
    severity = Column(String(16), nullable=False, default="MED")
    requires_comment = Column(Boolean, nullable=False, default=False)
    is_active = Column(Boolean, nullable=False, default=True)
    created_by_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
