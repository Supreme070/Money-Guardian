"""Tier service for Pro feature gating and limit enforcement."""

from dataclasses import dataclass
from typing import Literal
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.subscription import Subscription
from app.models.bank_connection import BankConnection
from app.models.email_connection import EmailConnection


@dataclass(frozen=True)
class TierLimits:
    """Limits for a subscription tier."""

    max_manual_subscriptions: int
    max_bank_connections: int
    max_email_connections: int
    email_scan_depth_days: int
    can_see_ai_insights: bool
    can_see_price_alerts: bool
    can_export_data: bool


# Tier configurations
_TIER_LIMITS: dict[str, TierLimits] = {
    "free": TierLimits(
        max_manual_subscriptions=5,
        max_bank_connections=0,  # No bank connections on free
        max_email_connections=0,  # No email connections on free
        email_scan_depth_days=0,  # No email scanning on free
        can_see_ai_insights=False,
        can_see_price_alerts=False,
        can_export_data=False,
    ),
    "pro": TierLimits(
        max_manual_subscriptions=-1,  # Unlimited
        max_bank_connections=5,
        max_email_connections=3,
        email_scan_depth_days=1095,  # 3 years
        can_see_ai_insights=True,
        can_see_price_alerts=True,
        can_export_data=True,
    ),
    "enterprise": TierLimits(
        max_manual_subscriptions=-1,  # Unlimited
        max_bank_connections=20,
        max_email_connections=10,
        email_scan_depth_days=1825,  # 5 years
        can_see_ai_insights=True,
        can_see_price_alerts=True,
        can_export_data=True,
    ),
}


@dataclass(frozen=True)
class FeatureCheckResult:
    """Result of a feature access check."""

    allowed: bool
    reason: str | None = None
    upgrade_required: bool = False
    current_count: int | None = None
    limit: int | None = None


