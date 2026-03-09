"""Admin impersonation service.

Allows super_admins to generate short-lived JWT tokens that act as a
specific user. Every impersonation is audit-logged.
"""

import logging
from datetime import datetime, timedelta, timezone
from uuid import UUID

from jose import jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.admin_user import AdminUser
from app.models.user import User
from app.services import audit_service

logger = logging.getLogger(__name__)

IMPERSONATION_TOKEN_MINUTES = 15


class ImpersonationError(Exception):
    """Base impersonation exception."""


class UserNotFoundError(ImpersonationError):
    """Raised when the target user does not exist."""


async def create_impersonation_token(
    db: AsyncSession,
    admin: AdminUser,
    user_id: str,
    *,
    ip_address: str = "",
    user_agent: str = "",
) -> dict[str, str | int]:
    """Create a short-lived JWT impersonating a regular user.

    The token contains the user's claims (sub, tenant_id, email) plus a
    ``token_type: "impersonation"`` marker so downstream middleware can
    distinguish it from normal access tokens.

    Returns:
        dict with access_token, user_email, user_name, expires_in (seconds).
    """
    target_uuid = UUID(user_id)

    # Look up target user
    result = await db.execute(
        select(User).where(User.id == target_uuid, User.is_active == True)  # noqa: E712
    )
    user = result.scalar_one_or_none()
    if user is None:
        raise UserNotFoundError(f"User {user_id} not found or inactive")

    # Build impersonation JWT
    now = datetime.now(timezone.utc)
    expire = now + timedelta(minutes=IMPERSONATION_TOKEN_MINUTES)
    payload = {
        "sub": str(user.id),
        "tenant_id": str(user.tenant_id),
        "email": user.email,
        "token_type": "impersonation",
        "impersonated_by": str(admin.id),
        "exp": int(expire.timestamp()),
        "iat": int(now.timestamp()),
    }
    access_token: str = jwt.encode(
        payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm,
    )

    # Audit log
    await audit_service.log_action(
        db,
        admin_user_id=admin.id,
        action="user.impersonate",
        entity_type="user",
        entity_id=target_uuid,
        details={
            "user_email": user.email,
            "expires_in": IMPERSONATION_TOKEN_MINUTES * 60,
        },
        ip_address=ip_address,
        user_agent=user_agent,
    )

    logger.info(
        "Admin %s (%s) impersonating user %s (%s)",
        admin.id, admin.email, user.id, user.email,
    )

    return {
        "access_token": access_token,
        "user_email": user.email,
        "user_name": user.full_name or "",
        "expires_in": IMPERSONATION_TOKEN_MINUTES * 60,
    }
