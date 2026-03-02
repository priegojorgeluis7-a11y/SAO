from sqlalchemy import Column, String, Integer, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid
from app.models.base import BaseModel


class Front(BaseModel):
    __tablename__ = "fronts"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(String(10), ForeignKey("projects.id", ondelete="CASCADE"), nullable=False)
    code = Column(String(10), nullable=False)  # 'F1', 'F2'
    name = Column(String(255), nullable=False)
    
    # Cadenamiento (en metros)
    pk_start = Column(Integer, nullable=True)  # e.g., 0 metros
    pk_end = Column(Integer, nullable=True)    # e.g., 60000 metros (60 km)
    
    responsible_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    
    # Relationships
    project = relationship("Project", back_populates="fronts")
    responsible = relationship("User", foreign_keys=[responsible_id])
    
    __table_args__ = (
        Index('idx_front_project', 'project_id'),
    )
    
    def __repr__(self):
        return f"<Front(code={self.code}, project={self.project_id})>"
