"""API dependencies for authentication and authorization."""

from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import TokenPayload, decode_token
from app.db.session import get_db
from app.models.user import User

# Bearer token security scheme
security = HTTPBearer()


class CurrentUser:
    """Current authenticated user with tenant context."""

    def __init__(
        self,
        user_id: UUID,
        tenant_id: UUID,
        email: str,
        user: User,
    ) -> None:
        self.user_id = user_id
        self.tenant_id = tenant_id
        self.email = email
        self.user = user


async def get_token_payload(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(security)],
) -> TokenPayload:
    """Extract and validate JWT token payload."""
    token = credentials.credentials
    payload = decode_token(token)

    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if payload.token_type != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return payload


async def get_current_user(
    token: Annotated[TokenPayload, Depends(get_token_payload)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> CurrentUser:
    """
    Get current authenticated user with tenant context.

    CRITICAL: This is the entry point for tenant isolation.
    All downstream services receive tenant_id from this dependency.
    """
    user_id = UUID(token.sub)
    tenant_id = UUID(token.tenant_id)

    # Fetch user from database
    result = await db.execute(
        select(User).where(
            User.id == user_id,
            User.tenant_id == tenant_id,  # Verify tenant match
            User.is_active == True,
        )
    )
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return CurrentUser(
        user_id=user_id,
        tenant_id=tenant_id,
        email=token.email,
        user=user,
    )


async def get_current_active_user(
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
) -> CurrentUser:
    """Get current active user (alias for clarity)."""
    if not current_user.user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is disabled",
        )
    return current_user


# Type aliases for cleaner dependency injection
CurrentUserDep = Annotated[CurrentUser, Depends(get_current_user)]
DbSessionDep = Annotated[AsyncSession, Depends(get_db)]
