"""Application configuration loaded from environment variables."""

import os
from functools import lru_cache

from pydantic import ValidationError
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime settings for API, persistence, security, and integrations."""

    PROJECT_NAME: str = "SAO Backend"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    # Database
    DATABASE_URL: str
    
    # JWT
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440  # 24 hours
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Google Cloud Storage
    GCS_BUCKET: str
    SIGNED_URL_EXPIRE_MINUTES: int = 15
    
    model_config = SettingsConfigDict(case_sensitive=True, extra="ignore")

    def get_cors_origins_list(self) -> list[str]:
        """Get CORS origins from env or defaults (comma-separated)."""
        cors_str = os.getenv("CORS_ORIGINS", "http://localhost:8000,http://localhost:3000")
        if not cors_str:
            return ["http://localhost:8000", "http://localhost:3000"]
        return [origin.strip() for origin in cors_str.split(",") if origin.strip()]


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
