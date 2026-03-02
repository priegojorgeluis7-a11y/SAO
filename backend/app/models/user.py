from sqlalchemy import Column, String, DateTime, Enum as SQLEnum, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid
from app.models.base import BaseModel
import enum


class UserStatus(str, enum.Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    LOCKED = "locked"


def _enum_values(enum_cls):
    return [item.value for item in enum_cls]


class User(BaseModel):
    __tablename__ = "users"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    pin_hash = Column(String(255), nullable=True)
    full_name = Column(String(255), nullable=False)
    status = Column(
        SQLEnum(UserStatus, values_callable=_enum_values),
        default=UserStatus.ACTIVE,
        nullable=False,
    )
    last_login_at = Column(DateTime(timezone=True), nullable=True)
    
    # Relationships
    role_scopes = relationship("UserRoleScope", foreign_keys="UserRoleScope.user_id", back_populates="user", cascade="all, delete-orphan")
    
    __table_args__ = (
        Index('idx_user_email_status', 'email', 'status'),
    )
    
    def __repr__(self):
        return f"<User(email={self.email}, status={self.status})>"
