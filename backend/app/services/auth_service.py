"""Authentication service - handles user registration and login."""

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

        # Create user
        user = User(
            tenant_id=tenant.id,
            email=request.email,
            hashed_password=get_password_hash(request.password),
            full_name=request.full_name,
            is_active=True,
            is_verified=False,  # TODO: Email verification
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
