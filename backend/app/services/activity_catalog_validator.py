"""Validation helpers for activity payload catalog bindings."""

from uuid import UUID

from sqlalchemy.orm import Session

from app.models.catalog import CATActivityType, CatalogVersion


class ActivityCatalogValidationError(ValueError):
    """Raised when an activity payload references an invalid catalog binding."""

    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


def validate_activity_catalog_binding(
    db: Session,
    *,
    project_id: str,
    catalog_version_id: UUID,
    activity_type_code: str,
) -> None:
    """Validate that activity_type_code belongs to catalog_version_id for the same project."""
    version = db.query(CatalogVersion).filter(CatalogVersion.id == catalog_version_id).first()
    if version is None:
        raise ActivityCatalogValidationError(
            code="CATALOG_VERSION_NOT_FOUND",
            message=f"catalog_version_id {catalog_version_id} does not exist",
        )

    if version.project_id != project_id:
        raise ActivityCatalogValidationError(
            code="CATALOG_PROJECT_MISMATCH",
            message=(
                f"catalog_version_id {catalog_version_id} belongs to project "
                f"{version.project_id}, not {project_id}"
            ),
        )

    activity_type = (
        db.query(CATActivityType)
        .filter(
            CATActivityType.version_id == catalog_version_id,
            CATActivityType.code == activity_type_code,
            CATActivityType.is_active.is_(True),
        )
        .first()
    )
    if activity_type is None:
        raise ActivityCatalogValidationError(
            code="ACTIVITY_TYPE_NOT_IN_CATALOG_VERSION",
            message=(
                f"activity_type_code {activity_type_code} is not active for "
                f"catalog_version_id {catalog_version_id}"
            ),
        )
