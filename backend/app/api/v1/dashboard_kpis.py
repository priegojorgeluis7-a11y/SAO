# backend/app/api/v1/dashboard_kpis.py
"""KPI endpoints - operational metrics desacoplado de review queue"""

import logging
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.firestore import get_firestore_client
from app.api.deps import get_current_user, resolve_user_project_access, user_has_permission, verify_project_access
from typing import Any

router = APIRouter(prefix="/dashboard", tags=["dashboard-kpis"])
logger = logging.getLogger(__name__)


@router.get("/kpis/operational", status_code=status.HTTP_200_OK)
def get_operational_kpis(
    project_id: str | None = Query(None),
    current_user: Any = Depends(get_current_user),
):
    """
    Get operational KPIs for dashboard.
    
    **Metrics (independent from review queue):**
    - `completed_today`: Activities completed in last 24h
    - `pending_today`: Activities still pending in last 24h
    - `review_queue_count`: Activities pending review (not started)
    - `sla_review_hours`: Target SLA for review (default 24h)
    - `overdue_review_count`: Activities exceeding SLA
    - `backlog_by_state`: Count by execution_state
    - `completion_rate`: % of activities completed vs total
    
    **Optional filters:**
    - `project_id`: If omitted, aggregates all accessible projects
    
    **Response includes:**
    - Timestamp (server time)
    - Calculated metrics
    - Cache hint (how long data can be cached)
    """
    try:
        client = get_firestore_client()
        now = datetime.now(timezone.utc)
        today_midnight = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)
        yesterday = today_midnight - timedelta(days=1)

        # ===== DETERMINE SCOPE =====
        # If project_id provided, query that project
        # Otherwise, accessible projects for user
        if project_id:
            normalized_project_id = project_id.strip().upper()
            verify_project_access(current_user, normalized_project_id, None)
            if not user_has_permission(current_user, "activity.view", None, project_id=normalized_project_id):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Missing permission: activity.view for project: {normalized_project_id}",
                )
            project_ids = [normalized_project_id]
        else:
            has_global_scope, allowed_project_ids = resolve_user_project_access(current_user)
            if has_global_scope:
                project_ids = [
                    str((doc.to_dict() or {}).get("id") or doc.id).strip().upper()
                    for doc in client.collection("projects").stream()
                    if str((doc.to_dict() or {}).get("id") or doc.id).strip()
                ]
            else:
                project_ids = [
                    pid for pid in sorted(allowed_project_ids)
                    if user_has_permission(current_user, "activity.view", None, project_id=pid)
                ]

        if not project_ids:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No accessible projects",
            )

        # ===== QUERY ACTIVITIES =====
        all_activities = []
        for pid in project_ids:
            docs = list(
                client.collection("activities")
                .where("project_id", "==", pid)
                .stream()
            )
            for doc in docs:
                payload = doc.to_dict() or {}
                if payload.get("deleted_at") is not None:
                    continue
                all_activities.append(payload)

        if not all_activities:
            return {
                "timestamp": now.isoformat(),
                "project_id": project_id,
                "completed_today": 0,
                "pending_today": 0,
                "review_queue_count": 0,
                "overdue_review_count": 0,
                "backlog_by_state": {
                    "PENDIENTE": 0,
                    "EN_CURSO": 0,
                    "REVISION_PENDIENTE": 0,
                    "COMPLETADA": 0,
                },
                "completion_rate": 0.0,
                "sla_review_hours": 24,
                "cache_seconds": 300,
            }

        # ===== CALCULATE METRICS =====
        completed_today = 0
        pending_today = 0
        review_queue = 0
        overdue_review = 0
        backlog_by_state = {
            "PENDIENTE": 0,
            "EN_CURSO": 0,
            "REVISION_PENDIENTE": 0,
            "COMPLETADA": 0,
        }
        total_activities = len(all_activities)

        sla_review_hours = 24
        sla_threshold = now - timedelta(hours=sla_review_hours)

        for activity in all_activities:
            state = activity.get("execution_state", "PENDIENTE")
            created_at_str = activity.get("created_at")
            updated_at_str = activity.get("updated_at")

            # Count by state
            if state in backlog_by_state:
                backlog_by_state[state] += 1

            # Parse timestamps
            try:
                if isinstance(created_at_str, str):
                    created_at = datetime.fromisoformat(created_at_str.replace("Z", "+00:00"))
                else:
                    created_at = created_at_str
            except (ValueError, TypeError, AttributeError):
                created_at = now

            try:
                if isinstance(updated_at_str, str):
                    updated_at = datetime.fromisoformat(updated_at_str.replace("Z", "+00:00"))
                else:
                    updated_at = updated_at_str
            except (ValueError, TypeError, AttributeError):
                updated_at = now

            # Completed today?
            if state == "COMPLETADA" and updated_at >= yesterday:
                completed_today += 1

            # Pending today? (still PENDIENTE or EN_CURSO as of today)
            if state in {"PENDIENTE", "EN_CURSO"} and created_at >= yesterday:
                pending_today += 1

            # Review queue?
            if state == "REVISION_PENDIENTE":
                review_queue += 1

                # Overdue?
                if created_at < sla_threshold:
                    overdue_review += 1

        # Completion rate
        completion_rate = (completed_today / total_activities * 100) if total_activities > 0 else 0.0

        logger.info(
            f"KPIs computed: project={project_id}, "
            f"completed_today={completed_today}, pending_today={pending_today}, "
            f"review_queue={review_queue}, overdue={overdue_review}"
        )

        # ===== RESPONSE =====
        return {
            "timestamp": now.isoformat(),
            "project_id": project_id or "ALL",
            "completed_today": completed_today,
            "pending_today": pending_today,
            "review_queue_count": review_queue,
            "overdue_review_count": overdue_review,
            "backlog_by_state": backlog_by_state,
            "completion_rate": round(completion_rate, 2),
            "total_activities": total_activities,
            "sla_review_hours": sla_review_hours,
            "sla_threshold_timestamp": sla_threshold.isoformat(),
            "cache_seconds": 300,  # Hint: frontend can cache for 5 min
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error computing KPIs: {e}")
        return {
            "error": str(e),
            "completed_today": 0,
            "pending_today": 0,
            "review_queue_count": 0,
            "backlog_by_state": {},
        }


@router.get("/kpis/daily-trend", status_code=status.HTTP_200_OK)
def get_daily_kpi_trend(
    project_id: str | None = Query(None),
    days: int = Query(7, ge=1, le=90),
    current_user: Any = Depends(get_current_user),
):
    """
    Get daily KPI trend (last N days).
    
    **Response:**
    - Array of daily snapshots with metrics
    - Useful for charts: completion trend, backlog evolution
    """
    try:
        client = get_firestore_client()
        now = datetime.now(timezone.utc)

        if project_id:
            project_ids = [project_id.strip().upper()]
        else:
            project_ids = getattr(current_user, "project_ids", [])
            if not project_ids:
                return {"error": "No accessible projects", "trend": []}

        daily_trend = []

        for day_offset in range(days):
            day = datetime(
                now.year, now.month, now.day, tzinfo=timezone.utc
            ) - timedelta(days=day_offset)
            day_start = day
            day_end = day + timedelta(days=1)

            completed_count = 0
            pending_count = 0

            for pid in project_ids:
                docs = list(
                    client.collection("activities")
                    .where("project_id", "==", pid)
                    .where("updated_at", ">=", day_start.isoformat())
                    .where("updated_at", "<", day_end.isoformat())
                    .stream()
                )

                for doc in docs:
                    activity = doc.to_dict() or {}
                    if activity.get("deleted_at") is not None:
                        continue
                    state = activity.get("execution_state", "PENDIENTE")
                    if state == "COMPLETADA":
                        completed_count += 1
                    elif state in {"PENDIENTE", "EN_CURSO"}:
                        pending_count += 1

            daily_trend.append({
                "date": day.date().isoformat(),
                "completed": completed_count,
                "pending": pending_count,
                "total": completed_count + pending_count,
            })

        return {
            "project_id": project_id or "ALL",
            "days": days,
            "trend": daily_trend,
        }

    except Exception as e:
        logger.error(f"Error computing daily KPI trend: {e}")
        return {
            "error": str(e),
            "trend": [],
        }