class TierService:
    """
    Service for checking and enforcing tier-based feature limits.

    PRO FEATURES:
    - Bank connection
    - Email scanning
    - AI insights
    - Price alerts
    - Data export
    """

    def __init__(self, db: AsyncSession) -> None:
        """Initialize with database session."""
        self.db = db

    async def get_tenant_tier(
        self,
        tenant_id: UUID,
    ) -> Literal["free", "pro", "enterprise"]:
        """
        Get tenant's current subscription tier.

        Args:
            tenant_id: Tenant UUID

        Returns:
            Tier name: "free", "pro", or "enterprise"
        """
        result = await self.db.execute(
            select(Tenant.tier).where(Tenant.id == tenant_id)
        )
        tier = result.scalar_one_or_none()
        if tier not in ("free", "pro", "enterprise"):
            return "free"
        return tier  # type: ignore[return-value]

    def get_limits_for_tier(
        self,
        tier: Literal["free", "pro", "enterprise"],
    ) -> TierLimits:
        """
        Get limits for a subscription tier.

        Args:
            tier: Tier name

        Returns:
            TierLimits dataclass
        """
        return _TIER_LIMITS.get(tier, _TIER_LIMITS["free"])

    async def check_can_connect_bank(
        self,
        tenant_id: UUID,
        user_id: UUID,
    ) -> FeatureCheckResult:
        """
        Check if user can connect a bank account.

        PRO FEATURE: Bank connections require Pro subscription.

        Args:
            tenant_id: Tenant UUID
            user_id: User UUID

        Returns:
            FeatureCheckResult with allowed status and reason
        """
        tier = await self.get_tenant_tier(tenant_id)
        limits = self.get_limits_for_tier(tier)

        if limits.max_bank_connections == 0:
            return FeatureCheckResult(
                allowed=False,
                reason="Bank connection requires Pro subscription",
                upgrade_required=True,
                current_count=0,
                limit=0,
            )

        # Count existing active connections
        result = await self.db.execute(
            select(func.count(BankConnection.id)).where(
                BankConnection.tenant_id == tenant_id,
                BankConnection.user_id == user_id,
                BankConnection.deleted_at.is_(None),
            )
        )
        current_count = result.scalar_one() or 0

        if limits.max_bank_connections != -1 and current_count >= limits.max_bank_connections:
            return FeatureCheckResult(
                allowed=False,
                reason=f"Maximum {limits.max_bank_connections} bank connections allowed on {tier} tier",
                upgrade_required=tier != "enterprise",
                current_count=current_count,
                limit=limits.max_bank_connections,
            )

        return FeatureCheckResult(
            allowed=True,
            current_count=current_count,
            limit=limits.max_bank_connections,
        )

    async def check_can_connect_email(
        self,
        tenant_id: UUID,
        user_id: UUID,
    ) -> FeatureCheckResult:
        """
        Check if user can connect an email account.

        PRO FEATURE: Email scanning requires Pro subscription.

        Args:
            tenant_id: Tenant UUID
            user_id: User UUID

        Returns:
            FeatureCheckResult with allowed status and reason
        """
        tier = await self.get_tenant_tier(tenant_id)
        limits = self.get_limits_for_tier(tier)

        if limits.max_email_connections == 0:
            return FeatureCheckResult(
                allowed=False,
                reason="Email scanning requires Pro subscription",
                upgrade_required=True,
                current_count=0,
                limit=0,
            )

        # Count existing active connections
        result = await self.db.execute(
            select(func.count(EmailConnection.id)).where(
                EmailConnection.tenant_id == tenant_id,
                EmailConnection.user_id == user_id,
                EmailConnection.deleted_at.is_(None),
            )
        )
        current_count = result.scalar_one() or 0

        if limits.max_email_connections != -1 and current_count >= limits.max_email_connections:
            return FeatureCheckResult(
                allowed=False,
                reason=f"Maximum {limits.max_email_connections} email connections allowed on {tier} tier",
                upgrade_required=tier != "enterprise",
                current_count=current_count,
                limit=limits.max_email_connections,
            )

        return FeatureCheckResult(
            allowed=True,
            current_count=current_count,
            limit=limits.max_email_connections,
        )

    async def check_can_add_subscription(
        self,
        tenant_id: UUID,
        user_id: UUID,
    ) -> FeatureCheckResult:
        """
        Check if user can add a manual subscription.

        Free tier has a limit of 5 manual subscriptions.

        Args:
            tenant_id: Tenant UUID
            user_id: User UUID

        Returns:
            FeatureCheckResult with allowed status and reason
        """
        tier = await self.get_tenant_tier(tenant_id)
        limits = self.get_limits_for_tier(tier)

        # Unlimited subscriptions
        if limits.max_manual_subscriptions == -1:
            return FeatureCheckResult(allowed=True, limit=-1)

        # Count manual subscriptions only
        result = await self.db.execute(
            select(func.count(Subscription.id)).where(
                Subscription.tenant_id == tenant_id,
                Subscription.user_id == user_id,
                Subscription.source == "manual",
                Subscription.deleted_at.is_(None),
            )
        )
        current_count = result.scalar_one() or 0

        if current_count >= limits.max_manual_subscriptions:
            return FeatureCheckResult(
                allowed=False,
                reason=f"Maximum {limits.max_manual_subscriptions} subscriptions allowed on free tier",
                upgrade_required=True,
                current_count=current_count,
                limit=limits.max_manual_subscriptions,
            )

        return FeatureCheckResult(
            allowed=True,
            current_count=current_count,
            limit=limits.max_manual_subscriptions,
        )

    async def get_email_scan_depth(
        self,
        tenant_id: UUID,
    ) -> int:
        """
        Get email scan depth in days based on tier.

        Args:
            tenant_id: Tenant UUID

        Returns:
            Number of days to scan back for emails
        """
        tier = await self.get_tenant_tier(tenant_id)
        limits = self.get_limits_for_tier(tier)
        return limits.email_scan_depth_days

    async def can_see_ai_insights(
        self,
        tenant_id: UUID,
    ) -> bool:
        """Check if tenant can see AI insights (unused, duplicate detection)."""
        tier = await self.get_tenant_tier(tenant_id)
        limits = self.get_limits_for_tier(tier)
        return limits.can_see_ai_insights

    async def can_see_price_alerts(
        self,
        tenant_id: UUID,
    ) -> bool:
        """Check if tenant can see price change alerts."""
        tier = await self.get_tenant_tier(tenant_id)
        limits = self.get_limits_for_tier(tier)
        return limits.can_see_price_alerts

    async def require_pro_feature(
        self,
        tenant_id: UUID,
        feature_name: str,
    ) -> FeatureCheckResult:
        """
        Check if a Pro-only feature is available.

        Args:
            tenant_id: Tenant UUID
            feature_name: Human-readable feature name for error message

        Returns:
            FeatureCheckResult with allowed status
        """
        tier = await self.get_tenant_tier(tenant_id)

        if tier in ("pro", "enterprise"):
            return FeatureCheckResult(allowed=True)

        return FeatureCheckResult(
            allowed=False,
            reason=f"{feature_name} requires Pro subscription",
            upgrade_required=True,
        )
