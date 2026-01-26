"""Application configuration with strict typing."""

from functools import lru_cache
from typing import Literal

from pydantic import Field, PostgresDsn, RedisDsn
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Application
    app_name: str = "Money Guardian API"
    app_version: str = "1.0.0"
    debug: bool = False
    environment: Literal["development", "staging", "production"] = "development"

    # API
    api_v1_prefix: str = "/api/v1"

    # Database
    database_url: PostgresDsn = Field(
        default="postgresql+asyncpg://postgres:postgres@localhost:5432/money_guardian"
    )
    database_echo: bool = False

    # Redis
    redis_url: RedisDsn = Field(default="redis://localhost:6379/0")

    # JWT
    jwt_secret_key: str = Field(default="CHANGE_ME_IN_PRODUCTION")
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 30
    jwt_refresh_token_expire_days: int = 7

    # Firebase (for auth verification)
    firebase_credentials_path: str | None = None

    # External APIs
    plaid_client_id: str | None = None
    plaid_secret: str | None = None
    plaid_environment: Literal["sandbox", "development", "production"] = "sandbox"

    stripe_secret_key: str | None = None
    stripe_webhook_secret: str | None = None

    # CORS
    cors_origins: list[str] = ["http://localhost:3000", "http://localhost:8080"]

    # Rate Limiting
    rate_limit_per_minute: int = 60

    @property
    def async_database_url(self) -> str:
        """Get async database URL."""
        return str(self.database_url)


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()


settings = get_settings()
