"""Role-based access control for admin portal.

Defines permission matrix and provides FastAPI dependency factory.
"""

from typing import Literal

from fastapi import Depends, HTTPException, status

from app.models.admin_user import AdminUser

AdminRole = Literal["super_admin", "admin", "support", "viewer"]

# ---------------------------------------------------------------------------
# Permission matrix: role -> set of permissions
# ---------------------------------------------------------------------------

ROLE_PERMISSIONS: dict[str, set[str]] = {
    "super_admin": {
        "users.view",
        "users.modify",
        "tenants.view",
        "tenants.modify",
        "analytics.view",
        "notifications.send",
        "impersonate",
        "admin_users.manage",
        "feature_flags.manage",
        "audit_log.view",
        "bulk_operations",
        "billing.manage",
        "approvals.manage",
    },
    "admin": {
        "users.view",
        "users.modify",
        "tenants.view",
        "tenants.modify",
        "analytics.view",
        "notifications.send",
        "feature_flags.manage",
        "audit_log.view",
        "bulk_operations",
        "billing.manage",
    },
    "support": {
        "users.view",
        "users.modify",
        "tenants.view",
        "notifications.send",
    },
    "viewer": {
        "users.view",
        "tenants.view",
        "analytics.view",
    },
}


def has_permission(role: str, permission: str) -> bool:
    """Check if a role has a specific permission."""
    perms = ROLE_PERMISSIONS.get(role, set())
    return permission in perms


def require_permission(permission: str):
    """FastAPI dependency factory requiring a specific permission.

    Usage:
        @router.get("/admin/users")
        async def list_users(
            admin: AdminUser = Depends(require_permission("users.view")),
        ):
            ...
    """
    from app.api.v1.endpoints.admin_auth import get_current_admin

    async def _check(
        admin: AdminUser = Depends(get_current_admin),
    ) -> AdminUser:
        if not has_permission(admin.role, permission):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Insufficient permissions: requires '{permission}'",
            )
        return admin

    return _check
