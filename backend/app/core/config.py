"""Application configuration loaded from environment variables."""

from functools import lru_cache

from pydantic import ValidationError
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime settings for API, persistence, security, and integrations."""

    PROJECT_NAME: str = "SAO Backend"
    VERSION: str = "1.1.0"
    API_V1_STR: str = "/api/v1"

    # Environment: "development" | "staging" | "production"
    ENV: str = "development"

    # Database
    DATABASE_URL: str

    # JWT
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440  # 24 hours
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Signup invite codes
    SIGNUP_INVITE_CODE: str | None = None
    ADMIN_INVITE_CODE: str | None = None

    # Google Cloud Storage
    GCS_BUCKET: str = "local"
    SIGNED_URL_EXPIRE_MINUTES: int = 15

    # Evidence storage backend: "gcs" (production) | "local" (development)
    # In local mode files are saved to LOCAL_UPLOADS_DIR and served via /uploads/*
    EVIDENCE_STORAGE_BACKEND: str = "gcs"
    # Base URL for building local upload/download URLs (only when EVIDENCE_STORAGE_BACKEND=local)
    LOCAL_BASE_URL: str = "http://localhost:8000"
    # Directory where evidence files are stored in local mode
    LOCAL_UPLOADS_DIR: str = "./uploads"

    # CORS — comma-separated list of allowed origins.
    # MUST be set via CORS_ORIGINS env var in staging/production.
    # Default only covers local development.
    CORS_ORIGINS: str = "http://localhost:8000,http://localhost:3000"

    # Rate limiting
    RATE_LIMIT_WINDOW_SECONDS: int = 60
    RATE_LIMIT_AUTH_LOGIN_PER_MINUTE: int = 10
    RATE_LIMIT_AUTH_REFRESH_PER_MINUTE: int = 30
    RATE_LIMIT_EVIDENCE_UPLOAD_INIT_PER_MINUTE: int = 60
    RATE_LIMIT_SYNC_PUSH_PER_MINUTE: int = 30

    model_config = SettingsConfigDict(case_sensitive=True, extra="ignore")

    def get_cors_origins_list(self) -> list[str]:
        """Return CORS_ORIGINS as a parsed list."""
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]


@lru_cache()
def get_settings() -> Settings:
    """Return cached settings instance."""
    try:
        return Settings()
    except ValidationError as exc:
        missing_fields = [
            err.get("loc", ["?"])[0]
            for err in exc.errors()
            if err.get("type") == "missing"
        ]
        if missing_fields:
            missing = ", ".join(sorted(set(str(name) for name in missing_fields)))
            raise RuntimeError(
                f"Missing required environment variables: {missing}"
            ) from exc
        raise RuntimeError(f"Invalid configuration: {exc}") from exc


settings = get_settings()
