"""Push notification helpers for catalog update events."""

from __future__ import annotations

import hashlib
import importlib
import json
import logging
from datetime import datetime, timezone
from pathlib import Path
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
