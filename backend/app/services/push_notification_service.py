"""Push notification helpers for catalog update events."""

from __future__ import annotations

import hashlib
import importlib
import json
import logging
from datetime import datetime, timezone
from pathlib import Path
try:
    from zoneinfo import ZoneInfo
except ImportError:  # Python < 3.9 fallback (shouldn't happen on 3.11)
    from backports.zoneinfo import ZoneInfo  # type: ignore[no-redef]

_TZ_MEXICO = ZoneInfo("America/Mexico_City")
from threading import Lock
from typing import Any

from app.core.config import settings
from app.core.firestore import get_firestore_client

logger = logging.getLogger(__name__)

_COLLECTION = "device_push_tokens"

_init_lock = Lock()


def _firebase_modules() -> tuple[Any, Any, Any] | None:
    try:
        firebase_admin = importlib.import_module("firebase_admin")
        credentials = importlib.import_module("firebase_admin.credentials")
        messaging = importlib.import_module("firebase_admin.messaging")
        return firebase_admin, credentials, messaging
    except Exception:
        return None


def _normalize_project_id(project_id: str | None) -> str:
    normalized = str(project_id or "").strip().upper()
    return normalized


def _token_doc_id(user_id: str, token: str) -> str:
    digest = hashlib.sha256(f"{user_id}:{token}".encode("utf-8")).hexdigest()
    return digest[:40]


def _is_fcm_enabled() -> bool:
    return bool(settings.FCM_ENABLED)


def _initialize_firebase_app() -> Any | None:
    if not _is_fcm_enabled():
        return None

    modules = _firebase_modules()
    if modules is None:
        logger.warning("FCM enabled but firebase_admin is not installed in runtime")
        return None
    firebase_admin, credentials, _ = modules

    try:
        return firebase_admin.get_app()
    except ValueError:
        pass

    with _init_lock:
        try:
            return firebase_admin.get_app()
        except ValueError:
            pass

        service_account_raw = (settings.FCM_SERVICE_ACCOUNT_JSON or "").strip()
        if not service_account_raw:
            # Uses ADC (Cloud Run service account) when no explicit credential is provided.
            return firebase_admin.initialize_app()

        if service_account_raw.startswith("{"):
            data = json.loads(service_account_raw)
            cred = credentials.Certificate(data)
            return firebase_admin.initialize_app(cred)

        # Allow absolute path to service account JSON.
        service_account_path = Path(service_account_raw)
        cred = credentials.Certificate(str(service_account_path))
        return firebase_admin.initialize_app(cred)


def register_device_push_token(
    *,
    user_id: str,
    token: str,
    project_id: str,
    platform: str,
    app_version: str | None,
) -> None:
    normalized_user = str(user_id or "").strip()
    normalized_token = str(token or "").strip()
    normalized_project = _normalize_project_id(project_id)
    normalized_platform = str(platform or "android").strip().lower() or "android"
    normalized_app_version = str(app_version or "").strip() or None

    if not normalized_user or not normalized_token or not normalized_project:
        raise ValueError("user_id, token, and project_id are required")

    now = datetime.now(timezone.utc)
    doc_id = _token_doc_id(normalized_user, normalized_token)

    payload: dict[str, Any] = {
        "user_id": normalized_user,
        "token": normalized_token,
        "project_id": normalized_project,
        "platform": normalized_platform,
        "app_version": normalized_app_version,
        "enabled": True,
        "updated_at": now,
        "last_seen_at": now,
    }

    get_firestore_client().collection(_COLLECTION).document(doc_id).set(payload, merge=True)


def disable_device_push_token(*, user_id: str, token: str) -> None:
    normalized_user = str(user_id or "").strip()
    normalized_token = str(token or "").strip()
    if not normalized_user or not normalized_token:
        return

    now = datetime.now(timezone.utc)
    doc_id = _token_doc_id(normalized_user, normalized_token)
    get_firestore_client().collection(_COLLECTION).document(doc_id).set(
        {
            "enabled": False,
            "updated_at": now,
            "disabled_reason": "client_unregister",
        },
        merge=True,
    )


