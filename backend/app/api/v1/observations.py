import json
from datetime import datetime, timezone
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.deps import require_any_role
from app.core.firestore import get_firestore_client
from typing import Any
from app.schemas.observation import ObservationCreateIn, ObservationOut, ObservationResolveOut

router = APIRouter(tags=["observations"])


@router.post("/observations", response_model=ObservationOut, status_code=status.HTTP_201_CREATED)
def create_observation(
    body: ObservationCreateIn,
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
):
    client = get_firestore_client()
    obs_id = uuid4()
    now = datetime.now(timezone.utc)
    payload = {
        "id": str(obs_id),
        "project_id": body.project_id,
        "activity_id": str(body.activity_id),
        "assignee_user_id": str(body.assignee_user_id) if body.assignee_user_id else None,
        "tags_json": json.dumps(body.tags),
        "message": body.message,
        "severity": body.severity,
        "due_date": body.due_date,
        "status": "OPEN",
        "resolved_at": None,
        "created_at": now,
        "sync_version": 1,
    }
    client.collection("observations").document(str(obs_id)).set(payload)
    client.collection("audit_logs").document(str(uuid4())).set(
        {
            "id": str(uuid4()),
            "created_at": now,
            "actor_id": str(getattr(current_user, "id", "")),
            "actor_email": getattr(current_user, "email", ""),
            "action": "OBSERVATION_CREATED",
            "entity": "observation",
            "entity_id": str(obs_id),
            "details_json": json.dumps(
                {
                    "project_id": body.project_id,
                    "activity_id": str(body.activity_id),
                    "severity": body.severity,
                }
            ),
        }
    )

    return ObservationOut(
        id=obs_id,
        project_id=body.project_id,
        activity_id=body.activity_id,
        assignee_user_id=body.assignee_user_id,
        tags=body.tags,
        message=body.message,
        severity=body.severity,
        due_date=body.due_date,
        status="OPEN",
        resolved_at=None,
        created_at=now,
    )


@router.get("/mobile/observations", response_model=list[ObservationOut])
def list_mobile_observations(
    project_id: str | None = Query(None),
    status_filter: str = Query("open", alias="status"),
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO", "LECTOR"])),
):
    client = get_firestore_client()
    rows = [d.to_dict() or {} for d in client.collection("observations").stream()]
    normalized = status_filter.strip().upper()
    out: list[ObservationOut] = []
    user_id = str(getattr(current_user, "id", "")) if current_user else ""
    for row in rows:
        if project_id and row.get("project_id") != project_id:
            continue
        if normalized == "OPEN" and row.get("status") != "OPEN":
            continue
        if normalized == "RESOLVED" and row.get("status") != "RESOLVED":
            continue
        assignee = row.get("assignee_user_id")
        if assignee and user_id and assignee != user_id:
            continue
        tags = []
        raw_tags = row.get("tags_json")
        if raw_tags:
            try:
                parsed = json.loads(raw_tags) if isinstance(raw_tags, str) else raw_tags
                if isinstance(parsed, list):
                    tags = [str(item) for item in parsed]
            except Exception:
                tags = []
        out.append(
            ObservationOut(
                id=UUID(str(row.get("id"))),
                project_id=str(row.get("project_id") or ""),
                activity_id=UUID(str(row.get("activity_id"))),
                assignee_user_id=UUID(str(assignee)) if assignee else None,
                tags=tags,
                message=str(row.get("message") or ""),
                severity=str(row.get("severity") or "MED"),
                due_date=row.get("due_date"),
                status=str(row.get("status") or "OPEN"),
                resolved_at=row.get("resolved_at"),
                created_at=row.get("created_at") or datetime.now(timezone.utc),
            )
        )
    out.sort(key=lambda x: x.created_at, reverse=True)
    return out[:200]


@router.post("/mobile/observations/{observation_id}/resolve", response_model=ObservationResolveOut)
def resolve_mobile_observation(
    observation_id: str,
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
):
    client = get_firestore_client()
    try:
        obs_uuid = UUID(observation_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid observation id")

    doc_ref = client.collection("observations").document(str(obs_uuid))
    snap = doc_ref.get()
    if not snap.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Observation not found")
    payload = snap.to_dict() or {}
    now = datetime.now(timezone.utc)
    doc_ref.set(
        {
            "status": "RESOLVED",
            "resolved_at": now,
            "sync_version": int(payload.get("sync_version") or 0) + 1,
        },
        merge=True,
    )
    client.collection("audit_logs").document(str(uuid4())).set(
        {
            "id": str(uuid4()),
            "created_at": now,
            "actor_id": str(getattr(current_user, "id", "")),
            "actor_email": getattr(current_user, "email", ""),
            "action": "OBSERVATION_RESOLVED",
            "entity": "observation",
            "entity_id": str(obs_uuid),
            "details_json": json.dumps({"status": "RESOLVED"}),
        }
    )
    return ObservationResolveOut(ok=True)

