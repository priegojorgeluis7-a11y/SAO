import json
import logging
import time
from contextlib import asynccontextmanager
from pathlib import Path
from uuid import uuid4

from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.api.v1 import (
    activities,
    assignments,
    audit,
    auth,
    catalog,
    completed_activities,
    dashboard,
    evidences,
    events,
    me,
    ocr,
    observations,
    projects,
    reports,
    review,
    sync,
    territory,
    users,
)
from app.core.config import settings
from app.core.firestore import check_firestore_connection
from app.core.request_context import reset_trace_id, set_trace_id

_access_logger = logging.getLogger("sao.access")


class _JsonFormatter(logging.Formatter):
    """Emit each log record as a single JSON line (Cloud Run compatible)."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict = {
            "severity": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
            "ts": self.formatTime(record, "%Y-%m-%dT%H:%M:%S"),
        }
        for key in ("trace_id", "method", "path", "status_code", "latency_ms", "user_id", "project_id"):
            if hasattr(record, key):
                payload[key] = getattr(record, key)
        if record.exc_info:
            payload["exc"] = self.formatException(record.exc_info)
        return json.dumps(payload, ensure_ascii=False)


def _configure_logging() -> None:
    """Switch root logger to JSON output when running in production."""
    from app.core.config import settings as _s  # local import avoids circular

    if _s.ENV == "development":
        return
    root = logging.getLogger()
    if root.handlers:
        for h in list(root.handlers):
            root.removeHandler(h)
    handler = logging.StreamHandler()
    handler.setFormatter(_JsonFormatter())
    root.addHandler(handler)
    root.setLevel(logging.INFO)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    """Application lifespan hook to validate required settings at startup."""
    _configure_logging()
    _ = settings.JWT_SECRET
    _ = settings.FIRESTORE_PROJECT_ID
    if settings.EVIDENCE_STORAGE_BACKEND == "local":
        Path(settings.LOCAL_UPLOADS_DIR).mkdir(parents=True, exist_ok=True)
    else:
        _ = settings.GCS_BUCKET
    yield

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan,
)


@app.middleware("http")
async def attach_trace_id(request: Request, call_next):
    """Attach and propagate request trace_id in context and response headers."""
    incoming_trace_id = request.headers.get("X-Trace-Id")
    trace_id = incoming_trace_id.strip() if incoming_trace_id else uuid4().hex
    request.state.trace_id = trace_id
    token = set_trace_id(trace_id)
    start_ms = time.monotonic()
    try:
        response = await call_next(request)
    finally:
        reset_trace_id(token)
    latency_ms = round((time.monotonic() - start_ms) * 1000, 1)
    response.headers["X-Trace-Id"] = trace_id
    user_id = getattr(request.state, "user_id", None)
    project_id = getattr(request.state, "project_id", None)
    _access_logger.info(
        "%s %s %s",
        request.method,
        request.url.path,
        response.status_code,
        extra={
            "trace_id": trace_id,
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
            "latency_ms": latency_ms,
            "user_id": user_id,
            "project_id": project_id,
        },
    )
    return response

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.get_cors_origins_list(),
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Request-Id"],
)

# Local file storage — serve uploaded evidence files as static assets (dev only)
if settings.EVIDENCE_STORAGE_BACKEND == "local":
    uploads_dir = Path(settings.LOCAL_UPLOADS_DIR)
    uploads_dir.mkdir(parents=True, exist_ok=True)
    app.mount("/uploads", StaticFiles(directory=str(uploads_dir)), name="uploads")

# Include routers
app.include_router(auth.router, prefix=settings.API_V1_STR)
app.include_router(catalog.router, prefix=settings.API_V1_STR)
app.include_router(activities.router, prefix=settings.API_V1_STR)
app.include_router(sync.router, prefix=settings.API_V1_STR)
app.include_router(evidences.router, prefix=settings.API_V1_STR)
app.include_router(events.router, prefix=settings.API_V1_STR)
app.include_router(me.router, prefix=settings.API_V1_STR)
app.include_router(users.router, prefix=settings.API_V1_STR)
app.include_router(assignments.router, prefix=settings.API_V1_STR)
app.include_router(projects.router, prefix=settings.API_V1_STR)
app.include_router(territory.router, prefix=settings.API_V1_STR)
app.include_router(audit.router, prefix=settings.API_V1_STR)
app.include_router(review.router, prefix=settings.API_V1_STR)
app.include_router(observations.router, prefix=settings.API_V1_STR)
app.include_router(ocr.router, prefix=settings.API_V1_STR)
app.include_router(reports.router, prefix=settings.API_V1_STR)
app.include_router(dashboard.router, prefix=settings.API_V1_STR)
app.include_router(completed_activities.router, prefix=settings.API_V1_STR)


@app.get("/")
def root():
    return {"status": "ok"}


@app.get("/health")
def health_check():
    checks: dict[str, str] = {}

    try:
        check_firestore_connection()
        checks["firestore"] = "ok"
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firestore connectivity check failed",
        ) from exc

    return {
        "status": "healthy",
        "data_backend": settings.DATA_BACKEND,
        "checks": checks,
    }


@app.get("/version")
def version_info():
    """Returns version and environment — used by clients for diagnostics."""
    return {
        "version": settings.VERSION,
        "env": settings.ENV,
        "api_prefix": settings.API_V1_STR,
    }