def _is_invalid_token_error(error: Exception) -> bool:
    msg = str(error).lower()
    return (
        "registration-token-not-registered" in msg
        or "invalid-registration-token" in msg
        or "requested entity was not found" in msg
    )


def notify_catalog_update(*, project_id: str, version_id: str) -> dict[str, int]:
    normalized_project = _normalize_project_id(project_id)
    normalized_version = str(version_id or "").strip()
    if not normalized_project or not normalized_version:
        return {"sent": 0, "failed": 0, "invalidated": 0}

    if not _is_fcm_enabled():
        return {"sent": 0, "failed": 0, "invalidated": 0}

    app = _initialize_firebase_app()
    if app is None:
        return {"sent": 0, "failed": 0, "invalidated": 0}

    modules = _firebase_modules()
    if modules is None:
        return {"sent": 0, "failed": 0, "invalidated": 0}
    _, _, messaging = modules

    client = get_firestore_client()
    docs = (
        client.collection(_COLLECTION)
        .where("enabled", "==", True)
        .where("project_id", "==", normalized_project)
        .stream()
    )

    token_rows: list[tuple[str, str]] = []
    for doc in docs:
        payload = doc.to_dict() or {}
        token = str(payload.get("token") or "").strip()
        if token:
            token_rows.append((doc.id, token))

    if not token_rows:
        logger.warning(
            "CATALOG_PUSH_NO_TOKENS project_id=%s version_id=%s (no registered device tokens)",
            normalized_project,
            normalized_version,
        )
        return {"sent": 0, "failed": 0, "invalidated": 0}

    sent = 0
    failed = 0
    invalidated = 0

    for index in range(0, len(token_rows), 500):
        chunk = token_rows[index:index + 500]
        tokens = [token for _, token in chunk]

        message = messaging.MulticastMessage(
            tokens=tokens,
            notification=messaging.Notification(
                title=f"Catalogo actualizado {normalized_project}",
                body=f"Nueva version {normalized_version} disponible.",
            ),
            data={
                "type": "catalog_update",
                "project_id": normalized_project,
                "version_id": normalized_version,
            },
            android=messaging.AndroidConfig(priority="high"),
        )

        response = messaging.send_each_for_multicast(message, app=app)
        sent += response.success_count
        failed += response.failure_count

        now = datetime.now(timezone.utc)
        for i, item in enumerate(response.responses):
            if item.success:
                continue
            err = item.exception
            if err is None:
                continue
            if not _is_invalid_token_error(err):
                continue

            invalidated += 1
            doc_id = chunk[i][0]
            client.collection(_COLLECTION).document(doc_id).set(
                {
                    "enabled": False,
                    "updated_at": now,
                    "disabled_reason": "invalid_or_unregistered",
                },
                merge=True,
            )

    logger.info(
        "CATALOG_PUSH project_id=%s version_id=%s sent=%s failed=%s invalidated=%s",
        normalized_project,
        normalized_version,
        sent,
        failed,
        invalidated,
    )

    return {"sent": sent, "failed": failed, "invalidated": invalidated}


