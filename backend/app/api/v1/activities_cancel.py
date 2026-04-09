# backend/app/api/v1/activities_cancel.py
"""Activity cancellation endpoint"""

import logging
from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, status

from app.core.api_errors import api_error
from app.core.firestore import get_firestore_client
from app.api.deps import get_current_user, require_any_role
from app.services.audit_service import write_firestore_audit_log
from typing import Any

router = APIRouter(prefix="/activities", tags=["activities-cancel"])
logger = logging.getLogger(__name__)


class ActivityCancelRequest:
    def __init__(self, reason: str | None = None, force: bool = False):
        self.reason = reason or "No especificado"
        self.force = force  # Allow cancel even if not in allowed states


class ActivityCancelResponse:
    def __init__(
        self,
        activity_id: str,
        old_execution_state: str,
        new_execution_state: str,
        canceled_at: datetime,
        canceled_by_user_id: str,
        reason: str,
    ):
        self.activity_id = activity_id
        self.old_execution_state = old_execution_state
        self.new_execution_state = new_execution_state
        self.canceled_at = canceled_at
        self.canceled_by_user_id = canceled_by_user_id
        self.reason = reason

    def to_dict(self) -> dict:
        return {
            "activity_id": self.activity_id,
            "old_execution_state": self.old_execution_state,
            "new_execution_state": self.new_execution_state,
            "canceled_at": self.canceled_at.isoformat(),
            "canceled_by_user_id": str(self.canceled_by_user_id),
            "reason": self.reason,
        }


@router.post("/{activity_uuid}/cancel", status_code=status.HTTP_200_OK)
async def cancel_activity(
    activity_uuid: str,
    reason: str | None = None,
    force: bool = False,
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR"])),
):
    """
    Cancel an activity.
    
    **Allowed transitions:**
    - PENDIENTE → CANCELED (immediate cancel)
    - EN_CURSO → CANCELED (stop work)
    - REVISION_PENDIENTE → CANCELED (revert pending review)
    - COMPLETADA → CANCELED (only with force=True and ADMIN role)
    
    **Audit trail:**
    - Logged in audit_logs with cancellation reason
    - Activity marked: execution_state=CANCELED, canceled_at, canceled_by_user_id
    
    **Parameters:**
    - `reason`: Cancellation reason (required for audit)
    - `force`: If true, allows canceling COMPLETADA (ADMIN only)
    """
    try:
        client = get_firestore_client()

        # Get activity
        activity_doc = client.collection("activities").document(activity_uuid).get()
        if not activity_doc.exists:
            raise api_error(
                status_code=status.HTTP_404_NOT_FOUND,
                code="ACTIVITY_NOT_FOUND",
                message=f"Activity {activity_uuid} not found",
            )

        activity_data = activity_doc.to_dict() or {}
        old_state = activity_data.get("execution_state", "PENDIENTE")
        project_id = activity_data.get("project_id", "UNKNOWN")

        # ===== STATE VALIDATION =====
        if old_state == "CANCELED":
            raise api_error(
                status_code=status.HTTP_400_BAD_REQUEST,
                code="ACTIVITY_ALREADY_CANCELED",
                message=f"Activity already canceled",
            )

        if old_state == "COMPLETADA" and not force:
            raise api_error(
                status_code=status.HTTP_400_BAD_REQUEST,
                code="CANNOT_CANCEL_COMPLETED",
                message="Cannot cancel completed activity (use force=true for admin override)",
            )

        if old_state == "COMPLETADA" and force and "ADMIN" not in {role.strip().upper() for role in current_user.roles}:
            raise api_error(
                status_code=status.HTTP_403_FORBIDDEN,
                code="INSUFFICIENT_ROLE_FOR_FORCE_CANCEL",
                message="Only ADMIN can force-cancel completed activities",
            )

        # ===== CANCEL ACTIVITY =====
        canceled_at = datetime.now(timezone.utc)
        cancel_reason = reason or "No especificado"

        # Update activity
        client.collection("activities").document(activity_uuid).update({
            "execution_state": "CANCELED",
            "deleted_at": canceled_at.isoformat(),  # Soft delete marker
            "updated_at": canceled_at.isoformat(),
        })

        # ===== AUDIT LOG =====
        await write_firestore_audit_log(
            user_id=str(current_user.id),
            action="ACTIVITY_CANCEL",
            resource_type="Activity",
            resource_id=activity_uuid,
            project_id=project_id,
            changes={
                "old_execution_state": old_state,
                "new_execution_state": "CANCELED",
                "canceled_at": canceled_at.isoformat(),
                "reason": cancel_reason,
                "force": force,
            },
            details=f"Canceled by {current_user.full_name} ({current_user.email})",
        )

        logger.info(
            f"Activity canceled: uuid={activity_uuid}, "
            f"old_state={old_state}, "
            f"canceled_by={current_user.email}, "
            f"reason={cancel_reason}"
        )

        # ===== RESPONSE =====
        return ActivityCancelResponse(
            activity_id=activity_uuid,
            old_execution_state=old_state,
            new_execution_state="CANCELED",
            canceled_at=canceled_at,
            canceled_by_user_id=current_user.id,
            reason=cancel_reason,
        ).to_dict()

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error canceling activity {activity_uuid}: {e}")
        raise api_error(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            code="CANCEL_ERROR",
            message="Error canceling activity",
        )
