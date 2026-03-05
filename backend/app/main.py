from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.api.v1 import (
    activities,
    assignments,
    audit,
    auth,
    catalog,
    dashboard,
    evidences,
    events,
    me,
    observations,
    projects,
    reports,
    review,
    sync,
    territory,
    users,
)
from app.core.config import settings
from app.core.database import check_db_connection, get_db


@asynccontextmanager
async def lifespan(_app: FastAPI):
    """Application lifespan hook to validate required settings at startup."""
    _ = settings.DATABASE_URL
    _ = settings.JWT_SECRET
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

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.get_cors_origins_list(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
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
app.include_router(reports.router, prefix=settings.API_V1_STR)
app.include_router(dashboard.router, prefix=settings.API_V1_STR)


@app.get("/")
def root():
    return {"status": "ok"}


@app.get("/health")
def health_check(db=Depends(get_db)):
    try:
        check_db_connection(db)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connectivity check failed",
        ) from exc
    return {"status": "healthy"}


@app.get("/version")
def version_info():
    """Returns version and environment — used by clients for diagnostics."""
    return {
        "version": settings.VERSION,
        "env": settings.ENV,
        "api_prefix": settings.API_V1_STR,
    }