def notify_review_decision(
    *,
    project_id: str,
    activity_id: str,
    decision: str,
    assigned_user_id: str | None = None,
    comment: str | None = None,
) -> dict[str, int]:
    normalized_project = _normalize_project_id(project_id)
    normalized_activity = str(activity_id or "").strip()
    normalized_decision = str(decision or "").strip().upper()
    normalized_assignee = str(assigned_user_id or "").strip()
    normalized_comment = str(comment or "").strip()

    if not normalized_project or not normalized_activity or not normalized_decision:
        return {"sent": 0, "failed": 0, "invalidated": 0}

    if not _is_fcm_enabled():
        return {"sent": 0, "failed": 0, "invalidated": 0}

    app = _initialize_firebase_app()
    if app is None:
        return {"sent": 0, "failed": 0, "invalidated": 0}

    modules = _firebase_modules()
    if modules is None:
        return {"sent": 0, "failed": 0, "invalidated": 0}
    _, _, messaging = modules

    client = get_firestore_client()
    docs_query = (
        client.collection(_COLLECTION)
        .where("enabled", "==", True)
        .where("project_id", "==", normalized_project)
    )
    docs = docs_query.stream()

    token_rows: list[tuple[str, str]] = []
    for doc in docs:
        payload = doc.to_dict() or {}
        if normalized_assignee:
            user_id = str(payload.get("user_id") or "").strip()
            if user_id != normalized_assignee:
                continue
        token = str(payload.get("token") or "").strip()
        if token:
            token_rows.append((doc.id, token))

    if not token_rows:
        logger.warning(
            "REVIEW_PUSH_NO_TOKENS project_id=%s activity_id=%s assignee=%s decision=%s (no registered device tokens)",
            normalized_project,
            normalized_activity,
            normalized_assignee,
            normalized_decision,
        )
        return {"sent": 0, "failed": 0, "invalidated": 0}

    if normalized_decision in {"REJECT", "CHANGES_REQUIRED"}:
        title = "Actividad requiere correccion"
        body = "Tu actividad fue regresada para correccion."
        event_type = "review_changes_required"
    elif normalized_decision in {"APPROVE", "APPROVE_EXCEPTION"}:
        title = "Actividad aprobada"
        body = "Tu actividad fue aprobada por coordinacion."
        event_type = "review_approved"
    else:
        title = "Decision de revision"
        body = f"Decision registrada: {normalized_decision}."
        event_type = "review_decision"

    if normalized_comment:
        body = f"{body} {normalized_comment[:120]}"

    sent = 0
    failed = 0
    invalidated = 0

    for index in range(0, len(token_rows), 500):
        chunk = token_rows[index:index + 500]
        tokens = [token for _, token in chunk]

        message = messaging.MulticastMessage(
            tokens=tokens,
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={
                "type": event_type,
                "project_id": normalized_project,
                "activity_id": normalized_activity,
                "decision": normalized_decision,
            },
            android=messaging.AndroidConfig(priority="high"),
        )

        response = messaging.send_each_for_multicast(message, app=app)
        sent += response.success_count
        failed += response.failure_count

        now = datetime.now(timezone.utc)
        for i, item in enumerate(response.responses):
            if item.success:
                continue
            err = item.exception
            if err is None:
                continue
            if not _is_invalid_token_error(err):
                continue

            invalidated += 1
            doc_id = chunk[i][0]
            client.collection(_COLLECTION).document(doc_id).set(
                {
                    "enabled": False,
                    "updated_at": now,
                    "disabled_reason": "invalid_or_unregistered",
                },
                merge=True,
            )

    logger.info(
        "REVIEW_PUSH project_id=%s activity_id=%s decision=%s sent=%s failed=%s invalidated=%s",
        normalized_project,
        normalized_activity,
        normalized_decision,
        sent,
        failed,
        invalidated,
    )

    return {"sent": sent, "failed": failed, "invalidated": invalidated}


def _fmt_local_time(iso_str: str | None) -> str:
    """Return a human-readable time string in Mexico City timezone, e.g. '24/04 9:30 AM'."""
    if not iso_str:
        return ""
    try:
        dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        dt_mx = dt.astimezone(_TZ_MEXICO)
        return dt_mx.strftime("%d/%m %-I:%M %p")
    except Exception:
        return ""


