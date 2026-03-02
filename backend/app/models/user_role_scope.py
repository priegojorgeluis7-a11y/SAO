from sqlalchemy import Column, String, Integer, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid
from app.models.base import BaseModel


class UserRoleScope(BaseModel):
    __tablename__ = "user_role_scopes"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    role_id = Column(Integer, ForeignKey("roles.id", ondelete="CASCADE"), nullable=False)
    
    # Scopes (NULL = todos)
    project_id = Column(String(10), ForeignKey("projects.id", ondelete="CASCADE"), nullable=True)
    front_id = Column(UUID(as_uuid=True), nullable=True)  # FK to fronts (will be added in migration)
    location_id = Column(UUID(as_uuid=True), nullable=True)  # FK to locations (will be added in migration)
    
    # Metadata
    assigned_by_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    valid_until = Column(DateTime(timezone=True), nullable=True)
    
    # Relationships
    user = relationship("User", foreign_keys=[user_id], back_populates="role_scopes")
    role = relationship("Role", back_populates="user_scopes")
    assigned_by = relationship("User", foreign_keys=[assigned_by_id])
    
    __table_args__ = (
        Index('idx_user_role_scope', 'user_id', 'project_id', 'front_id'),
    )
    
    def __repr__(self):
        return f"<UserRoleScope(user_id={self.user_id}, role_id={self.role_id})>"
