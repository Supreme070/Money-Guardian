"""API v1 router combining all endpoints."""

from fastapi import APIRouter

from app.api.v1.endpoints import admin, admin_auth, admin_billing, admin_bulk, admin_export, admin_feature_flags, admin_notifications, admin_sse, auth, users, subscriptions, alerts, pulse, banking, email, webhooks, payments

api_router = APIRouter()

# Include all endpoint routers
api_router.include_router(
    auth.router,
    prefix="/auth",
    tags=["Authentication"],
)

api_router.include_router(
    users.router,
    prefix="/users",
    tags=["Users"],
)

api_router.include_router(
    subscriptions.router,
    prefix="/subscriptions",
    tags=["Subscriptions"],
)

api_router.include_router(
    alerts.router,
    prefix="/alerts",
    tags=["Alerts"],
)

api_router.include_router(
    pulse.router,
    prefix="/pulse",
    tags=["Daily Pulse"],
)

api_router.include_router(
    banking.router,
    prefix="/banking",
    tags=["Banking"],
)

api_router.include_router(
    email.router,
    prefix="/email",
    tags=["Email"],
)

api_router.include_router(
    webhooks.router,
    prefix="/webhooks",
    tags=["Webhooks"],
)

api_router.include_router(
    payments.router,
    prefix="/payments",
    tags=["Payments"],
)

api_router.include_router(
    admin_auth.router,
    prefix="/admin",
    tags=["Admin Auth"],
)

api_router.include_router(
    admin.router,
    prefix="/admin",
    tags=["Admin"],
)

api_router.include_router(
    admin_notifications.router,
    prefix="/admin/notifications",
    tags=["Admin Notifications"],
)

api_router.include_router(
    admin_billing.router,
    prefix="/admin/billing",
    tags=["Admin Billing"],
)

api_router.include_router(
    admin_feature_flags.router,
    tags=["Admin Feature Flags"],
)

api_router.include_router(
    admin_sse.router,
    prefix="/admin/sse",
    tags=["Admin SSE"],
)

api_router.include_router(
    admin_bulk.router,
    prefix="/admin/bulk",
    tags=["Admin Bulk Operations"],
)

api_router.include_router(
    admin_export.router,
    prefix="/admin/export",
    tags=["Admin Export"],
)