def notify_new_assignment(
    *,
    project_id: str,
    activity_id: str,
    activity_title: str,
    assignee_user_id: str,
    assigned_by_name: str | None = None,
    is_transfer: bool = False,
    municipio: str | None = None,
    estado: str | None = None,
    frente: str | None = None,
    start_at: str | None = None,
) -> dict[str, int]:
    """Send an FCM push notification to the newly assigned operative/user.

    Filters device tokens by user_id so only the recipient is notified.
    Non-blocking: logs errors and returns counters. Safe to call without
    awaiting; callers should run it in a background thread if needed.
    """
    normalized_project = _normalize_project_id(project_id)
    normalized_activity = str(activity_id or "").strip()
    normalized_assignee = str(assignee_user_id or "").strip()
    normalized_title = str(activity_title or "").strip() or "Actividad"
    normalized_by = str(assigned_by_name or "").strip()

    if not normalized_project or not normalized_activity or not normalized_assignee:
        return {"sent": 0, "failed": 0, "invalidated": 0}

    if not _is_fcm_enabled():
        return {"sent": 0, "failed": 0, "invalidated": 0}

    app = _initialize_firebase_app()
    if app is None:
        return {"sent": 0, "failed": 0, "invalidated": 0}

    modules = _firebase_modules()
    if modules is None:
        return {"sent": 0, "failed": 0, "invalidated": 0}
    _, _, messaging = modules

    client = get_firestore_client()
    docs = (
        client.collection(_COLLECTION)
        .where("enabled", "==", True)
        .where("project_id", "==", normalized_project)
        .where("user_id", "==", normalized_assignee)
        .stream()
    )

    token_rows: list[tuple[str, str]] = []
    for doc in docs:
        payload = doc.to_dict() or {}
        token = str(payload.get("token") or "").strip()
        if token:
            token_rows.append((doc.id, token))

    if not token_rows:
        logger.warning(
            "ASSIGNMENT_PUSH_NO_TOKENS project_id=%s activity_id=%s assignee=%s is_transfer=%s (no registered device tokens)",
            normalized_project,
            normalized_activity,
            normalized_assignee,
            is_transfer,
        )
        return {"sent": 0, "failed": 0, "invalidated": 0}

    if is_transfer:
        title = "Actividad transferida a ti"
        body = f'"{normalized_title}" fue transferida a tu cargo.'
    else:
        title = "Nueva actividad asignada"
        body = f'Se te asignó "{normalized_title}".'

    time_str = _fmt_local_time(start_at)
    if time_str:
        body += f" {time_str}."

    location_parts = [p for p in [frente, municipio, estado] if p and str(p).strip()]
    if location_parts:
        body += " " + ", ".join(str(p).strip() for p in location_parts) + "."

    if normalized_by:
        body += f" Por: {normalized_by}."

    sent = 0
    failed = 0
    invalidated = 0

    for index in range(0, len(token_rows), 500):
        chunk = token_rows[index:index + 500]
        tokens = [token for _, token in chunk]

        message = messaging.MulticastMessage(
            tokens=tokens,
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={
                "type": "new_assignment" if not is_transfer else "assignment_transferred",
                "project_id": normalized_project,
                "activity_id": normalized_activity,
            },
            android=messaging.AndroidConfig(priority="high"),
        )

        response = messaging.send_each_for_multicast(message, app=app)
        sent += response.success_count
        failed += response.failure_count

        now = datetime.now(timezone.utc)
        for i, item in enumerate(response.responses):
            if item.success:
                continue
            err = item.exception
            if err is None:
                continue
            if not _is_invalid_token_error(err):
                continue

            invalidated += 1
            doc_id = chunk[i][0]
            client.collection(_COLLECTION).document(doc_id).set(
                {
                    "enabled": False,
                    "updated_at": now,
                    "disabled_reason": "invalid_or_unregistered",
                },
                merge=True,
            )

    logger.info(
        "ASSIGNMENT_PUSH project_id=%s activity_id=%s assignee=%s is_transfer=%s sent=%s failed=%s invalidated=%s",
        normalized_project,
        normalized_activity,
        normalized_assignee,
        is_transfer,
        sent,
        failed,
        invalidated,
    )

    return {"sent": sent, "failed": failed, "invalidated": invalidated}


