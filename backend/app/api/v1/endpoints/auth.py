"""Authentication endpoints."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import DbSessionDep, get_token_payload
from app.core.config import settings
from app.core.security import TokenPayload, decode_token
from app.schemas.auth import (
    LoginRequest,
    PasswordResetConfirm,
    PasswordResetRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
)
from app.schemas.user import UserResponse
from app.services.auth_service import (
    AuthService,
    EmailAlreadyExistsError,
    InvalidCredentialsError,
    InvalidResetTokenError,
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


@router.post("/password-reset/request")
async def request_password_reset(
    request: PasswordResetRequest,
    db: DbSessionDep,
) -> dict[str, str]:
    """
    Request a password reset.

    Sends a password reset email to the user if the email exists.
    Always returns success to prevent email enumeration.
    """
    service = AuthService(db)

    try:
        token = await service.request_password_reset(request.email)
        if token:
            # Send password reset email
            from app.services.email_sender_service import EmailSenderService
            from sqlalchemy import select
            from app.models.user import User

            result = await db.execute(
                select(User).where(User.email == request.email)
            )
            user = result.scalar_one_or_none()
            if user:
                email_service = EmailSenderService(db)
                await email_service.send_password_reset_email(
                    user_id=str(user.id),
                    email=user.email,
                )
    except UserNotFoundError:
        # Don't reveal if email exists - always return success
        pass

    return {
        "message": "If an account with that email exists, a password reset link has been sent."
    }


@router.post("/password-reset/confirm")
async def confirm_password_reset(
    request: PasswordResetConfirm,
    db: DbSessionDep,
) -> dict[str, str]:
    """
    Confirm password reset with token.

    Resets the user's password if the token is valid.
    """
    service = AuthService(db)

    try:
        await service.confirm_password_reset(
            token=request.token,
            new_password=request.new_password,
        )
    except InvalidResetTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    return {"message": "Password has been reset successfully."}


@router.post("/verify-email")
async def verify_email(
    token: str,
    db: DbSessionDep,
) -> dict[str, str]:
    """
    Verify user email with verification token.

    The token is sent to the user's email address on registration.
    """
    from app.services.email_sender_service import EmailSenderService

    email_service = EmailSenderService(db)
    verified = await email_service.verify_email_token(token)

    if not verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification token",
        )

    return {"message": "Email verified successfully."}


@router.post("/resend-verification")
async def resend_verification(
    email: str,
    db: DbSessionDep,
) -> dict[str, str]:
    """
    Resend email verification link.

    Always returns success to prevent email enumeration.
    """
    from sqlalchemy import select
    from app.models.user import User
    from app.services.email_sender_service import EmailSenderService

    result = await db.execute(
        select(User).where(User.email == email, User.is_verified == False)
    )
    user = result.scalar_one_or_none()

    if user:
        email_service = EmailSenderService(db)
        await email_service.send_verification_email(
            user_id=str(user.id),
            email=user.email,
        )

    return {"message": "If the email exists and is unverified, a verification link has been sent."}
