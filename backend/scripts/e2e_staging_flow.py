from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any
from urllib import error, parse, request
from uuid import uuid4
from uuid import UUID


@dataclass
class HttpResult:
    status_code: int
    body_text: str
    data: Any | None


class E2EError(RuntimeError):
    pass


def _json_request(
    method: str,
    url: str,
    *,
    body: dict[str, Any] | None = None,
    auth_header: str | None = None,
    serverless_token: str | None = None,
    timeout_seconds: int = 30,
) -> HttpResult:
    headers = {
        "Content-Type": "application/json",
    }
    if auth_header:
        headers["Authorization"] = f"Bearer {auth_header}"
    if serverless_token:
        headers["X-Serverless-Authorization"] = f"Bearer {serverless_token}"

    payload = None
    if body is not None:
        payload = json.dumps(body).encode("utf-8")

    req = request.Request(url=url, method=method.upper(), data=payload, headers=headers)

    try:
        with request.urlopen(req, timeout=timeout_seconds) as response:
            raw = response.read().decode("utf-8")
            parsed = None
            if raw.strip():
                try:
                    parsed = json.loads(raw)
                except json.JSONDecodeError:
                    parsed = None
            return HttpResult(status_code=response.status, body_text=raw, data=parsed)
    except error.HTTPError as exc:
        raw = exc.read().decode("utf-8") if exc.fp is not None else ""
        parsed = None
        if raw.strip():
            try:
                parsed = json.loads(raw)
            except json.JSONDecodeError:
                parsed = None
        return HttpResult(status_code=exc.code, body_text=raw, data=parsed)


def _ensure_ok(result: HttpResult, expected: set[int], context: str) -> None:
    if result.status_code not in expected:
        raise E2EError(
            f"{context} failed with HTTP {result.status_code}. Body: {result.body_text}"
        )


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run SAO staging E2E flow: operativo push -> supervisor approve -> operativo pull"
    )
    parser.add_argument("--base-url", required=True, help="Backend base URL, e.g. https://...run.app")
    parser.add_argument("--project-id", default="TMQ", help="Project ID for the test flow")

    parser.add_argument("--operativo-email", required=True)
    parser.add_argument("--operativo-password", required=True)

    parser.add_argument("--supervisor-email", required=True)
    parser.add_argument("--supervisor-password", required=True)

    parser.add_argument("--activity-type-code", default="INSP_CIVIL")
    parser.add_argument("--pk-start", type=int, default=13500)
    parser.add_argument("--pk-end", type=int, default=13800)

    parser.add_argument(
        "--cloud-run-private",
        action="store_true",
        help="Use gcloud identity token for Cloud Run private ingress",
    )
    parser.add_argument(
        "--identity-token",
        default="",
        help="Optional pre-generated identity token (overrides gcloud fetch)",
    )
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--verbose", action="store_true")
    return parser.parse_args()


def _normalize_base_url(base_url: str) -> str:
    value = base_url.strip().rstrip("/")
    if not value:
        raise E2EError("base-url is empty")
    return value


def _build_url(base_url: str, path: str, query: dict[str, str] | None = None) -> str:
    normalized_path = path if path.startswith("/") else f"/{path}"
    url = f"{base_url}{normalized_path}"
    if query:
        url = f"{url}?{parse.urlencode(query)}"
    return url


def _resolve_identity_token(args: argparse.Namespace) -> str | None:
    if not args.cloud_run_private:
        return None
    if args.identity_token.strip():
        return args.identity_token.strip()

    process = subprocess.run(
        ["gcloud", "auth", "print-identity-token"],
        capture_output=True,
        text=True,
        check=False,
    )
    token = process.stdout.strip()
    if process.returncode != 0 or not token:
        raise E2EError(
            "Unable to get identity token from gcloud. "
            "Run 'gcloud auth login' or pass --identity-token explicitly."
        )
    return token


def _login(
    *,
    base_url: str,
    email: str,
    password: str,
    identity_token: str | None,
    timeout: int,
) -> str:
    login_url = _build_url(base_url, "/api/v1/auth/login")
    login_result = _json_request(
        "POST",
        login_url,
        body={"email": email, "password": password},
        auth_header=identity_token,
        timeout_seconds=timeout,
    )
    _ensure_ok(login_result, {200}, f"Login for {email}")

    if not isinstance(login_result.data, dict) or not login_result.data.get("access_token"):
        raise E2EError(f"Login for {email} did not return access_token")

    return str(login_result.data["access_token"])


def _is_uuid(value: str | None) -> bool:
    if not value:
        return False
    try:
        UUID(value)
        return True
    except (ValueError, TypeError):
        return False


