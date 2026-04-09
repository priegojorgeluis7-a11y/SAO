# backend/app/api/v1/reports_generate.py
"""Auditable reports generation endpoint"""

import hashlib
import json
import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, Query, status

from app.core.api_errors import api_error
from app.core.firestore import get_firestore_client
from app.api.deps import get_current_user, require_any_role
from app.services.audit_service import write_firestore_audit_log

router = APIRouter(prefix="/reports", tags=["reports"])
logger = logging.getLogger(__name__)


class ReportGenerateRequest:
    def __init__(
        self,
        project_id: str,
        date_from: str | None = None,
        date_to: str | None = None,
        status_filter: str | None = None,
        front_id: str | None = None,
    ):
        self.project_id = project_id
        self.date_from = date_from
        self.date_to = date_to
        self.status_filter = status_filter
        self.front_id = front_id


@router.post("/generate", status_code=status.HTTP_200_OK)
def generate_report(
    project_id: str = Query(..., min_length=1),
    date_from: str | None = Query(None),
    date_to: str | None = Query(None),
    status_filter: str | None = Query(None),
    front_id: str | None = Query(None),
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "LECTOR"])),
):
    """
    Generate auditable report.
    
    **Filters:**
    - `project_id`: Required project
    - `date_from`: ISO8601 start date (optional)
    - `date_to`: ISO8601 end date (optional)
    - `status_filter`: PENDIENTE | EN_CURSO | REVISION_PENDIENTE | COMPLETADA (optional)
    - `front_id`: Filter by front/segment UUID (optional)
    
    **Response includes:**
    - `data`: Array of activities matching filters
    - `generated_at`: Server timestamp (UTC)
    - `generated_by_user_id`: Who generated the report
    - `hash`: SHA256 of report data + metadata (for verification)
    - `trace_id`: Correlation ID for audit trail
    - `pagination`: count, limit, offset (if applicable)
    
    **Audit trail:**
    - Logged with generated_at, filters, user_id
    - Hash allows verification that PDF/export matches backend data
    """
    try:
        client = get_firestore_client()
        now = datetime.now(timezone.utc)
        trace_id = f"report-{now.timestamp()}-{current_user.id}"

        # ===== QUERY ACTIVITIES =====
        project_id_upper = project_id.strip().upper()
        
        query = client.collection("activities").where("project_id", "==", project_id_upper)

        # Apply filters
        if status_filter:
            query = query.where("execution_state", "==", status_filter.strip().upper())

        if front_id:
            query = query.where("front_id", "==", front_id.strip())

        # Date range (simple string comparison for ISO8601)
        if date_from:
            query = query.where("created_at", ">=", date_from)
        if date_to:
            query = query.where("created_at", "<=", date_to)

        # Execute query
        docs = list(query.stream())
        activities = [doc.to_dict() for doc in docs if doc.to_dict()]

        # ===== BUILD RESPONSE =====
        report_data = []
        for activity in activities:
            report_data.append({
                "uuid": activity.get("uuid"),
                "project_id": activity.get("project_id"),
                "execution_state": activity.get("execution_state"),
                "activity_type_code": activity.get("activity_type_code"),
                "title": activity.get("title"),
                "pk_start": activity.get("pk_start"),
                "pk_end": activity.get("pk_end"),
                "created_at": activity.get("created_at"),
                "updated_at": activity.get("updated_at"),
                "assigned_to_user_id": activity.get("assigned_to_user_id"),
                "latitude": activity.get("latitude"),
                "longitude": activity.get("longitude"),
            })

        # ===== COMPUTE HASH FOR VERIFICATION =====
        # Hash includes: data + generation time + filters
        # This allows verification that nothing was altered after generation
        hashable_content = json.dumps(
            {
                "data": report_data,
                "generated_at": now.isoformat(),
                "generated_by": str(current_user.id),
                "filters": {
                    "project_id": project_id_upper,
                    "date_from": date_from,
                    "date_to": date_to,
                    "status_filter": status_filter,
                    "front_id": front_id,
                },
            },
            sort_keys=True,
        )
        report_hash = hashlib.sha256(hashable_content.encode()).hexdigest()

        # ===== AUDIT LOG =====
        write_firestore_audit_log(
            user_id=str(current_user.id),
            action="REPORT_GENERATE",
            resource_type="Report",
            resource_id=trace_id,
            project_id=project_id_upper,
            changes={
                "generated_at": now.isoformat(),
                "report_hash": report_hash,
                "activity_count": len(report_data),
                "filters": {
                    "date_from": date_from,
                    "date_to": date_to,
                    "status": status_filter,
                    "front_id": front_id,
                },
            },
            details=f"Report generated by {current_user.full_name} ({current_user.email}) for project {project_id_upper}",
        )

        logger.info(
            f"Report generated: "
            f"project={project_id_upper}, "
            f"activities={len(report_data)}, "
            f"trace={trace_id}, "
            f"hash={report_hash[:16]}..., "
            f"user={current_user.email}"
        )

        # ===== RESPONSE =====
        return {
            "trace_id": trace_id,
            "generated_at": now.isoformat(),
            "generated_by_user_id": str(current_user.id),
            "generated_by_name": current_user.full_name,
            "project_id": project_id_upper,
            "filters": {
                "date_from": date_from,
                "date_to": date_to,
                "status": status_filter,
                "front_id": front_id,
            },
            "data": report_data,
            "pagination": {
                "count": len(report_data),
                "limit": None,
                "offset": 0,
            },
            "hash": report_hash,
            "hash_algorithm": "SHA256",
            "message": f"Report generated successfully with {len(report_data)} activities",
        }

    except Exception as e:
        logger.error(f"Error generating report: {e}")
        raise api_error(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            code="REPORT_GENERATION_ERROR",
            message="Error generating report",
        )
