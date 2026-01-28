"""Security utilities for authentication and authorization."""

from datetime import datetime, timedelta, timezone
from typing import Literal
from uuid import UUID
import base64
import hashlib

import bcrypt
from cryptography.fernet import Fernet
from jose import JWTError, jwt
from pydantic import BaseModel

from app.core.config import settings


# -----------------------------------------------------------------------------
# Token Encryption (for sensitive data like Plaid access tokens)
# -----------------------------------------------------------------------------

def _get_encryption_key() -> bytes:
    """
    Derive a Fernet-compatible key from JWT secret.

    Fernet requires a 32-byte base64-encoded key.
    We derive this from the JWT secret using SHA-256.
    """
    key_bytes = hashlib.sha256(settings.jwt_secret_key.encode()).digest()
    return base64.urlsafe_b64encode(key_bytes)


def encrypt_sensitive_data(plaintext: str) -> str:
    """
    Encrypt sensitive data (e.g., Plaid access tokens).

    Returns base64-encoded encrypted string.
    """
    fernet = Fernet(_get_encryption_key())
    encrypted = fernet.encrypt(plaintext.encode())
    return encrypted.decode()


def decrypt_sensitive_data(ciphertext: str) -> str:
    """
    Decrypt sensitive data.

    Returns original plaintext string.
    """
    fernet = Fernet(_get_encryption_key())
    decrypted = fernet.decrypt(ciphertext.encode())
    return decrypted.decode()


class TokenPayload(BaseModel):
    """JWT token payload - strictly typed."""

    sub: str  # user_id
    tenant_id: str
    email: str
    token_type: Literal["access", "refresh"]
    exp: int  # Unix timestamp
    iat: int  # Unix timestamp


class TokenPair(BaseModel):
    """Access and refresh token pair."""

    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash."""
    return bcrypt.checkpw(
        plain_password.encode("utf-8"),
        hashed_password.encode("utf-8"),
    )


def get_password_hash(password: str) -> str:
    """Hash a password using bcrypt."""
    return bcrypt.hashpw(
        password.encode("utf-8"),
        bcrypt.gensalt(),
    ).decode("utf-8")


def create_access_token(
    user_id: UUID,
    tenant_id: UUID,
    email: str,
) -> str:
    """Create a JWT access token with tenant_id."""
    now = datetime.now(timezone.utc)
    expire = now + timedelta(minutes=settings.jwt_access_token_expire_minutes)

    # Use dict with Unix timestamps for JWT compatibility
    payload = {
        "sub": str(user_id),
        "tenant_id": str(tenant_id),
        "email": email,
        "token_type": "access",
        "exp": int(expire.timestamp()),
        "iat": int(now.timestamp()),
    }

    return jwt.encode(
        payload,
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

    # Use dict with Unix timestamps for JWT compatibility
    payload = {
        "sub": str(user_id),
        "tenant_id": str(tenant_id),
        "email": email,
        "token_type": "refresh",
        "exp": int(expire.timestamp()),
        "iat": int(now.timestamp()),
    }

    return jwt.encode(
        payload,
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
