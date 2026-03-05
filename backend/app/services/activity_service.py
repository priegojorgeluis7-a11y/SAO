"""Activity service for CRUD and business logic"""
from datetime import datetime, timezone
from typing import List, Optional
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.activity import Activity
from app.schemas.activity import ActivityCreate, ActivityUpdate, ActivityDTO


class ActivityService:
    """Service for managing activities with CRUD operations and sync support"""
    
    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _utc_now() -> datetime:
        """Return timezone-aware UTC datetime."""
        return datetime.now(timezone.utc)

    @staticmethod
    def _parse_uuid(value: Optional[str | UUID]) -> Optional[UUID]:
        """Parse an optional UUID string safely, returning None on invalid values."""
        if value is None:
            return None
        try:
            return UUID(value) if isinstance(value, str) else value
        except (ValueError, AttributeError, TypeError):
            return None
    
    def create_activity(self, activity_data: ActivityCreate, created_by_user_id: Optional[UUID] = None) -> Activity:
        """
        Create new activity (idempotent by uuid)
        If activity with uuid already exists, return existing activity
        """
        # Check if activity with this uuid already exists
        existing = self.db.query(Activity).filter(Activity.uuid == activity_data.uuid).first()
        if existing:
            return existing
        
        # Override created_by_user_id if provided as parameter (for auth context)
        if created_by_user_id is not None:
            activity_data.created_by_user_id = created_by_user_id
        
        # Create new activity
        activity = Activity(
            uuid=activity_data.uuid,
            project_id=activity_data.project_id,
            front_id=activity_data.front_id,
            pk_start=activity_data.pk_start,
            pk_end=activity_data.pk_end,
            execution_state=activity_data.execution_state,
            assigned_to_user_id=activity_data.assigned_to_user_id,
            created_by_user_id=activity_data.created_by_user_id,
            catalog_version_id=activity_data.catalog_version_id,
            activity_type_code=activity_data.activity_type_code,
            latitude=activity_data.latitude,
            longitude=activity_data.longitude,
            title=activity_data.title,
            description=activity_data.description,
            sync_version=1,  # Start at 1 for new activities
            created_at=activity_data.created_at or self._utc_now(),
            updated_at=activity_data.updated_at or self._utc_now(),
        )
        
        self.db.add(activity)
        self.db.commit()
        self.db.refresh(activity)
        return activity
    
    def get_activity_by_uuid(self, uuid: str | UUID, include_deleted: bool = False) -> Optional[Activity]:
        """Get activity by uuid"""
        parsed_uuid = self._parse_uuid(uuid)
        if not parsed_uuid:
            return None
        query = self.db.query(Activity).filter(Activity.uuid == parsed_uuid)
        if not include_deleted:
            query = query.filter(Activity.deleted_at.is_(None))
        return query.first()
    
    def get_activity_by_id(self, activity_id: int, include_deleted: bool = False) -> Optional[Activity]:
        """Get activity by server_id"""
        query = self.db.query(Activity).filter(Activity.id == activity_id)
        if not include_deleted:
            query = query.filter(Activity.deleted_at.is_(None))
        return query.first()
    
    def list_activities(
        self,
        project_id: Optional[str] = None,
        front_id: Optional[str] = None,
        execution_state: Optional[str] = None,
        updated_since_sync_version: Optional[int] = None,
        include_deleted: bool = False,
        limit: int = 100,
        offset: int = 0,
    ) -> tuple[List[Activity], int]:
        """
        List activities with filters
        Returns (activities, total_count)
        """
        query = self.db.query(Activity)
        
        # Apply filters
        if project_id:
            query = query.filter(Activity.project_id == project_id)
        if front_id:
            front_uuid = self._parse_uuid(front_id)
            if front_uuid:
                query = query.filter(Activity.front_id == front_uuid)
        if execution_state:
            query = query.filter(Activity.execution_state == execution_state)
        if updated_since_sync_version is not None:
            query = query.filter(Activity.sync_version > updated_since_sync_version)
        if not include_deleted:
            query = query.filter(Activity.deleted_at.is_(None))
        
        # Get total count
        total = query.count()
        
        # Apply pagination and ordering
        activities = query.order_by(Activity.updated_at.desc()).limit(limit).offset(offset).all()
        
        return activities, total
    
    def update_activity(self, uuid: str, update_data: ActivityUpdate) -> Activity:
        """Update activity by uuid"""
        activity = self.get_activity_by_uuid(uuid, include_deleted=False)
        if not activity:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Activity with uuid {uuid} not found"
            )
        
        # Update fields if provided
        update_dict = update_data.model_dump(exclude_unset=True)
        for field, value in update_dict.items():
            setattr(activity, field, value)
        
        # Update sync metadata
        activity.updated_at = self._utc_now()
        activity.increment_sync_version()
        
        self.db.commit()
        self.db.refresh(activity)
        return activity
    
    def soft_delete_activity(self, uuid: str) -> Activity:
        """Soft delete activity by uuid"""
        activity = self.get_activity_by_uuid(uuid, include_deleted=False)
        if not activity:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Activity with uuid {uuid} not found"
            )
        
        activity.soft_delete()
        activity.updated_at = self._utc_now()
        
        self.db.commit()
        self.db.refresh(activity)
        return activity
    
    def get_latest_sync_version(self) -> int:
        """Get the latest sync_version across all activities"""
        result = self.db.query(Activity.sync_version).order_by(Activity.sync_version.desc()).first()
        return result[0] if result else 0

    def _compute_flags(self, activity: Activity) -> dict[str, bool]:
        return {
            "gps_mismatch": bool(activity.gps_mismatch),
            "catalog_changed": bool(activity.catalog_changed),
        }

    def patch_flags(
        self,
        uuid: str,
        gps_mismatch: bool | None,
        catalog_changed: bool | None,
    ) -> Activity:
        """Set structured review flags on an activity without touching other fields."""
        activity = self.get_activity_by_uuid(uuid, include_deleted=False)
        if not activity:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Activity with uuid {uuid} not found",
            )
        if gps_mismatch is not None:
            activity.gps_mismatch = gps_mismatch
        if catalog_changed is not None:
            activity.catalog_changed = catalog_changed
        activity.updated_at = self._utc_now()
        activity.increment_sync_version()
        self.db.commit()
        self.db.refresh(activity)
        return activity

    def to_dto(self, activity: Activity) -> ActivityDTO:
        """Convert Activity model to ActivityDTO"""
        payload = {
            "uuid": activity.uuid,
            "id": activity.id,
            "project_id": activity.project_id,
            "front_id": activity.front_id,
            "pk_start": activity.pk_start,
            "pk_end": activity.pk_end,
            "execution_state": activity.execution_state,
            "assigned_to_user_id": activity.assigned_to_user_id,
            "created_by_user_id": activity.created_by_user_id,
            "catalog_version_id": activity.catalog_version_id,
            "activity_type_code": activity.activity_type_code,
            "latitude": activity.latitude,
            "longitude": activity.longitude,
            "title": activity.title,
            "description": activity.description,
            "flags": self._compute_flags(activity),
            "created_at": activity.created_at,
            "updated_at": activity.updated_at,
            "deleted_at": activity.deleted_at,
            "sync_version": activity.sync_version,
        }
        return ActivityDTO.model_validate(payload)
    
    def to_dto_list(self, activities: List[Activity]) -> List[ActivityDTO]:
        """Convert list of Activity models to ActivityDTOs"""
        return [self.to_dto(activity) for activity in activities]
