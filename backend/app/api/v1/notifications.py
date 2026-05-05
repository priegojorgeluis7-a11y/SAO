"""Push notification device token registration endpoints and in-app notification center."""

import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel, Field

from app.api.deps import get_current_user, verify_project_access
from app.core.config import settings
from app.schemas.notification import NotificationListResponse, UserNotificationItem
from app.services.notification_service import (
    get_user_notifications,
    mark_all_notifications_read,
    mark_notification_read,
)
from app.services.push_notification_service import (
    disable_device_push_token,
    notify_daily_agenda,
    register_device_push_token,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/notifications", tags=["notifications"])


class DevicePushTokenRequest(BaseModel):
    token: str = Field(..., min_length=20, description="FCM registration token")
    project_id: str = Field(..., min_length=2, description="Project ID (e.g., TMQ)")
    platform: str = Field(default="android", description="Device platform")
    app_version: str | None = Field(default=None, description="App version")


@router.post("/device-tokens", status_code=status.HTTP_204_NO_CONTENT)
def upsert_device_push_token(
    body: DevicePushTokenRequest,
    current_user: Any = Depends(get_current_user),
):
    project_id = body.project_id.strip().upper()
    if not project_id:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="project_id is required",
        )

    verify_project_access(current_user, project_id, None)

    register_device_push_token(
        user_id=str(getattr(current_user, "id", "")).strip(),
        token=body.token,
        project_id=project_id,
        platform=body.platform,
        app_version=body.app_version,
    )


@router.delete("/device-tokens", status_code=status.HTTP_204_NO_CONTENT)
def delete_device_push_token(
    token: str = Query(..., min_length=20, description="FCM registration token"),
    current_user: Any = Depends(get_current_user),
):
    disable_device_push_token(
        user_id=str(getattr(current_user, "id", "")).strip(),
        token=token,
    )


@router.post("/daily-agenda", status_code=status.HTTP_200_OK)
def trigger_daily_agenda(
    request: Request,
    project_id: str | None = Query(default=None, description="Limit to a specific project (optional)"),
):
    """Trigger morning agenda push notifications for all users with activities today.

    Protected by a shared secret passed as a Bearer token in the Authorization header.
    Intended to be called by Cloud Scheduler at 09:00 America/Mexico_City.
    """
    secret = settings.SCHEDULER_SECRET
    if not secret:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Daily agenda notifications are not configured",
        )

    auth_header = request.headers.get("Authorization", "")
    provided = auth_header.removeprefix("Bearer ").strip()
    if provided != secret:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid scheduler secret",
        )

    result = notify_daily_agenda(project_id=project_id)
    logger.info("DAILY_AGENDA_TRIGGER result=%s", result)
    return result


# ---------------------------------------------------------------------------
# In-app notification center
# ---------------------------------------------------------------------------


@router.get("", response_model=NotificationListResponse)
def list_user_notifications(
    unread_only: bool = Query(False, description="Return only unread notifications"),
    limit: int = Query(50, ge=1, le=200, description="Max results"),
    current_user: Any = Depends(get_current_user),
):
    """Fetch the authenticated user's in-app notifications, newest first."""
    user_id = str(getattr(current_user, "id", "")).strip()
    items = get_user_notifications(user_id=user_id, limit=limit, unread_only=unread_only)
    unread_count = sum(1 for n in items if n.status == "unread")
    return NotificationListResponse(items=items, unread_count=unread_count)


@router.post("/{notification_id}/read", status_code=status.HTTP_204_NO_CONTENT)
def mark_notification_as_read(
    notification_id: str,
    current_user: Any = Depends(get_current_user),
):
    """Mark a single notification as read."""
    user_id = str(getattr(current_user, "id", "")).strip()
    success = mark_notification_read(notification_id=notification_id, user_id=user_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found",
        )


@router.post("/read-all", status_code=status.HTTP_200_OK)
def mark_all_as_read(
    current_user: Any = Depends(get_current_user),
):
    """Mark all unread notifications as read for the current user."""
    user_id = str(getattr(current_user, "id", "")).strip()
    count = mark_all_notifications_read(user_id=user_id)
    return {"marked_read": count}
