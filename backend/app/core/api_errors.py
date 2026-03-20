"""API error helpers with optional structured payload support."""

from typing import Any

from fastapi import HTTPException, Request

from app.core.request_context import get_trace_id


def api_error(
    *,
    status_code: int,
    code: str,
    message: str,
    request: Request | None = None,
    details: dict[str, Any] | None = None,
    headers: dict[str, str] | None = None,
    legacy_detail: bool = True,
) -> HTTPException:
    """Build a normalized HTTPException while preserving legacy clients by default."""
    trace_id: str | None = None
    if request is not None:
        trace_id = getattr(request.state, "trace_id", None)
    if trace_id is None:
        trace_id = get_trace_id()

    response_headers = dict(headers or {})
    response_headers["X-Error-Code"] = code
    if trace_id:
        response_headers["X-Trace-Id"] = trace_id

    if legacy_detail:
        detail: str | dict[str, Any] = message
    else:
        detail = {
            "code": code,
            "message": message,
            "details": details,
            "trace_id": trace_id,
        }

    return HTTPException(status_code=status_code, detail=detail, headers=response_headers)