"""Shared pytest fixtures for Firestore-only backend tests."""

import os

import pytest
from fastapi.testclient import TestClient

from app.core.rate_limit import rate_limiter
from app.main import app

os.environ.setdefault("DATA_BACKEND", "firestore")
os.environ.setdefault("JWT_SECRET", "test-secret")
os.environ.setdefault("GCS_BUCKET", "test-bucket")
os.environ.setdefault("CORS_ORIGINS", "http://localhost:8000,http://localhost:3000")


@pytest.fixture(scope="function")
def client():
    """Create test client for firestore-only routes."""
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture(autouse=True)
def reset_rate_limiter():
    rate_limiter.reset()
    yield
    rate_limiter.reset()


@pytest.fixture(scope="function")
def db():
    """Retired SQL fixture: skip legacy postgres/sqlite tests."""
    pytest.skip("SQL legacy tests retired: backend test suite is firestore-only")


@pytest.fixture(scope="function")
def test_user(db):
    """Retired SQL fixture kept for compatibility with legacy tests."""
    pytest.skip("SQL legacy tests retired: backend test suite is firestore-only")


@pytest.fixture(scope="function")
def auth_headers(db):
    """Retired SQL fixture kept for compatibility with legacy tests."""
    pytest.skip("SQL legacy tests retired: backend test suite is firestore-only")
