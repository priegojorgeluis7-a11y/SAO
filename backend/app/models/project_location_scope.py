from sqlalchemy import Boolean, Column, ForeignKey, Index, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
import uuid

from app.models.base import BaseModel


class ProjectLocationScope(BaseModel):
    __tablename__ = "project_location_scopes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    project_id = Column(
        ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    location_id = Column(
        UUID(as_uuid=True),
        ForeignKey("locations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    is_active = Column(Boolean, nullable=False, default=True)

    __table_args__ = (
        UniqueConstraint("project_id", "location_id", name="uq_project_location_scope"),
        Index("idx_project_location_scope_project", "project_id"),
        Index("idx_project_location_scope_location", "location_id"),
    )
