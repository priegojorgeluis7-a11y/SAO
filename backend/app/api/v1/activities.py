"""Activities API endpoints"""

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.services.activity_service import ActivityService
from app.schemas.activity import (
    ActivityCreate,
    ActivityUpdate,
    ActivityDTO,
    ActivityListResponse,
)

router = APIRouter(prefix="/activities", tags=["activities"])


@router.post("", response_model=ActivityDTO)
async def create_activity(
    activity_data: ActivityCreate,
    response: Response,
    db: Session = Depends(get_db),
    authenticated_user: User = Depends(get_current_user),
):
    """
    Create new activity (idempotent by uuid)
    If activity with uuid already exists, returns existing activity (200)
    Otherwise creates new activity (201)
    """
    service = ActivityService(db)
    
    # Check if activity already exists
    existing = service.get_activity_by_uuid(activity_data.uuid)
    if existing:
        # Return existing activity (idempotent create)
        response.status_code = status.HTTP_200_OK
        return service.to_dto(existing)
    
    # Create new activity
    response.status_code = status.HTTP_201_CREATED
    activity = service.create_activity(activity_data, created_by_user_id=authenticated_user.id)
    return service.to_dto(activity)


@router.get("", response_model=ActivityListResponse)
async def list_activities(
    project_id: str | None = Query(None, description="Filter by project_id"),
    front_id: str | None = Query(None, description="Filter by front_id"),
    execution_state: str | None = Query(None, description="Filter by execution_state"),
    updated_since_sync_version: int | None = Query(None, description="Get activities updated after this sync_version"),
    include_deleted: bool = Query(False, description="Include soft-deleted activities"),
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(50, ge=1, le=100, description="Items per page"),
    db: Session = Depends(get_db),
    _authenticated_user: User = Depends(get_current_user),
):
    """
    List activities with filters and pagination
    Supports incremental sync via updated_since_sync_version parameter
    """
    service = ActivityService(db)
    
    offset = (page - 1) * page_size
    activities, total = service.list_activities(
        project_id=project_id,
        front_id=front_id,
        execution_state=execution_state,
        updated_since_sync_version=updated_since_sync_version,
        include_deleted=include_deleted,
        limit=page_size,
        offset=offset,
    )
    
    return ActivityListResponse(
        items=service.to_dto_list(activities),
        total=total,
        page=page,
        page_size=page_size,
        has_next=offset + len(activities) < total,
    )


@router.get("/{uuid}", response_model=ActivityDTO)
async def get_activity(
    uuid: str,
    db: Session = Depends(get_db),
    _authenticated_user: User = Depends(get_current_user),
):
    """Get activity by uuid"""
    service = ActivityService(db)
    activity = service.get_activity_by_uuid(uuid)
    
    if not activity:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Activity with uuid {uuid} not found"
        )
    
    return service.to_dto(activity)


@router.put("/{uuid}", response_model=ActivityDTO)
async def update_activity(
    uuid: str,
    update_data: ActivityUpdate,
    db: Session = Depends(get_db),
    _authenticated_user: User = Depends(get_current_user),
):
    """
    Update activity by uuid
    Automatically increments sync_version on update
    """
    service = ActivityService(db)
    activity = service.update_activity(uuid, update_data)
    return service.to_dto(activity)


@router.delete("/{uuid}", response_model=ActivityDTO)
async def delete_activity(
    uuid: str,
    db: Session = Depends(get_db),
    _authenticated_user: User = Depends(get_current_user),
):
    """
    Soft delete activity by uuid
    Sets deleted_at timestamp and increments sync_version
    """
    service = ActivityService(db)
    activity = service.soft_delete_activity(uuid)
    return service.to_dto(activity)
