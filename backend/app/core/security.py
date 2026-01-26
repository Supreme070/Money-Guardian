"""Security utilities for authentication and authorization."""

from datetime import datetime, timedelta, timezone
from typing import Literal
from uuid import UUID

from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel

from app.core.config import settings


# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class TokenPayload(BaseModel):
    """JWT token payload - strictly typed."""

    sub: str  # user_id
    tenant_id: str
    email: str
    token_type: Literal["access", "refresh"]
    exp: datetime
    iat: datetime


class TokenPair(BaseModel):
    """Access and refresh token pair."""

    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash."""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Hash a password."""
    return pwd_context.hash(password)


def create_access_token(
    user_id: UUID,
    tenant_id: UUID,
    email: str,
) -> str:
    """Create a JWT access token with tenant_id."""
    now = datetime.now(timezone.utc)
    expire = now + timedelta(minutes=settings.jwt_access_token_expire_minutes)

    payload = TokenPayload(
        sub=str(user_id),
        tenant_id=str(tenant_id),
        email=email,
        token_type="access",
        exp=expire,
        iat=now,
    )

    return jwt.encode(
        payload.model_dump(mode="json"),
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )


def create_refresh_token(
    user_id: UUID,
    tenant_id: UUID,
    email: str,
) -> str:
    """Create a JWT refresh token with tenant_id."""
    now = datetime.now(timezone.utc)
    expire = now + timedelta(days=settings.jwt_refresh_token_expire_days)

    payload = TokenPayload(
        sub=str(user_id),
        tenant_id=str(tenant_id),
        email=email,
        token_type="refresh",
        exp=expire,
        iat=now,
    )

    return jwt.encode(
        payload.model_dump(mode="json"),
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )


def create_token_pair(
    user_id: UUID,
    tenant_id: UUID,
    email: str,
) -> TokenPair:
    """Create both access and refresh tokens."""
    return TokenPair(
        access_token=create_access_token(user_id, tenant_id, email),
        refresh_token=create_refresh_token(user_id, tenant_id, email),
    )


def decode_token(token: str) -> TokenPayload | None:
    """Decode and validate a JWT token."""
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
        )
        return TokenPayload(**payload)
    except JWTError:
        return None