def notify_daily_agenda(*, project_id: str | None = None) -> dict[str, int]:
    """Send a morning agenda push to every user who has activities scheduled for today.

    Designed to be triggered at 09:00 America/Mexico_City by Cloud Scheduler.
    Queries activities where assignment_start_at falls within today's local date,
    groups by assignee, and sends one summary message per user per project.
    """
    if not _is_fcm_enabled():
        return {"sent": 0, "failed": 0, "invalidated": 0, "users_notified": 0}

    app = _initialize_firebase_app()
    if app is None:
        return {"sent": 0, "failed": 0, "invalidated": 0, "users_notified": 0}

    modules = _firebase_modules()
    if modules is None:
        return {"sent": 0, "failed": 0, "invalidated": 0, "users_notified": 0}
    _, _, messaging = modules

    # Today's bounds in Mexico City time, converted to UTC for ISO comparison.
    now_mx = datetime.now(_TZ_MEXICO)
    today_start_utc = now_mx.replace(hour=0, minute=0, second=0, microsecond=0).astimezone(timezone.utc)
    today_end_utc = now_mx.replace(hour=23, minute=59, second=59, microsecond=999999).astimezone(timezone.utc)
    today_start_iso = today_start_utc.isoformat()
    today_end_iso = today_end_utc.isoformat()

    client = get_firestore_client()

    # --- Collect all active device tokens ---
    filter_project = _normalize_project_id(project_id) if project_id else None
    token_query = client.collection(_COLLECTION).where("enabled", "==", True)
    token_docs = list(token_query.stream())

    # user_id → project_id → [token, ...]
    user_project_tokens: dict[str, dict[str, list[str]]] = {}
    for doc in token_docs:
        payload = doc.to_dict() or {}
        uid = str(payload.get("user_id") or "").strip()
        pid = str(payload.get("project_id") or "").strip()
        token = str(payload.get("token") or "").strip()
        if not uid or not pid or not token:
            continue
        if filter_project and pid != filter_project:
            continue
        user_project_tokens.setdefault(uid, {}).setdefault(pid, []).append(token)

    if not user_project_tokens:
        logger.info("DAILY_AGENDA_PUSH no active device tokens found")
        return {"sent": 0, "failed": 0, "invalidated": 0, "users_notified": 0}

    unique_pids = {pid for pids in user_project_tokens.values() for pid in pids}

    # --- Load today's pending activities per project (filter in Python) ---
    _active_states = {"PENDIENTE", "EN_PROCESO", "EN_REVISION"}
    # project_id → list of activity dicts
    project_activities: dict[str, list[dict]] = {pid: [] for pid in unique_pids}

    for pid in unique_pids:
        for doc in client.collection("activities").where("project_id", "==", pid).stream():
            d = doc.to_dict() or {}
            if d.get("deleted_at") is not None:
                continue
            state = str(d.get("execution_state") or "").strip()
            if state not in _active_states:
                continue
            start_raw = str(d.get("assignment_start_at") or d.get("start_at") or "").strip()
            if not start_raw:
                continue
            try:
                dt = datetime.fromisoformat(start_raw.replace("Z", "+00:00"))
                if not (today_start_utc <= dt <= today_end_utc):
                    continue
            except Exception:
                continue
            project_activities[pid].append(d)

    # --- Send one summary notification per user per project ---
    sent = failed = invalidated = users_notified = 0

    for uid, pids in user_project_tokens.items():
        for pid, tokens in pids.items():
            user_acts = sorted(
                [
                    a for a in project_activities.get(pid, [])
                    if str(a.get("assigned_to_user_id") or "").strip() == uid
                ],
                key=lambda a: a.get("assignment_start_at", ""),
            )
            if not user_acts:
                continue

            count = len(user_acts)
            title = f"Tienes {count} actividad{'es' if count > 1 else ''} hoy"

            snippets: list[str] = []
            for act in user_acts[:3]:
                act_title = str(act.get("title") or act.get("activity_type_code") or "Actividad")[:35]
                time_str = _fmt_local_time(str(act.get("assignment_start_at") or ""))
                location_parts = [
                    str(act.get("frente") or "").strip(),
                    str(act.get("municipio") or "").strip(),
                ]
                loc = next((p for p in location_parts if p), "")
                snippet = act_title
                if time_str:
                    snippet += f" {time_str}"
                if loc:
                    snippet += f" ({loc})"
                snippets.append(snippet)

            body = " · ".join(snippets)
            if count > 3:
                body += f" · +{count - 3} más"

            for index in range(0, len(tokens), 500):
                chunk_tokens = tokens[index : index + 500]
                message = messaging.MulticastMessage(
                    tokens=chunk_tokens,
                    notification=messaging.Notification(title=title, body=body),
                    data={
                        "type": "daily_agenda",
                        "project_id": pid,
                        "count": str(count),
                    },
                    android=messaging.AndroidConfig(priority="normal"),
                )
                response = messaging.send_each_for_multicast(message, app=app)
                sent += response.success_count
                failed += response.failure_count

                now = datetime.now(timezone.utc)
                for i, item in enumerate(response.responses):
                    if item.success:
                        continue
                    err = item.exception
                    if err is None or not _is_invalid_token_error(err):
                        continue
                    invalidated += 1
                    # Mark token as invalid — need the doc_id for this chunk
                    # Since we only have raw tokens here (not doc IDs), disable via a fresh query
                    bad_token = chunk_tokens[i]
                    _disable_token_by_value(client, bad_token, now)

            users_notified += 1

    logger.info(
        "DAILY_AGENDA_PUSH date=%s sent=%s failed=%s invalidated=%s users_notified=%s",
        now_mx.strftime("%Y-%m-%d"),
        sent,
        failed,
        invalidated,
        users_notified,
    )
    return {"sent": sent, "failed": failed, "invalidated": invalidated, "users_notified": users_notified}