def _resolve_catalog_version_uuid(
    *,
    base_url: str,
    project_id: str,
    operativo_token: str,
    identity_token: str | None,
    timeout: int,
) -> str:
    version_result = _json_request(
        "GET",
        _build_url(base_url, "/api/v1/catalog/version/current", {"project_id": project_id}),
        auth_header=operativo_token,
        serverless_token=identity_token,
        timeout_seconds=timeout,
    )
    _ensure_ok(version_result, {200}, "GET /api/v1/catalog/version/current")
    if not isinstance(version_result.data, dict):
        raise E2EError("catalog/version/current returned invalid JSON")

    current_value = str(version_result.data.get("version_id", "")).strip()
    if _is_uuid(current_value):
        return current_value

    # Some environments expose semantic bundle IDs here (e.g., tmq-v2.0.0).
    # sync/push requires the canonical UUID from CatalogVersion.
    versions_result = _json_request(
        "GET",
        _build_url(base_url, "/api/v1/catalog/versions", {"project_id": project_id}),
        auth_header=operativo_token,
        serverless_token=identity_token,
        timeout_seconds=timeout,
    )
    _ensure_ok(versions_result, {200}, "GET /api/v1/catalog/versions")
    payload = versions_result.data
    if isinstance(payload, dict):
        candidate_rows: list[dict[str, Any]] = [payload]
    elif isinstance(payload, list):
        candidate_rows = [row for row in payload if isinstance(row, dict)]
    else:
        raise E2EError("catalog/versions returned invalid JSON")

    catalog_uuid = ""
    for row in candidate_rows:
        candidate = str(row.get("id", "")).strip()
        if _is_uuid(candidate):
            catalog_uuid = candidate
            break

    if not _is_uuid(catalog_uuid):
        raise E2EError(
            "Could not resolve UUID catalog_version_id. "
            f"version/current={current_value!r}, versions.id={catalog_uuid!r}"
        )
    return catalog_uuid


