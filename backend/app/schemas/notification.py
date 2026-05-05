"""In-app notification schemas."""
from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class UserNotificationItem(BaseModel):
    id: str
    type: str  # new_assignment | co_responsable_added | assignment_transferred
    activity_id: str
    activity_title: str
    project_id: str
    from_user_id: str | None = None
    from_user_name: str | None = None
    # unread | read | accepted | declined
    status: str
    requires_acceptance: bool
    created_at: datetime
    read_at: datetime | None = None
    responded_at: datetime | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class NotificationListResponse(BaseModel):
    items: list[UserNotificationItem]
    unread_count: int
