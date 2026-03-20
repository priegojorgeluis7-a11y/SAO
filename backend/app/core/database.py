"""Database engine, session factory, and FastAPI dependency helpers."""

from collections.abc import Generator
from typing import Optional

from fastapi import HTTPException, status
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session, declarative_base, sessionmaker

from app.core.config import settings

_sql_enabled = settings.DATA_BACKEND in {"postgres", "dual"}

if _sql_enabled:
    if not settings.DATABASE_URL:
        raise RuntimeError(
            "DATABASE_URL is required when DATA_BACKEND is postgres or dual"
        )
    engine = create_engine(
        settings.DATABASE_URL,
        pool_pre_ping=True,
        future=True,
    )
    SessionLocal = sessionmaker(
        bind=engine, autocommit=False, autoflush=False, class_=Session
    )
else:
    engine = None
    SessionLocal = None

Base = declarative_base()


def get_db() -> Generator[Session, None, None]:
    """FastAPI dependency to provide a SQLAlchemy session."""
    if SessionLocal is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="SQL database is disabled for current DATA_BACKEND mode",
        )
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_db_optional() -> Generator[Optional[Session], None, None]:
    """FastAPI dependency that yields None when SQL is disabled."""
    if SessionLocal is None:
        yield None
        return

    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def check_db_connection(db: Session) -> None:
    """Run a lightweight query to verify database connectivity."""
    db.execute(text("SELECT 1"))
