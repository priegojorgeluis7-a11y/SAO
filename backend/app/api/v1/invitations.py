from typing import Any

from fastapi import APIRouter, Depends, status

from app.api.deps import require_any_role
from app.schemas.invitations import InvitationCreateRequest, InvitationResponse
from app.services.audit_service import write_firestore_audit_log
from app.services.invitation_service import create_invitation, list_invitations

router = APIRouter(prefix="/invitations", tags=["invitations"])


def _serialize_invitation(invitation: Any) -> InvitationResponse:
    if isinstance(invitation, dict):
        payload = invitation
    else:
        payload = {
            "invite_id": getattr(invitation, "invite_id", ""),
            "role": getattr(invitation, "role", ""),
            "created_by": getattr(invitation, "created_by", ""),
            "target_email": getattr(invitation, "target_email", None),
            "expires_at": getattr(invitation, "expires_at", None),
            "used": getattr(invitation, "used", False),
            "used_by": getattr(invitation, "used_by", None),
            "used_at": getattr(invitation, "used_at", None),
            "created_at": getattr(invitation, "created_at", None),
        }
    return InvitationResponse(**payload)


@router.get("", response_model=list[InvitationResponse])
def list_admin_invitations(
    _current_user: Any = Depends(require_any_role(["ADMIN", "SUPERVISOR"])),
):
    return [_serialize_invitation(item) for item in list_invitations()]


@router.post("", response_model=InvitationResponse, status_code=status.HTTP_201_CREATED)
def create_admin_invitation(
    payload: InvitationCreateRequest,
    current_user: Any = Depends(require_any_role(["ADMIN"])),
):
    created = create_invitation(
        role=payload.role,
        created_by=str(getattr(current_user, "email", "") or getattr(current_user, "id", "")),
        target_email=payload.target_email,
        expire_days=payload.expire_days,
    )
    response = _serialize_invitation(created)
    write_firestore_audit_log(
        action="INVITATION_CREATE",
        entity="invitation",
        entity_id=response.invite_id,
        actor=current_user,
        details={
            "role": response.role,
            "target_email": response.target_email,
            "expires_at": response.expires_at.isoformat(),
            "invite_id": response.invite_id,
        },
    )
    return response
