from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from app.api.v1 import auth, catalog, activities, sync, evidences, events
from app.core.config import settings
from app.core.database import check_db_connection, get_db


@asynccontextmanager
async def lifespan(_app: FastAPI):
    """Application lifespan hook to validate required settings at startup."""
    _ = settings.DATABASE_URL
    _ = settings.JWT_SECRET
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

# Include routers
app.include_router(auth.router, prefix=settings.API_V1_STR)
app.include_router(catalog.router, prefix=settings.API_V1_STR)
app.include_router(activities.router, prefix=settings.API_V1_STR)
app.include_router(sync.router, prefix=settings.API_V1_STR)
app.include_router(evidences.router, prefix=settings.API_V1_STR)
app.include_router(events.router, prefix=settings.API_V1_STR)


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
