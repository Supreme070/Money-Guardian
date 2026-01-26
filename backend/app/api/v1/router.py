"""API v1 router combining all endpoints."""

from fastapi import APIRouter

from app.api.v1.endpoints import auth, users, subscriptions, alerts, pulse

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