def _run_flow(args: argparse.Namespace) -> None:
    base_url = _normalize_base_url(args.base_url)
    identity_token = _resolve_identity_token(args)

    print("\n🚦 SAO Staging E2E Flow")
    print(f"Base URL: {base_url}")
    print(f"Project: {args.project_id}")

    if args.cloud_run_private:
        print("Cloud Run private mode: ON")

    print("\n[1/7] Login operativo and supervisor...")
    operativo_token = _login(
        base_url=base_url,
        email=args.operativo_email,
        password=args.operativo_password,
        identity_token=identity_token,
        timeout=args.timeout,
    )
    supervisor_token = _login(
        base_url=base_url,
        email=args.supervisor_email,
        password=args.supervisor_password,
        identity_token=identity_token,
        timeout=args.timeout,
    )

    print("[2/7] Resolve operativo identity and current catalog version...")
    me_result = _json_request(
        "GET",
        _build_url(base_url, "/api/v1/auth/me"),
        auth_header=operativo_token,
        serverless_token=identity_token,
        timeout_seconds=args.timeout,
    )
    _ensure_ok(me_result, {200}, "GET /api/v1/auth/me (operativo)")
    if not isinstance(me_result.data, dict) or not me_result.data.get("id"):
        raise E2EError("Operativo /auth/me response missing id")
    operativo_user_id = str(me_result.data["id"])

    catalog_version_id = _resolve_catalog_version_uuid(
        base_url=base_url,
        project_id=args.project_id,
        operativo_token=operativo_token,
        identity_token=identity_token,
        timeout=args.timeout,
    )

    print("[3/7] Operativo push activity to sync endpoint...")
    activity_uuid = str(uuid4())
    activity_payload = {
        "uuid": activity_uuid,
        "project_id": args.project_id,
        "front_id": None,
        "pk_start": args.pk_start,
        "pk_end": args.pk_end,
        "execution_state": "REVISION_PENDIENTE",
        "assigned_to_user_id": None,
        "created_by_user_id": operativo_user_id,
        "catalog_version_id": catalog_version_id,
        "activity_type_code": args.activity_type_code,
        "title": f"E2E Staging Activity {activity_uuid[:8]}",
        "description": "Auto-generated by e2e_staging_flow.py",
        "latitude": None,
        "longitude": None,
        "deleted_at": None,
    }
    push_result = _json_request(
        "POST",
        _build_url(base_url, "/api/v1/sync/push"),
        body={"project_id": args.project_id, "activities": [activity_payload]},
        auth_header=operativo_token,
        serverless_token=identity_token,
        timeout_seconds=args.timeout,
    )
    _ensure_ok(push_result, {200}, "POST /api/v1/sync/push")
    if not isinstance(push_result.data, dict) or not isinstance(push_result.data.get("results"), list):
        raise E2EError("sync/push response missing results")
    push_item = push_result.data["results"][0]
    push_status = str(push_item.get("status", ""))
    if push_status not in {"CREATED", "UPDATED", "UNCHANGED"}:
        raise E2EError(f"Unexpected push result status: {push_status}")

    print("[4/7] Baseline operativo pull to capture current_version...")
    baseline_pull_result = _json_request(
        "POST",
        _build_url(base_url, "/api/v1/sync/pull"),
        body={"project_id": args.project_id, "since_version": 0, "limit": 500},
        auth_header=operativo_token,
        serverless_token=identity_token,
        timeout_seconds=args.timeout,
    )
    _ensure_ok(baseline_pull_result, {200}, "POST /api/v1/sync/pull baseline")
    if not isinstance(baseline_pull_result.data, dict):
        raise E2EError("Baseline pull returned invalid JSON")
    baseline_version = int(baseline_pull_result.data.get("current_version", 0))

    print("[5/7] Supervisor approves activity in review endpoint...")
    approve_result = _json_request(
        "POST",
        _build_url(base_url, f"/api/v1/review/activity/{activity_uuid}/decision"),
        body={"decision": "APPROVE", "field_resolutions": []},
        auth_header=supervisor_token,
        serverless_token=identity_token,
        timeout_seconds=args.timeout,
    )
    if approve_result.status_code == 422 and isinstance(approve_result.data, dict):
        detail = approve_result.data.get("detail")
        if isinstance(detail, dict) and detail.get("error") == "CHECKLIST_INCOMPLETE":
            # In real staging/prod data, strict checklist rules may block a plain APPROVE.
            # Use APPROVE_EXCEPTION to keep the E2E flow validating push→review→pull end-to-end.
            approve_result = _json_request(
                "POST",
                _build_url(base_url, f"/api/v1/review/activity/{activity_uuid}/decision"),
                body={
                    "decision": "APPROVE_EXCEPTION",
                    "comment": "E2E staging bypass due to checklist constraints",
                    "field_resolutions": [],
                },
                auth_header=supervisor_token,
                serverless_token=identity_token,
                timeout_seconds=args.timeout,
            )

    _ensure_ok(approve_result, {200}, "POST /api/v1/review/activity/{id}/decision")
    if not isinstance(approve_result.data, dict) or approve_result.data.get("ok") is not True:
        raise E2EError("Approval response does not confirm ok=true")

    print("[6/7] Operativo delta pull after approval...")
    delta_pull_result = _json_request(
        "POST",
        _build_url(base_url, "/api/v1/sync/pull"),
        body={
            "project_id": args.project_id,
            "since_version": baseline_version,
            "limit": 500,
        },
        auth_header=operativo_token,
        serverless_token=identity_token,
        timeout_seconds=args.timeout,
    )
    _ensure_ok(delta_pull_result, {200}, "POST /api/v1/sync/pull delta")

    approved_item = None
    if isinstance(delta_pull_result.data, dict):
        for item in delta_pull_result.data.get("activities", []):
            if isinstance(item, dict) and str(item.get("uuid")) == activity_uuid:
                approved_item = item
                break

    if approved_item is None:
        full_pull_result = _json_request(
            "POST",
            _build_url(base_url, "/api/v1/sync/pull"),
            body={"project_id": args.project_id, "since_version": 0, "limit": 500},
            auth_header=operativo_token,
            serverless_token=identity_token,
            timeout_seconds=args.timeout,
        )
        _ensure_ok(full_pull_result, {200}, "POST /api/v1/sync/pull full fallback")
        if isinstance(full_pull_result.data, dict):
            for item in full_pull_result.data.get("activities", []):
                if isinstance(item, dict) and str(item.get("uuid")) == activity_uuid:
                    approved_item = item
                    break

    if approved_item is None:
        raise E2EError("Approved activity not found in pull responses")

    print("[7/7] Validate final execution_state from pull...")
    execution_state = str(approved_item.get("execution_state", ""))
    if execution_state != "COMPLETADA":
        raise E2EError(
            f"Expected execution_state=COMPLETADA, got {execution_state}. "
            f"Payload: {json.dumps(approved_item, ensure_ascii=False)}"
        )

    print("\n✅ E2E flow passed")
    print(f"Activity UUID: {activity_uuid}")
    print(f"Push status: {push_status}")
    print(f"Final execution_state: {execution_state}")

    if args.verbose:
        print("\nDebug summary:")
        print(f"- Baseline current_version: {baseline_version}")
        print(f"- Catalog version_id: {catalog_version_id}")
        print(f"- Timestamp UTC: {datetime.now(timezone.utc).isoformat()}")


def main() -> int:
    try:
        args = _parse_args()
        _run_flow(args)
        return 0
    except E2EError as exc:
        print(f"\n❌ E2E failed: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\n❌ E2E interrupted by user", file=sys.stderr)
        return 130
    except Exception as exc:
        print(f"\n❌ Unexpected error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
