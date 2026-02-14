"""Subscription service - tenant-scoped operations."""

from decimal import Decimal
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.subscription import Subscription
from app.schemas.subscription import (
    SubscriptionCreate,
    SubscriptionUpdate,
    SubscriptionListResponse,
    SubscriptionResponse,
)


class SubscriptionNotFoundError(Exception):
    """Raised when subscription is not found."""

    pass


class SubscriptionService:
    """
    Subscription service.

    CRITICAL: All methods require tenant_id for isolation.
    Never query subscriptions without tenant filter.
    """

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def create(
        self,
        tenant_id: UUID,
        user_id: UUID,
        request: SubscriptionCreate,
    ) -> Subscription:
        """
        Create a new subscription.

        tenant_id comes from authenticated user's JWT.
        """
        subscription = Subscription(
            tenant_id=tenant_id,
            user_id=user_id,
            name=request.name,
            description=request.description,
            amount=request.amount,
            currency=request.currency,
            billing_cycle=request.billing_cycle,
            next_billing_date=request.next_billing_date,
            start_date=request.start_date,
            trial_end_date=request.trial_end_date,
            color=request.color,
            icon=request.icon,
            logo_url=request.logo_url,
            source=request.source,
            bank_transaction_pattern=request.bank_transaction_pattern,
            ai_flag="none",
        )

        self.db.add(subscription)
        await self.db.commit()
        await self.db.refresh(subscription)

        return subscription

    async def get_by_id(
        self,
        tenant_id: UUID,
        subscription_id: UUID,
    ) -> Subscription:
        """
        Get subscription by ID.

        CRITICAL: Always filters by tenant_id.
        """
        result = await self.db.execute(
            select(Subscription).where(
                Subscription.id == subscription_id,
                Subscription.tenant_id == tenant_id,
                Subscription.deleted_at.is_(None),
            )
        )
        subscription = result.scalar_one_or_none()

        if subscription is None:
            raise SubscriptionNotFoundError(
                f"Subscription {subscription_id} not found"
            )

        return subscription

    async def list(
        self,
        tenant_id: UUID,
        user_id: UUID,
        include_inactive: bool = False,
        include_deleted: bool = False,
    ) -> SubscriptionListResponse:
        """
        List all subscriptions for a user.

        CRITICAL: Always filters by tenant_id.

        Args:
            include_inactive: If True, includes cancelled/inactive subscriptions.
            include_deleted: If True, includes soft-deleted subscriptions (for history).
        """
        query = select(Subscription).where(
            Subscription.tenant_id == tenant_id,
            Subscription.user_id == user_id,
        )

        if not include_deleted:
            query = query.where(Subscription.deleted_at.is_(None))

        if not include_inactive:
            query = query.where(Subscription.is_active == True)

        query = query.order_by(Subscription.next_billing_date)

        result = await self.db.execute(query)
        subscriptions = list(result.scalars().all())

        # Calculate totals
        monthly_total = Decimal("0")
        yearly_total = Decimal("0")
        flagged_count = 0

        for sub in subscriptions:
            if sub.is_active and not sub.is_paused:
                amount = sub.amount
                cycle = sub.billing_cycle

                # Normalize to monthly
                if cycle == "weekly":
                    monthly = amount * Decimal("4.33")
                elif cycle == "monthly":
                    monthly = amount
                elif cycle == "quarterly":
                    monthly = amount / Decimal("3")
                elif cycle == "yearly":
                    monthly = amount / Decimal("12")
                else:
                    monthly = amount

                monthly_total += monthly

            if sub.ai_flag != "none":
                flagged_count += 1

        yearly_total = monthly_total * Decimal("12")

        return SubscriptionListResponse(
            subscriptions=[
                SubscriptionResponse.model_validate(s) for s in subscriptions
            ],
            total_count=len(subscriptions),
            monthly_total=monthly_total.quantize(Decimal("0.01")),
            yearly_total=yearly_total.quantize(Decimal("0.01")),
            flagged_count=flagged_count,
        )

    async def update(
        self,
        tenant_id: UUID,
        subscription_id: UUID,
        request: SubscriptionUpdate,
    ) -> Subscription:
        """
        Update subscription.

        CRITICAL: Always filters by tenant_id.
        """
        subscription = await self.get_by_id(tenant_id, subscription_id)

        # Track price changes for AI detection
        if request.amount is not None and request.amount != subscription.amount:
            subscription.previous_amount = subscription.amount

        # Update only provided fields
        update_data = request.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(subscription, field, value)

        self.db.add(subscription)
        await self.db.commit()
        await self.db.refresh(subscription)

        return subscription

    async def delete(
        self,
        tenant_id: UUID,
        subscription_id: UUID,
    ) -> None:
        """
        Soft delete subscription.

        CRITICAL: Always filters by tenant_id.
        """
        subscription = await self.get_by_id(tenant_id, subscription_id)

        # Soft delete
        from datetime import datetime, timezone
        subscription.deleted_at = datetime.now(timezone.utc)

        self.db.add(subscription)
        await self.db.commit()
