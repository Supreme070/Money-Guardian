"""Authentication service - handles user registration and login."""

import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import (
    TokenPair,
    create_token_pair,
    get_password_hash,
    verify_password,
)
from app.models.tenant import Tenant
from app.models.user import User
from app.schemas.auth import LoginRequest, RegisterRequest


class AuthServiceError(Exception):
    """Base exception for auth service errors."""

    pass


class EmailAlreadyExistsError(AuthServiceError):
    """Raised when email is already registered."""

    pass


class InvalidCredentialsError(AuthServiceError):
    """Raised when credentials are invalid."""

    pass


class UserNotFoundError(AuthServiceError):
    """Raised when user is not found."""

    pass


class InvalidResetTokenError(AuthServiceError):
    """Raised when password reset token is invalid or expired."""

    pass


class AuthService:
    """
    Authentication service.

    Handles user registration, login, and token management.
    Creates tenant on registration (single-user tenant model).
    """

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def register(self, request: RegisterRequest) -> tuple[User, TokenPair]:
        """
        Register a new user.

        Creates a tenant and user in a single transaction.
        Returns user and token pair.
        """
        # Check if email already exists
        existing = await self.db.execute(
            select(User).where(User.email == request.email)
        )
        if existing.scalar_one_or_none() is not None:
            raise EmailAlreadyExistsError(f"Email {request.email} is already registered")

        # Create tenant (single-user tenant model)
        tenant = Tenant(
            name=request.full_name or request.email.split("@")[0],
            tier="free",
            status="active",
        )
        self.db.add(tenant)
        await self.db.flush()  # Get tenant.id

        # Create user with consent timestamps
        now = datetime.now(timezone.utc)
        user = User(
            tenant_id=tenant.id,
            email=request.email,
            hashed_password=get_password_hash(request.password),
            full_name=request.full_name,
            is_active=True,
            is_verified=False,
            terms_accepted_at=now if request.accepted_terms else None,
            privacy_accepted_at=now if request.accepted_privacy else None,
        )
        self.db.add(user)
        await self.db.flush()  # Get user.id

        # Create tokens
        tokens = create_token_pair(
            user_id=user.id,
            tenant_id=tenant.id,
            email=user.email,
        )

        await self.db.commit()

        # Send verification email (non-blocking, don't fail registration)
        try:
            from app.services.email_sender_service import EmailSenderService
            email_service = EmailSenderService(self.db)
            await email_service.send_verification_email(
                user_id=str(user.id),
                email=user.email,
            )
        except Exception:
            pass  # Registration succeeds even if email fails
        await self.db.refresh(user)

        return user, tokens

    async def login(self, request: LoginRequest) -> tuple[User, TokenPair]:
        """
        Authenticate user and return tokens.

        Validates email and password, returns user and token pair.
        """
        # Find user by email
        result = await self.db.execute(
            select(User).where(User.email == request.email)
        )
        user = result.scalar_one_or_none()

        if user is None:
            raise InvalidCredentialsError("Invalid email or password")

        # Verify password
        if not verify_password(request.password, user.hashed_password):
            raise InvalidCredentialsError("Invalid email or password")

        # Check if user is active
        if not user.is_active:
            raise InvalidCredentialsError("Account is disabled")

        # Create tokens
        tokens = create_token_pair(
            user_id=user.id,
            tenant_id=user.tenant_id,
            email=user.email,
        )

        return user, tokens

    async def refresh_tokens(
        self,
        user_id: UUID,
        tenant_id: UUID,
    ) -> TokenPair:
        """
        Refresh tokens for a user.

        Validates user still exists and is active.
        """
        # Verify user exists and is active
        result = await self.db.execute(
            select(User).where(
                User.id == user_id,
                User.tenant_id == tenant_id,
                User.is_active == True,
            )
        )
        user = result.scalar_one_or_none()

        if user is None:
            raise UserNotFoundError("User not found or inactive")

        # Create new tokens
        return create_token_pair(
            user_id=user.id,
            tenant_id=user.tenant_id,
            email=user.email,
        )

    async def request_password_reset(self, email: str) -> str | None:
        """
        Request a password reset.

        Generates a secure token and stores it with 1-hour expiry.
        Returns the token (for email sending) or None if user not found.

        Note: Caller should always return success to prevent email enumeration.
        """
        # Find user by email
        result = await self.db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()

        if user is None:
            return None

        # Generate secure token and store its hash (never store plaintext)
        token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        expires_at = datetime.now(timezone.utc) + timedelta(hours=1)

        # Store hashed token - the raw token is returned to the caller for email
        user.password_reset_token = token_hash
        user.password_reset_token_expires_at = expires_at

        await self.db.commit()

        return token

    async def confirm_password_reset(
        self,
        token: str,
        new_password: str,
    ) -> None:
        """
        Confirm password reset with token.

        Validates token and updates password.
        Raises InvalidResetTokenError if token is invalid or expired.
        """
        # Hash the incoming token and compare against stored hash
        token_hash = hashlib.sha256(token.encode()).hexdigest()

        result = await self.db.execute(
            select(User).where(User.password_reset_token == token_hash)
        )
        user = result.scalar_one_or_none()

        if user is None:
            raise InvalidResetTokenError("Invalid or expired reset token")

        # Check expiration
        if (
            user.password_reset_token_expires_at is None
            or user.password_reset_token_expires_at.replace(tzinfo=timezone.utc)
            < datetime.now(timezone.utc)
        ):
            # Clear expired token
            user.password_reset_token = None
            user.password_reset_token_expires_at = None
            await self.db.commit()
            raise InvalidResetTokenError("Reset token has expired")

        # Update password
        user.hashed_password = get_password_hash(new_password)
        user.password_reset_token = None
        user.password_reset_token_expires_at = None

        await self.db.commit()
