from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, Text, JSON
from sqlalchemy.dialects.postgresql import JSONB
from app.core.database import Base

JSON_TYPE = JSON().with_variant(JSONB, "postgresql")


class CatalogVersionCurrent(Base):
    __tablename__ = "catalog_version"

    version_id = Column(Text, primary_key=True)
    created_at = Column(DateTime(timezone=True), nullable=True)
    changelog = Column(Text, nullable=True)
    is_current = Column(Boolean, nullable=False)


class CatProject(Base):
    __tablename__ = "cat_projects"

    project_id = Column(Text, primary_key=True)
    name = Column(Text, nullable=False)
    version_id = Column(Text, ForeignKey("catalog_version.version_id"), nullable=False)
    is_active = Column(Boolean, nullable=False)
    updated_at = Column(DateTime(timezone=True), nullable=False)


class CatActivity(Base):
    __tablename__ = "cat_activities"

    activity_id = Column(Text, primary_key=True)
    name = Column(Text, nullable=False)
    description = Column(Text, nullable=True)
    version_id = Column(Text, ForeignKey("catalog_version.version_id"), nullable=False)
    is_active = Column(Boolean, nullable=False)
    updated_at = Column(DateTime(timezone=True), nullable=False)


class CatSubcategory(Base):
    __tablename__ = "cat_subcategories"

    subcategory_id = Column(Text, primary_key=True)
    activity_id = Column(Text, ForeignKey("cat_activities.activity_id"), nullable=False)
    name = Column(Text, nullable=False)
    description = Column(Text, nullable=True)
    version_id = Column(Text, ForeignKey("catalog_version.version_id"), nullable=False)
    is_active = Column(Boolean, nullable=False)
    updated_at = Column(DateTime(timezone=True), nullable=False)


class CatPurpose(Base):
    __tablename__ = "cat_purposes"

    purpose_id = Column(Text, primary_key=True)
    activity_id = Column(Text, ForeignKey("cat_activities.activity_id"), nullable=False)
    subcategory_id = Column(Text, ForeignKey("cat_subcategories.subcategory_id"), nullable=True)
    name = Column(Text, nullable=False)
    version_id = Column(Text, ForeignKey("catalog_version.version_id"), nullable=False)
    is_active = Column(Boolean, nullable=False)
    updated_at = Column(DateTime(timezone=True), nullable=False)


class CatTopic(Base):
    __tablename__ = "cat_topics"

    topic_id = Column(Text, primary_key=True)
    type = Column(Text, nullable=True)
    name = Column(Text, nullable=False)
    description = Column(Text, nullable=True)
    version_id = Column(Text, ForeignKey("catalog_version.version_id"), nullable=False)
    is_active = Column(Boolean, nullable=False)
    updated_at = Column(DateTime(timezone=True), nullable=False)


class RelActivityTopic(Base):
    __tablename__ = "rel_activity_topics"

    activity_id = Column(Text, ForeignKey("cat_activities.activity_id"), primary_key=True)
    topic_id = Column(Text, ForeignKey("cat_topics.topic_id"), primary_key=True)
    version_id = Column(Text, ForeignKey("catalog_version.version_id"), nullable=False)
    is_active = Column(Boolean, nullable=False)
    updated_at = Column(DateTime(timezone=True), nullable=False)


class CatResult(Base):
    __tablename__ = "cat_results"

    result_id = Column(Text, primary_key=True)
    name = Column(Text, nullable=False)
    category = Column(Text, nullable=False)
    severity_default = Column(Text, nullable=True)
    version_id = Column(Text, ForeignKey("catalog_version.version_id"), nullable=False)
    is_active = Column(Boolean, nullable=False)
    updated_at = Column(DateTime(timezone=True), nullable=False)


class CatAttendee(Base):
    __tablename__ = "cat_attendees"

    attendee_id = Column(Text, primary_key=True)
    type = Column(Text, nullable=False)
    name = Column(Text, nullable=False)
    description = Column(Text, nullable=True)
    version_id = Column(Text, ForeignKey("catalog_version.version_id"), nullable=False)
    is_active = Column(Boolean, nullable=False)
    updated_at = Column(DateTime(timezone=True), nullable=False)


class ProjCatalogOverride(Base):
    __tablename__ = "proj_catalog_override"

    project_id = Column(Text, ForeignKey("cat_projects.project_id"), primary_key=True)
    entity_type = Column(Text, primary_key=True)
    entity_id = Column(Text, primary_key=True)
    is_enabled = Column(Boolean, nullable=True)
    display_name_override = Column(Text, nullable=True)
    sort_order_override = Column(Integer, nullable=True)
    color_override = Column(Text, nullable=True)
    severity_override = Column(Text, nullable=True)
    rules_json = Column(JSON_TYPE, nullable=True)
    version_id = Column(Text, ForeignKey("catalog_version.version_id"), nullable=False)
    is_active = Column(Boolean, nullable=False)
    updated_at = Column(DateTime(timezone=True), nullable=False)
