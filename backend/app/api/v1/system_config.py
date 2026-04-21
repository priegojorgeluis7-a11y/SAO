"""System-wide configuration endpoints (admin-only writes, authenticated reads)."""

import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.api.deps import get_current_user
from app.core.firestore import get_firestore_client

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/system", tags=["system"])

_COLLECTION = "system_config"
_DOC_ID = "global"

# Hardcoded fallback calendar ID (used before any admin configures it)
_DEFAULT_CALENDAR_ID = (
    "7874f5cb85c43eba5ba24e8b710c1b2fac0d8f64106f0cdfddb6bb14441bc151"
    "@group.calendar.google.com"
)


class SystemConfig(BaseModel):
    google_calendar_id: str | None = None


class SystemConfigUpdate(BaseModel):
    google_calendar_id: str


def _is_admin(user: Any) -> bool:
    roles = [str(r).strip().upper() for r in (getattr(user, "roles", []) or [])]
    return "ADMIN" in roles


@router.get("/config", response_model=SystemConfig)
async def get_system_config(
    current_user: Any = Depends(get_current_user),
):
    """Return the current system configuration (any authenticated user)."""
    try:
        db = get_firestore_client()
        doc = db.collection(_COLLECTION).document(_DOC_ID).get()
        if doc.exists:
            data = doc.to_dict() or {}
            return SystemConfig(
                google_calendar_id=data.get("google_calendar_id") or _DEFAULT_CALENDAR_ID
            )
    except Exception as exc:
        logger.warning("system_config read error: %s", exc)
    return SystemConfig(google_calendar_id=_DEFAULT_CALENDAR_ID)


@router.put("/config", response_model=SystemConfig)
async def update_system_config(
    body: SystemConfigUpdate,
    current_user: Any = Depends(get_current_user),
):
    """Update system configuration (ADMIN only)."""
    if not _is_admin(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo ADMIN puede modificar la configuración del sistema.",
        )
    cal_id = body.google_calendar_id.strip()
    if not cal_id:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="google_calendar_id no puede estar vacío.",
        )
    try:
        db = get_firestore_client()
        db.collection(_COLLECTION).document(_DOC_ID).set(
            {"google_calendar_id": cal_id}, merge=True
        )
    except Exception as exc:
        logger.error("system_config write error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al guardar la configuración.",
        )
    return SystemConfig(google_calendar_id=cal_id)
