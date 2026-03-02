from sqlalchemy import Column, String, Date, Enum as SQLEnum
from sqlalchemy.orm import relationship
from app.models.base import BaseModel
import enum


class ProjectStatus(str, enum.Enum):
    ACTIVE = "active"
    ARCHIVED = "archived"


def _enum_values(enum_cls):
    return [item.value for item in enum_cls]


class Project(BaseModel):
    __tablename__ = "projects"
    
    id = Column(String(10), primary_key=True)  # 'TMQ', 'TAP', 'SNL'
    name = Column(String(255), nullable=False)
    status = Column(
        SQLEnum(ProjectStatus, values_callable=_enum_values),
        default=ProjectStatus.ACTIVE,
        nullable=False,
    )
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=True)
    
    # Relationships
    fronts = relationship("Front", back_populates="project", cascade="all, delete-orphan")
    catalog_versions = relationship("CatalogVersion", back_populates="project", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<Project(id={self.id}, name={self.name})>"
