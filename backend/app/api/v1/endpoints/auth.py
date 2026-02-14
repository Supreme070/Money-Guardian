"""Authentication endpoints."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.api.deps import DbSessionDep
from app.core.config import settings
from app.core.security import decode_token
from app.core.token_blacklist import blacklist_token, is_token_blacklisted
from app.core.rate_limit import limiter
from app.schemas.auth import (
    LoginRequest,
    LogoutRequest,
    PasswordResetConfirm,
    PasswordResetRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
)
from app.services.auth_service import (
    AuthService,
    EmailAlreadyExistsError,
    InvalidCredentialsError,
    InvalidResetTokenError,
    UserNotFoundError,
)

router = APIRouter()
security = HTTPBearer()

# Auth rate limit string, e.g. "10/minute"
_auth_limit = f"{settings.auth_rate_limit_per_minute}/minute"


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
)
@limiter.limit(_auth_limit)
async def register(
    request: Request,
    body: RegisterRequest,
    db: DbSessionDep,
) -> TokenResponse:
    """
    Register a new user.

    Creates a tenant and user account. Returns access and refresh tokens.
    """
    service = AuthService(db)

    try:
        user, tokens = await service.register(body)
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
@limiter.limit(_auth_limit)
async def login(
    request: Request,
    body: LoginRequest,
    db: DbSessionDep,
) -> TokenResponse:
    """
    Login with email and password.

    Returns access and refresh tokens.
    """
    service = AuthService(db)

    try:
        user, tokens = await service.login(body)
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
    body: RefreshRequest,
    db: DbSessionDep,
) -> TokenResponse:
    """
    Refresh access token using refresh token.

    Checks blacklist before issuing new tokens, then blacklists
    the old refresh token (one-time use / rotation).

    Returns new access and refresh tokens.
    """
    # Decode refresh token
    payload = decode_token(body.refresh_token)

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

    # Check if this refresh token has been revoked (logout or already used)
    if await is_token_blacklisted(body.refresh_token):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token has been revoked",
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

    # Rotate: blacklist the old refresh token so it can't be reused
    await blacklist_token(body.refresh_token, payload.exp)

    return TokenResponse(
        access_token=tokens.access_token,
        refresh_token=tokens.refresh_token,
        token_type="bearer",
        expires_in=settings.jwt_access_token_expire_minutes * 60,
    )


@router.post("/logout")
async def logout(
    body: LogoutRequest | None = None,
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict[str, str]:
    """
    Logout user.

    Blacklists the access token (from Authorization header) and the
    refresh token (from request body, if provided) in Redis so neither
    can be reused.
    """
    # Blacklist the access token
    access_token = credentials.credentials
    access_payload = decode_token(access_token)
    if access_payload is not None:
        await blacklist_token(access_token, access_payload.exp)

    # Blacklist the refresh token if provided
    if body is not None and body.refresh_token:
        refresh_payload = decode_token(body.refresh_token)
        if refresh_payload is not None:
            await blacklist_token(body.refresh_token, refresh_payload.exp)

    return {"message": "Successfully logged out"}


@router.post("/password-reset/request")
@limiter.limit(_auth_limit)
async def request_password_reset(
    request: Request,
    body: PasswordResetRequest,
    db: DbSessionDep,
) -> dict[str, str]:
    """
    Request a password reset.

    Sends a password reset email to the user if the email exists.
    Always returns success to prevent email enumeration.
    """
    service = AuthService(db)

    try:
        token = await service.request_password_reset(body.email)
        if token:
            # Send password reset email
            from app.services.email_sender_service import EmailSenderService
            from sqlalchemy import select
            from app.models.user import User

            result = await db.execute(
                select(User).where(User.email == body.email)
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
@limiter.limit(_auth_limit)
async def confirm_password_reset(
    request: Request,
    body: PasswordResetConfirm,
    db: DbSessionDep,
) -> dict[str, str]:
    """
    Confirm password reset with token.

    Resets the user's password if the token is valid.
    """
    service = AuthService(db)

    try:
        await service.confirm_password_reset(
            token=body.token,
            new_password=body.new_password,
        )
    except InvalidResetTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    return {"message": "Password has been reset successfully."}


@router.post("/verify-email")
@limiter.limit(_auth_limit)
async def verify_email(
    request: Request,
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
@limiter.limit(_auth_limit)
async def resend_verification(
    request: Request,
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
