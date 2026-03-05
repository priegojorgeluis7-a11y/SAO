"""Shared pytest fixtures for backend API tests."""

import os

from uuid import uuid4

import pytest
from sqlalchemy import create_engine
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.ext.compiler import compiles
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient
from sqlalchemy.orm import sessionmaker

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret")
os.environ.setdefault("GCS_BUCKET", "test-bucket")
os.environ.setdefault("CORS_ORIGINS", "http://localhost:8000,http://localhost:3000")

# Import ALL model modules so Base.metadata.create_all() creates every table.
import app.models.activity  # noqa: F401
import app.models.audit_log  # noqa: F401
import app.models.catalog  # noqa: F401
import app.models.catalog_effective  # noqa: F401
import app.models.event  # noqa: F401
import app.models.evidence  # noqa: F401
import app.models.front  # noqa: F401
import app.models.location  # noqa: F401
import app.models.observation  # noqa: F401
import app.models.permission  # noqa: F401
import app.models.project  # noqa: F401
import app.models.project_location_scope  # noqa: F401
import app.models.reject_reason  # noqa: F401
import app.models.role  # noqa: F401
import app.models.user_role_scope  # noqa: F401
from app.core.database import Base, get_db
from app.core.rate_limit import rate_limiter
from app.core.security import get_password_hash
from app.main import app
from app.models.user import User, UserStatus

# Test database — true in-memory con StaticPool para que todas las
# conexiones (TestClient + fixture db) compartan la misma DB.
TEST_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@compiles(PGUUID, "sqlite")
def _compile_uuid_sqlite(_type, _compiler, **_kw):
    # CI uses SQLite for tests; map PostgreSQL UUID columns to CHAR(36).
    return "CHAR(36)"


@pytest.fixture(scope="function")
def db():
    """Create test database"""
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db):
    """Create test client"""
    def override_get_db():
        yield db
    
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()


@pytest.fixture(autouse=True)
def reset_rate_limiter():
    rate_limiter.reset()
    yield
    rate_limiter.reset()


@pytest.fixture
def test_user(db):
    """Create test user"""
    unique_email = f"test-{uuid4().hex[:8]}@example.com"
    user = User(
        id=uuid4(),
        email=unique_email,
        password_hash=get_password_hash("testpass123"),
        full_name="Test User",
        status=UserStatus.ACTIVE
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def auth_headers(client, test_user):
    """Get auth headers with JWT token"""
    response = client.post(
        "/api/v1/auth/login",
        json={"email": test_user.email, "password": "testpass123"}
    )
    assert response.status_code == 200
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}
