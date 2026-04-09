"""Push notification device token registration endpoints."""

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field

from app.api.deps import get_current_user, verify_project_access
from app.services.push_notification_service import (
    disable_device_push_token,
    register_device_push_token,
)

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
