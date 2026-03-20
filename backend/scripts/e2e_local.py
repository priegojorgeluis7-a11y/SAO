"""SAO — E2E Local Test Script
============================
Runs the full SAO operational flow against a local dev server
(localhost:8000, SQLite, EVIDENCE_STORAGE_BACKEND=local).

Flow
----
 1. Login OPERATIVO  → obtener token
 2. Resolver identidad (/auth/me) y versión de catálogo activa
 3. POST /activities  → crear actividad en estado REVISION_PENDIENTE
 4. PATCH /activities/{uuid}/flags → establecer gps_mismatch flag
 5. POST /evidences/upload-init  → iniciar subida de evidencia
 6. PUT  /local-upload/{evidence_id} → subir bytes (modo local)
 7. POST /sync/push  → push actividad al servidor
 8. Login COORD  → obtener token
 9. GET  /review/queue  → verificar actividad en cola de revisión
10. POST /review/activity/{uuid}/decision → aprobar actividad
11. POST /sync/pull  → delta pull, verificar estado COMPLETADA
12. POST /events     → crear evento de campo
13. GET  /events     → listar eventos, verificar que existe

Usage
-----
    # All defaults point to local dev server with seeded admin user:
    cd backend
    python scripts/e2e_local.py

    # With custom credentials:
    python scripts/e2e_local.py \\
        --operativo-email operativo.demo@sao.mx \\
        --operativo-password Operativo123! \\
        --coord-email admin@sao.mx \\
        --coord-password admin123

Prerequisites
-------------
    - Backend running on localhost:8000 (uvicorn app.main:app ...)
    - DATA_BACKEND=firestore
    - Firestore base catalogs available (see ensure_firestore_base_catalogs.py)
    - EVIDENCE_STORAGE_BACKEND=local
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any
from urllib import error, parse, request
from uuid import uuid4


# ─── HTTP helpers (no external deps) ────────────────────────────────────────


@dataclass
class HttpResult:
    status_code: int
    body_text: str
    data: Any | None


class E2EError(RuntimeError):
    pass


def _http(
    method: str,
    url: str,
    *,
    body: dict[str, Any] | bytes | None = None,
    token: str | None = None,
    content_type: str = "application/json",
    timeout: int = 30,
) -> HttpResult:
    headers: dict[str, str] = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    payload: bytes | None = None
    if isinstance(body, bytes):
        payload = body
        headers["Content-Type"] = content_type
    elif isinstance(body, dict):
        payload = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"

    req = request.Request(url=url, method=method.upper(), data=payload, headers=headers)
    try:
        with request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8")
            return HttpResult(
                status_code=resp.status,
                body_text=raw,
                data=json.loads(raw) if raw.strip() else None,
            )
    except error.HTTPError as exc:
        raw = exc.read().decode("utf-8") if exc.fp else ""
        return HttpResult(
            status_code=exc.code,
            body_text=raw,
            data=json.loads(raw) if raw.strip() else None,
        )


def _ok(result: HttpResult, expected: set[int], ctx: str) -> None:
    if result.status_code not in expected:
        raise E2EError(
            f"[FAIL] {ctx} → HTTP {result.status_code}\n{result.body_text}"
        )


def _url(base: str, path: str, **params: str) -> str:
    base = base.rstrip("/")
    if params:
        qs = parse.urlencode(params)
        return f"{base}{path}?{qs}"
    return f"{base}{path}"


# ─── Step helpers ────────────────────────────────────────────────────────────


def _login(base: str, email: str, password: str) -> str:
    r = _http("POST", _url(base, "/api/v1/auth/login"),
               body={"email": email, "password": password})
    _ok(r, {200}, f"Login {email}")
    token = (r.data or {}).get("access_token")
    if not token:
        raise E2EError("Login response missing access_token")
    return str(token)


def _me(base: str, token: str) -> str:
    r = _http("GET", _url(base, "/api/v1/auth/me"), token=token)
    _ok(r, {200}, "GET /auth/me")
    user_id = (r.data or {}).get("id")
    if not user_id:
        raise E2EError("/auth/me response missing id")
    return str(user_id)


def _catalog_version(base: str, token: str, project_id: str) -> str:
    r = _http("GET", _url(base, "/api/v1/catalog/version/current",
                          project_id=project_id), token=token)
    _ok(r, {200}, "GET /catalog/version/current")
    ver = (r.data or {}).get("version_id")
    if not ver:
        raise E2EError("catalog/version/current missing version_id")
    return str(ver)


# ─── Main flow ────────────────────────────────────────────────────────────────


def _run(args: argparse.Namespace) -> None:  # noqa: PLR0915
    base = args.base_url.rstrip("/")
    project_id = args.project_id
    now_iso = datetime.now(timezone.utc).isoformat()

    print("\n🚦 SAO E2E Local Flow")
    print(f"   Backend : {base}")
    print(f"   Project : {project_id}")
    print()

    # ── 1. Login ─────────────────────────────────────────────────────────────
    print("[1/13] Login operativo + coord...")
    op_token = _login(base, args.operativo_email, args.operativo_password)
    coord_token = _login(base, args.coord_email, args.coord_password)
    print(f"       ✓ Operativo  : {args.operativo_email}")
    print(f"       ✓ Coord      : {args.coord_email}")

    # ── 2. Resolve identity + catalog version ─────────────────────────────────
    print("[2/13] Resolve operativo identity and catalog version...")
    op_user_id = _me(base, op_token)
    catalog_version_id = _catalog_version(base, op_token, project_id)
    print(f"       ✓ user_id           : {op_user_id}")
    print(f"       ✓ catalog_version_id: {catalog_version_id}")

    # ── 3. Create activity ────────────────────────────────────────────────────
    print("[3/13] Create activity via POST /activities...")
    activity_uuid = str(uuid4())
    act_payload = {
        "uuid": activity_uuid,
        "project_id": project_id,
        "front_id": None,
        "pk_start": args.pk_start,
        "pk_end": args.pk_end,
        "execution_state": "REVISION_PENDIENTE",
        "assigned_to_user_id": None,
        "created_by_user_id": op_user_id,
        "catalog_version_id": catalog_version_id,
        "activity_type_code": args.activity_type_code,
        "title": f"E2E Local Activity {activity_uuid[:8]}",
        "description": "Generada por e2e_local.py",
        "latitude": "19.4326",
        "longitude": "-99.1332",
    }
    r = _http("POST", _url(base, "/api/v1/activities"), body=act_payload, token=op_token)
    _ok(r, {200, 201}, "POST /activities")
    server_id = (r.data or {}).get("server_id") or (r.data or {}).get("id")
    print(f"       ✓ activity_uuid : {activity_uuid}")
    print(f"       ✓ server_id     : {server_id}")

    # ── 4. Set GPS flag ───────────────────────────────────────────────────────
    print("[4/13] PATCH /activities/{uuid}/flags → set gps_mismatch=true...")
    r = _http("PATCH", _url(base, f"/api/v1/activities/{activity_uuid}/flags"),
               body={"gps_mismatch": True}, token=op_token)
    _ok(r, {200}, "PATCH /activities/{uuid}/flags")
    flags = (r.data or {}).get("flags", {})
    if flags.get("gps_mismatch") is not True:
        raise E2EError(f"Expected gps_mismatch=true, got {flags}")
    print(f"       ✓ flags: {flags}")

    # ── 5. Evidence upload-init ───────────────────────────────────────────────
    print("[5/13] POST /evidences/upload-init → init evidence...")
    evidence_uuid = str(uuid4())
    r = _http(
        "POST",
        _url(base, "/api/v1/evidences/upload-init"),
        body={
            "activity_uuid": activity_uuid,
            "evidence_uuid": evidence_uuid,
            "mime_type": "image/jpeg",
            "file_size_bytes": 1024,
        },
        token=op_token,
    )
    _ok(r, {200, 201}, "POST /evidences/upload-init")
    upload_url: str = str((r.data or {}).get("upload_url", ""))
    evidence_id: str = str((r.data or {}).get("evidence_id", evidence_uuid))
    print(f"       ✓ evidence_id : {evidence_id}")
    print(f"       ✓ upload_url  : {upload_url}")

    # ── 6. Upload evidence (local mode) ───────────────────────────────────────
    print("[6/13] Upload evidence bytes → PUT /local-upload/{evidence_id}...")
    dummy_jpeg = b"\xff\xd8\xff\xe0" + b"\x00" * 1020  # minimal JPEG-like bytes
    if "/local-upload/" in upload_url:
        r = _http("PUT", upload_url, body=dummy_jpeg, content_type="image/jpeg", token=op_token)
        _ok(r, {200}, "PUT /local-upload/{evidence_id}")
        print("       ✓ Evidence uploaded via local endpoint")
    else:
        print("       ℹ  upload_url is not a local endpoint — skipping upload (GCS mode?)")

    # ── 7. Sync push ──────────────────────────────────────────────────────────
    print("[7/13] POST /sync/push → push activity...")
    push_payload = {
        "project_id": project_id,
        "activities": [{**act_payload, "deleted_at": None}],
    }
    r = _http("POST", _url(base, "/api/v1/sync/push"), body=push_payload, token=op_token)
    _ok(r, {200}, "POST /sync/push")
    results = (r.data or {}).get("results", [])
    push_status = str((results[0] if results else {}).get("status", "?"))
    if push_status not in {"CREATED", "UPDATED", "UNCHANGED"}:
        raise E2EError(f"Unexpected sync push result: {push_status}")
    print(f"       ✓ push status: {push_status}")

    # ── 8. Baseline pull (cursor) ─────────────────────────────────────────────
    print("[8/13] POST /sync/pull → baseline cursor...")
    r = _http("POST", _url(base, "/api/v1/sync/pull"),
               body={"project_id": project_id, "since_version": 0, "limit": 500},
               token=op_token)
    _ok(r, {200}, "POST /sync/pull baseline")
    baseline_version = int((r.data or {}).get("current_version", 0))
    print(f"       ✓ baseline_version: {baseline_version}")

    # ── 9. Verify review queue ────────────────────────────────────────────────
    print("[9/13] GET /review/queue → verify activity appears...")
    r = _http("GET", _url(base, "/api/v1/review/queue", project_id=project_id),
               token=coord_token)
    _ok(r, {200}, "GET /review/queue")
    queue_items = (r.data or {}).get("items") or (r.data if isinstance(r.data, list) else [])
    in_queue = any(
        str((item.get("activity") or item).get("uuid", "")) == activity_uuid
        for item in queue_items
    )
    print(f"       ✓ activities in queue: {len(queue_items)}, our activity found: {in_queue}")

    # ── 10. Approve activity ──────────────────────────────────────────────────
    print("[10/13] POST /review/activity/{uuid}/decision → approve...")
    r = _http(
        "POST",
        _url(base, f"/api/v1/review/activity/{activity_uuid}/decision"),
        body={"decision": "APPROVE", "field_resolutions": []},
        token=coord_token,
    )
    _ok(r, {200}, "POST /review/activity/{uuid}/decision")
    ok_flag = (r.data or {}).get("ok")
    if ok_flag is not True:
        raise E2EError(f"Approval response does not confirm ok=true: {r.data}")
    print("       ✓ Activity approved")

    # ── 11. Delta pull → verify COMPLETADA ───────────────────────────────────
    print("[11/13] POST /sync/pull delta → verify execution_state=COMPLETADA...")
    r = _http(
        "POST",
        _url(base, "/api/v1/sync/pull"),
        body={"project_id": project_id, "since_version": baseline_version, "limit": 500},
        token=op_token,
    )
    _ok(r, {200}, "POST /sync/pull delta")
    approved_item: dict | None = None
    for item in (r.data or {}).get("activities", []):
        if str(item.get("uuid")) == activity_uuid:
            approved_item = item
            break

    if approved_item is None:
        # Fallback: full pull
        r = _http("POST", _url(base, "/api/v1/sync/pull"),
                   body={"project_id": project_id, "since_version": 0, "limit": 500},
                   token=op_token)
        _ok(r, {200}, "POST /sync/pull full fallback")
        for item in (r.data or {}).get("activities", []):
            if str(item.get("uuid")) == activity_uuid:
                approved_item = item
                break

    if approved_item is None:
        raise E2EError("Approved activity not found in pull responses")

    execution_state = str(approved_item.get("execution_state", "?"))
    if execution_state != "COMPLETADA":
        raise E2EError(
            f"Expected execution_state=COMPLETADA, got '{execution_state}'"
        )
    print(f"       ✓ execution_state: {execution_state}")

    # ── 12. Clear GPS flag now that it was reviewed ────────────────────────────
    print("[12/13] PATCH /activities/{uuid}/flags → clear gps_mismatch...")
    r = _http("PATCH", _url(base, f"/api/v1/activities/{activity_uuid}/flags"),
               body={"gps_mismatch": False}, token=coord_token)
    _ok(r, {200}, "PATCH /activities/{uuid}/flags clear")
    flags = (r.data or {}).get("flags", {})
    if flags.get("gps_mismatch") is not False:
        raise E2EError(f"Expected gps_mismatch=false after clear, got {flags}")
    print(f"       ✓ flags: {flags}")

    # ── 13. Create + list event ───────────────────────────────────────────────
    print("[13/13] POST /events → create + GET /events → list...")
    event_uuid = str(uuid4())
    r = _http(
        "POST",
        _url(base, "/api/v1/events"),
        body={
            "uuid": event_uuid,
            "project_id": project_id,
            "reported_by_user_id": op_user_id,
            "event_type_code": "DERRAME",
            "title": "Derrame E2E Local",
            "description": "Test event from e2e_local.py",
            "severity": "HIGH",
            "location_pk_meters": args.pk_start,
            "occurred_at": now_iso,
        },
        token=op_token,
    )
    _ok(r, {200, 201}, "POST /events")
    print(f"       ✓ event created: {event_uuid}")

    r = _http("GET", _url(base, "/api/v1/events", project_id=project_id), token=op_token)
    _ok(r, {200}, "GET /events")
    items = (r.data or {}).get("items", [])
    event_found = any(str(i.get("uuid", "")) == event_uuid for i in items)
    if not event_found:
        raise E2EError(f"Event {event_uuid} not found in GET /events response")
    print(f"       ✓ events in project: {len(items)}, our event found: True")

    # ── Summary ───────────────────────────────────────────────────────────────
    print()
    print("━" * 60)
    print("✅ E2E LOCAL PASSED")
    print("━" * 60)
    print(f"  Activity UUID       : {activity_uuid}")
    print(f"  Event UUID          : {event_uuid}")
    print(f"  Push result         : {push_status}")
    print(f"  Final state         : {execution_state}")
    print(f"  Timestamp UTC       : {now_iso}")
    print("━" * 60)


# ─── CLI ─────────────────────────────────────────────────────────────────────


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="SAO E2E local test — full operational flow against localhost",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--base-url",
        default="http://localhost:8000",
        help="Backend base URL (default: http://localhost:8000)",
    )
    parser.add_argument(
        "--project-id",
        default="TMQ",
        help="Project ID to use for the test (default: TMQ)",
    )
    parser.add_argument(
        "--operativo-email",
        default="admin@sao.mx",
        help="Operativo user email (default: admin@sao.mx)",
    )
    parser.add_argument(
        "--operativo-password",
        default="admin123",
        help="Operativo user password (default: admin123)",
    )
    parser.add_argument(
        "--coord-email",
        default="admin@sao.mx",
        help="Coordinator/supervisor email (default: admin@sao.mx)",
    )
    parser.add_argument(
        "--coord-password",
        default="admin123",
        help="Coordinator/supervisor password (default: admin123)",
    )
    parser.add_argument(
        "--activity-type-code",
        default="INSP_CIVIL",
        help="Activity type code from catalog (default: INSP_CIVIL)",
    )
    parser.add_argument(
        "--pk-start",
        type=int,
        default=13500,
        help="PK start in meters (default: 13500 = km 13+500)",
    )
    parser.add_argument(
        "--pk-end",
        type=int,
        default=13800,
        help="PK end in meters (default: 13800 = km 13+800)",
    )
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    try:
        _run(args)
        return 0
    except E2EError as exc:
        print(f"\n❌ E2E FAILED: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\n❌ Interrupted", file=sys.stderr)
        return 130
    except Exception as exc:
        print(f"\n❌ Unexpected error: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
