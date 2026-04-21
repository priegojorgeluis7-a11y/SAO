"""Shared pytest fixtures for Firestore-only backend tests."""

import os

# Must be set BEFORE any app module is imported so Settings() validates correctly
# in CI environments where there is no .env file.
os.environ.setdefault("DATA_BACKEND", "firestore")
os.environ.setdefault("JWT_SECRET", "test-secret-for-ci-tests-minimum32chars!")
os.environ.setdefault("GCS_BUCKET", "test-bucket")
os.environ.setdefault("CORS_ORIGINS", "http://localhost:8000,http://localhost:3000")

import pytest
from fastapi.testclient import TestClient

from app.core.rate_limit import rate_limiter
from app.main import app


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
    """Retired SQL fixture. Raises an error to prevent accidentally using it in new tests."""
    pytest.fail(
        "The 'db' fixture is retired. Use the 'client' fixture for Firestore-based tests. "
        "If this is intentional legacy SQL code, remove the test."
    )


@pytest.fixture(scope="function")
def test_user(db):
    """Retired SQL fixture kept for compatibility signature."""
    pytest.fail(
        "The 'test_user' fixture is retired. Use 'client' + dependency_overrides instead."
    )


@pytest.fixture(scope="function")
def auth_headers(db):
    """Retired SQL fixture kept for compatibility signature."""
    pytest.fail(
        "The 'auth_headers' fixture is retired. Use 'client' + dependency_overrides instead."
    )