def _disable_token_by_value(client: Any, token: str, now: datetime) -> None:
    """Mark a specific FCM token as disabled when we only know its value (not doc ID)."""
    docs = (
        client.collection(_COLLECTION)
        .where("token", "==", token)
        .limit(5)
        .stream()
    )
    for doc in docs:
        doc.reference.set(
            {"enabled": False, "updated_at": now, "disabled_reason": "invalid_or_unregistered"},
            merge=True,
        )


def notify_user(
    *,
    user_id: str,
    title: str,
    body: str,
    data: dict[str, str] | None = None,
    project_id: str | None = None,
) -> dict[str, int]:
    """Send a custom push notification to all registered devices of a specific user.

    Optionally scoped to a project (only tokens registered for that project are used).
    Safe to call even when FCM is disabled — returns zeroes without raising.
    """
    normalized_user = str(user_id or "").strip()
    normalized_project = _normalize_project_id(project_id) if project_id else None

    if not normalized_user:
        return {"sent": 0, "failed": 0, "invalidated": 0}

    if not _is_fcm_enabled():
        return {"sent": 0, "failed": 0, "invalidated": 0}

    app = _initialize_firebase_app()
    if app is None:
        return {"sent": 0, "failed": 0, "invalidated": 0}

    modules = _firebase_modules()
    if modules is None:
        return {"sent": 0, "failed": 0, "invalidated": 0}
    _, _, messaging = modules

    client = get_firestore_client()
    query = (
        client.collection(_COLLECTION)
        .where("enabled", "==", True)
        .where("user_id", "==", normalized_user)
    )
    if normalized_project:
        query = query.where("project_id", "==", normalized_project)

    token_rows: list[tuple[str, str]] = []
    for doc in query.stream():
        payload = doc.to_dict() or {}
        token = str(payload.get("token") or "").strip()
        if token:
            token_rows.append((doc.id, token))

    if not token_rows:
        logger.warning(
            "NOTIFY_USER_NO_TOKENS user_id=%s project_id=%s (no registered device tokens)",
            normalized_user,
            normalized_project or "*",
        )
        return {"sent": 0, "failed": 0, "invalidated": 0}

    normalized_data: dict[str, str] = {k: str(v) for k, v in (data or {}).items()}

    sent = 0
    failed = 0
    invalidated = 0
    now = datetime.now(timezone.utc)

    for index in range(0, len(token_rows), 500):
        chunk = token_rows[index : index + 500]
        tokens = [t for _, t in chunk]

        message = messaging.MulticastMessage(
            tokens=tokens,
            notification=messaging.Notification(title=title, body=body),
            data=normalized_data,
            android=messaging.AndroidConfig(priority="high"),
        )

        response = messaging.send_each_for_multicast(message, app=app)
        sent += response.success_count
        failed += response.failure_count

        for i, item in enumerate(response.responses):
            if item.success:
                continue
            err = item.exception
            if err is None or not _is_invalid_token_error(err):
                continue
            invalidated += 1
            doc_id = chunk[i][0]
            client.collection(_COLLECTION).document(doc_id).set(
                {"enabled": False, "updated_at": now, "disabled_reason": "invalid_or_unregistered"},
                merge=True,
            )

    logger.info(
        "NOTIFY_USER user_id=%s project_id=%s sent=%s failed=%s invalidated=%s",
        normalized_user,
        normalized_project or "*",
        sent,
        failed,
        invalidated,
    )
    return {"sent": sent, "failed": failed, "invalidated": invalidated}
