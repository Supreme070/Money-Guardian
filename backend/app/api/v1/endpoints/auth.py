"""Authentication endpoints."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import DbSessionDep, get_token_payload
from app.core.config import settings
from app.core.security import TokenPayload, decode_token
from app.schemas.auth import (
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
)
from app.schemas.user import UserResponse
from app.services.auth_service import (
    AuthService,
    EmailAlreadyExistsError,
    InvalidCredentialsError,
    UserNotFoundError,
)

router = APIRouter()


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register(
    request: RegisterRequest,
    db: DbSessionDep,
) -> TokenResponse:
    """
    Register a new user.

    Creates a tenant and user account. Returns access and refresh tokens.
    """
    service = AuthService(db)

    try:
        user, tokens = await service.register(request)
    except EmailAlreadyExistsError as e:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(e),
        )

    return TokenResponse(
        access_token=tokens.access_token,
        refresh_token=tokens.refresh_token,
        token_type="bearer",
        expires_in=settings.jwt_access_token_expire_minutes * 60,
    )


@router.post(
    "/login",
    response_model=TokenResponse,
)
async def login(
    request: LoginRequest,
    db: DbSessionDep,
) -> TokenResponse:
    """
    Login with email and password.

    Returns access and refresh tokens.
    """
    service = AuthService(db)

    try:
        user, tokens = await service.login(request)
    except InvalidCredentialsError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"},
        )

    return TokenResponse(
        access_token=tokens.access_token,
        refresh_token=tokens.refresh_token,
        token_type="bearer",
        expires_in=settings.jwt_access_token_expire_minutes * 60,
    )


@router.post(
    "/refresh",
    response_model=TokenResponse,
)
async def refresh(
    request: RefreshRequest,
    db: DbSessionDep,
) -> TokenResponse:
    """
    Refresh access token using refresh token.

    Returns new access and refresh tokens.
    """
    # Decode refresh token
    payload = decode_token(request.refresh_token)

    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if payload.token_type != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type",
            headers={"WWW-Authenticate": "Bearer"},
        )

    service = AuthService(db)

    try:
        tokens = await service.refresh_tokens(
            user_id=UUID(payload.sub),
            tenant_id=UUID(payload.tenant_id),
        )
    except UserNotFoundError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"},
        )

    return TokenResponse(
        access_token=tokens.access_token,
        refresh_token=tokens.refresh_token,
        token_type="bearer",
        expires_in=settings.jwt_access_token_expire_minutes * 60,
    )


@router.post("/logout")
async def logout() -> dict[str, str]:
    """
    Logout user.

    Client should discard tokens. Server-side token invalidation
    would require a token blacklist (Redis).
    """
    return {"message": "Successfully logged out"}
