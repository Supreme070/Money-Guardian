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
    db_pool_size: int = 20
    db_max_overflow: int = 10
    db_pool_pre_ping: bool = True
    db_pool_recycle: int = 3600

    # Redis
    redis_url: RedisDsn = Field(default="redis://localhost:6379/0")

    # JWT - MUST be set via JWT_SECRET_KEY env var. Default is for local dev only.
    jwt_secret_key: str = Field(default="LOCAL_DEV_ONLY__CHANGE_IN_PRODUCTION")
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 30
    jwt_refresh_token_expire_days: int = 7

    # Encryption master key for Fernet encryption (e.g., Plaid access tokens).
    # MUST be set separately from JWT secret in production.
    # Falls back to JWT secret if not set (with a warning).
    encryption_master_key: str | None = None

    # Firebase (for auth verification)
    firebase_credentials_path: str | None = None

    # External APIs - Plaid (USA/Canada)
    plaid_client_id: str | None = None
    plaid_secret: str | None = None
    plaid_environment: Literal["sandbox", "development", "production"] = "sandbox"
    plaid_webhook_url: str | None = None

    # Mono (Nigeria/Africa)
    mono_secret_key: str | None = None
    mono_public_key: str | None = None
    mono_environment: Literal["test", "live"] = "test"

    # Stitch (South Africa)
    stitch_client_id: str | None = None
    stitch_client_secret: str | None = None
    stitch_redirect_uri: str = "http://localhost:8000/api/v1/banking/stitch/callback"
    stitch_environment: Literal["test", "live"] = "test"

    # TrueLayer (UK/Europe)
    truelayer_client_id: str | None = None
    truelayer_client_secret: str | None = None
    truelayer_redirect_uri: str = "http://localhost:8000/api/v1/banking/truelayer/callback"
    truelayer_environment: Literal["sandbox", "live"] = "sandbox"

    # Tink (EU broad coverage)
    tink_client_id: str | None = None
    tink_client_secret: str | None = None
    tink_redirect_uri: str = "http://localhost:8000/api/v1/banking/tink/callback"
    tink_environment: Literal["sandbox", "production"] = "sandbox"

    # Google OAuth (Gmail integration)
    google_client_id: str | None = None
    google_client_secret: str | None = None
    google_redirect_uri: str = "http://localhost:8000/api/v1/email/oauth/callback"

    # Microsoft OAuth (Outlook integration)
    microsoft_client_id: str | None = None
    microsoft_client_secret: str | None = None
    microsoft_redirect_uri: str = "http://localhost:8000/api/v1/email/oauth/callback"

    # Stripe (payments)
    stripe_secret_key: str | None = None
    stripe_webhook_secret: str | None = None
    stripe_pro_price_id: str | None = None

    # Sentry (error monitoring)
    sentry_dsn: str | None = None
    sentry_traces_sample_rate: float = 0.1

    # Admin API
    admin_api_key: str | None = None

    # CORS - restrict to known frontend origins.
    # Override via CORS_ORIGINS env var (JSON array) in production.
    cors_origins: list[str] = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8080",
        "https://app.moneyguardian.co",
    ]

    # Rate Limiting
    rate_limit_per_minute: int = 60
    auth_rate_limit_per_minute: int = 10  # Stricter for auth endpoints

    # Email Provider ("ses" for production, "smtp" for local dev)
    email_provider: Literal["ses", "smtp"] = "smtp"

    # AWS SES (when email_provider = "ses")
    aws_access_key_id: str | None = None
    aws_secret_access_key: str | None = None
    aws_region: str = "us-east-1"
    ses_configuration_set: str | None = None
    ses_from_email: str = "noreply@moneyguardian.co"
    ses_from_name: str = "Money Guardian"

    # SMTP fallback (for local dev without AWS)
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_user: str | None = None
    smtp_password: str | None = None
    smtp_from_email: str = "noreply@moneyguardian.co"
    smtp_from_name: str = "Money Guardian"

    # App URLs (for email links)
    frontend_url: str = "https://app.moneyguardian.co"
    email_verify_url: str = "{frontend_url}/verify-email?token={token}"
    password_reset_url: str = "{frontend_url}/reset-password?token={token}"

    @property
    def async_database_url(self) -> str:
        """Get async database URL."""
        return str(self.database_url)


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()


settings = get_settings()
