from sqlalchemy import Column, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
import uuid
from app.core.database import Base


class Location(Base):
    __tablename__ = "locations"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    estado = Column(String(100), nullable=False)
    municipio = Column(String(100), nullable=False)
    
    __table_args__ = (
        UniqueConstraint('estado', 'municipio', name='uq_location_estado_municipio'),
    )
    
    def __repr__(self):
        return f"<Location(estado={self.estado}, municipio={self.municipio})>"
