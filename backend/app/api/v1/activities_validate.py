# backend/app/api/v1/activities_validate.py
"""Activity validation endpoint - pre-submit gatekeeper for mobile UI"""

import logging
from typing import Any

from fastapi import APIRouter, Depends, status

from app.core.api_errors import api_error
from app.core.firestore import get_firestore_client
from app.schemas.activity import ActivityCreate, ActivityUpdate
from app.api.deps import get_current_user

router = APIRouter(prefix="/activities/validate", tags=["activities-validate"])
logger = logging.getLogger(__name__)


class ValidationError:
    def __init__(self, field: str, message: str, code: str):
        self.field = field
        self.message = message
        self.code = code

    def to_dict(self) -> dict:
        return {
            "field": self.field,
            "message": self.message,
            "code": self.code,
        }


@router.post("/submit", status_code=status.HTTP_200_OK)
def validate_activity_submit(
    payload: ActivityCreate,
    current_user: Any = Depends(get_current_user),
):
    """
    Pre-submit validation gatekeeper.
    
    Called before mobile submits activity to backend.
    Returns 200 OK + empty errors list if valid.
    Returns 200 OK + errors list if validation fails (so UI can display them).
    
    Mobile should NOT call POST /activities if this returns errors.
    """
    errors: list[ValidationError] = []

    # ===== BASIC FIELDS =====
    if not payload.uuid or str(payload.uuid).strip() == "":
        errors.append(ValidationError("uuid", "UUID is required", "MISSING_UUID"))

    if not payload.project_id or payload.project_id.strip() == "":
        errors.append(ValidationError("project_id", "Project is required", "MISSING_PROJECT"))

    if not payload.activity_type_code or payload.activity_type_code.strip() == "":
        errors.append(ValidationError("activity_type_code", "Activity type is required", "MISSING_TYPE"))

    if not payload.catalog_version_id or str(payload.catalog_version_id).strip() == "":
        errors.append(ValidationError("catalog_version_id", "Catalog version is required", "MISSING_CATALOG_VERSION"))

    # Early return if basic fields missing
    if errors:
        return {
            "valid": False,
            "errors": [e.to_dict() for e in errors],
            "message": "Basic validation failed",
        }

    # ===== EXECUTION STATE =====
    if payload.execution_state not in ["PENDIENTE", "EN_CURSO", "REVISION_PENDIENTE", "COMPLETADA"]:
        errors.append(
            ValidationError(
                "execution_state",
                f"Invalid state: {payload.execution_state}",
                "INVALID_STATE",
            )
        )

    # ===== PK RANGE =====
    if payload.pk_start is None:
        errors.append(ValidationError("pk_start", "PK start is required", "MISSING_PK_START"))
    elif payload.pk_start < 0:
        errors.append(ValidationError("pk_start", "PK start must be >= 0", "INVALID_PK_START"))

    if payload.pk_end is not None and payload.pk_start is not None:
        if payload.pk_end < payload.pk_start:
            errors.append(
                ValidationError(
                    "pk_end",
                    "PK end must be >= PK start",
                    "INVALID_PK_RANGE",
                )
            )

    # ===== CATALOG + ACTIVITY TYPE VALIDATION =====
    try:
        client = get_firestore_client()
        project_id = payload.project_id.strip().upper()
        catalog_version_id = str(payload.catalog_version_id).strip()
        activity_type_code = payload.activity_type_code.strip().upper()

        # Get catalog version
        catalog_doc = client.collection("catalog_versions").document(catalog_version_id).get()
        if not catalog_doc.exists:
            errors.append(
                ValidationError(
                    "catalog_version_id",
                    f"Catalog version not found: {catalog_version_id}",
                    "CATALOG_VERSION_NOT_FOUND",
                )
            )
            # Can't validate activity type without catalog
            return {
                "valid": False,
                "errors": [e.to_dict() for e in errors],
                "message": "Catalog validation failed",
            }

        catalog_data = catalog_doc.to_dict() or {}

        # Check if activity type exists in catalog
        activities_in_catalog = catalog_data.get("activities", {})
        if activity_type_code not in activities_in_catalog:
            errors.append(
                ValidationError(
                    "activity_type_code",
                    f"Activity type '{activity_type_code}' not in catalog",
                    "ACTIVITY_TYPE_NOT_IN_CATALOG",
                )
            )
        else:
            # Get activity type spec
            activity_spec = activities_in_catalog[activity_type_code] or {}

            # Validate required fields based on activity spec
            requires_pk = activity_spec.get("requires_pk", False)
            requires_geo = activity_spec.get("requires_geo", False)
            requires_evidence = activity_spec.get("requires_evidence", False)

            if requires_pk and payload.pk_start is None:
                errors.append(
                    ValidationError(
                        "pk_start",
                        f"Activity type '{activity_type_code}' requires PK",
                        "MISSING_PK_FOR_TYPE",
                    )
                )

            if requires_geo:
                if not payload.latitude or payload.latitude.strip() == "":
                    errors.append(
                        ValidationError(
                            "latitude",
                            "Activity type requires geolocation",
                            "MISSING_GEO_LATITUDE",
                        )
                    )
                if not payload.longitude or payload.longitude.strip() == "":
                    errors.append(
                        ValidationError(
                            "longitude",
                            "Activity type requires geolocation",
                            "MISSING_GEO_LONGITUDE",
                        )
                    )

            # Validate geo format if present
            if payload.latitude:
                try:
                    lat = float(payload.latitude)
                    if lat < -90 or lat > 90:
                        raise ValueError("Out of range")
                except (ValueError, TypeError):
                    errors.append(
                        ValidationError(
                            "latitude",
                            "Invalid latitude format",
                            "INVALID_LATITUDE",
                        )
                    )

            if payload.longitude:
                try:
                    lon = float(payload.longitude)
                    if lon < -180 or lon > 180:
                        raise ValueError("Out of range")
                except (ValueError, TypeError):
                    errors.append(
                        ValidationError(
                            "longitude",
                            "Invalid longitude format",
                            "INVALID_LONGITUDE",
                        )
                    )

    except Exception as e:
        logger.error(f"Error validating activity with catalog: {e}")
        errors.append(
            ValidationError(
                "catalog",
                "Error validating against catalog",
                "CATALOG_VALIDATION_ERROR",
            )
        )

    # ===== RESPONSE =====
    is_valid = len(errors) == 0

    return {
        "valid": is_valid,
        "errors": [e.to_dict() for e in errors],
        "message": "Validation successful" if is_valid else "Validation failed",
    }
