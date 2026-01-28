"""AI Flag Detection Service for subscription analysis.

This service analyzes subscriptions and detects potential issues:
- Unused: Not used in 30+ days (if usage tracking available)
- Duplicate: Similar name or merchant to another subscription
- Price Increase: Amount increased from previous
- Trial Ending: Free trial ending within 7 days
- Forgotten: Added 90+ days ago with no interaction
"""

from datetime import datetime, timedelta
from decimal import Decimal
from typing import Literal
from uuid import UUID

from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.subscription import Subscription


# AI Flag types
AIFlagType = Literal[
    "none",
    "unused",
    "duplicate",
    "price_increase",
    "trial_ending",
    "forgotten",
]


class AIFlagResult:
    """Result of AI flag detection for a subscription."""

    def __init__(
        self,
        subscription_id: UUID,
        flag: AIFlagType,
        reason: str | None = None,
        confidence: float = 1.0,
    ):
        self.subscription_id = subscription_id
        self.flag = flag
        self.reason = reason
        self.confidence = confidence


class AIFlagService:
    """Service for detecting AI flags on subscriptions."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def analyze_all_subscriptions(
        self,
        tenant_id: UUID,
        user_id: UUID,
    ) -> list[AIFlagResult]:
        """
        Analyze all subscriptions for a user and detect flags.

        Returns a list of flag results for subscriptions that have issues.
        """
        # Get all active subscriptions
        query = select(Subscription).where(
            and_(
                Subscription.tenant_id == tenant_id,
                Subscription.user_id == user_id,
                Subscription.is_active == True,
                Subscription.deleted_at.is_(None),
            )
        )
        result = await self.db.execute(query)
        subscriptions = result.scalars().all()

        if not subscriptions:
            return []

        results: list[AIFlagResult] = []

        # Run all detection algorithms
        results.extend(await self._detect_trials_ending(subscriptions))
        results.extend(await self._detect_price_increases(subscriptions))
        results.extend(await self._detect_duplicates(subscriptions))
        results.extend(await self._detect_forgotten(subscriptions))
        results.extend(await self._detect_unused(subscriptions))

        return results

    async def analyze_subscription(
        self,
        tenant_id: UUID,
        user_id: UUID,
        subscription_id: UUID,
    ) -> AIFlagResult | None:
        """Analyze a single subscription and return flag if found."""
        query = select(Subscription).where(
            and_(
                Subscription.tenant_id == tenant_id,
                Subscription.user_id == user_id,
                Subscription.id == subscription_id,
                Subscription.deleted_at.is_(None),
            )
        )
        result = await self.db.execute(query)
        subscription = result.scalar_one_or_none()

        if not subscription:
            return None

        # Get all subscriptions for duplicate detection
        all_query = select(Subscription).where(
            and_(
                Subscription.tenant_id == tenant_id,
                Subscription.user_id == user_id,
                Subscription.is_active == True,
                Subscription.deleted_at.is_(None),
            )
        )
        all_result = await self.db.execute(all_query)
        all_subscriptions = all_result.scalars().all()

        # Run detection on single subscription
        if flag := self._check_trial_ending(subscription):
            return flag
        if flag := self._check_price_increase(subscription):
            return flag
        if flag := self._check_duplicate(subscription, all_subscriptions):
            return flag
        if flag := self._check_forgotten(subscription):
            return flag
        if flag := self._check_unused(subscription):
            return flag

        return AIFlagResult(
            subscription_id=subscription.id,
            flag="none",
        )

    async def apply_flags(
        self,
        tenant_id: UUID,
        user_id: UUID,
    ) -> int:
        """
        Analyze all subscriptions and update their AI flags in database.

        Returns the count of subscriptions that were flagged.
        """
        results = await self.analyze_all_subscriptions(tenant_id, user_id)

        # Get all subscriptions to reset flags
        query = select(Subscription).where(
            and_(
                Subscription.tenant_id == tenant_id,
                Subscription.user_id == user_id,
                Subscription.is_active == True,
                Subscription.deleted_at.is_(None),
            )
        )
        db_result = await self.db.execute(query)
        subscriptions = {s.id: s for s in db_result.scalars().all()}

        # Reset all flags first
        for sub in subscriptions.values():
            sub.ai_flag = "none"
            sub.ai_flag_reason = None

        # Apply new flags
        flagged_count = 0
        for result in results:
            if result.flag != "none" and result.subscription_id in subscriptions:
                sub = subscriptions[result.subscription_id]
                # Only apply if confidence is high enough
                if result.confidence >= 0.7:
                    sub.ai_flag = result.flag
                    sub.ai_flag_reason = result.reason
                    flagged_count += 1

        await self.db.commit()
        return flagged_count

    async def _detect_trials_ending(
        self,
        subscriptions: list[Subscription],
    ) -> list[AIFlagResult]:
        """Detect subscriptions with trials ending soon (within 7 days)."""
        results: list[AIFlagResult] = []
        now = datetime.now().date()
        soon = now + timedelta(days=7)

        for sub in subscriptions:
            if flag := self._check_trial_ending(sub):
                results.append(flag)

        return results

    def _check_trial_ending(self, sub: Subscription) -> AIFlagResult | None:
        """Check if a subscription has a trial ending soon."""
        if not sub.trial_end_date:
            return None

        now = datetime.now().date()
        days_until = (sub.trial_end_date - now).days

        if 0 <= days_until <= 7:
            return AIFlagResult(
                subscription_id=sub.id,
                flag="trial_ending",
                reason=f"Free trial ends in {days_until} day{'s' if days_until != 1 else ''}",
                confidence=1.0,
            )
        return None

    async def _detect_price_increases(
        self,
        subscriptions: list[Subscription],
    ) -> list[AIFlagResult]:
        """Detect subscriptions that had a price increase."""
        results: list[AIFlagResult] = []

        for sub in subscriptions:
            if flag := self._check_price_increase(sub):
                results.append(flag)

        return results

    def _check_price_increase(self, sub: Subscription) -> AIFlagResult | None:
        """Check if a subscription had a price increase."""
        if sub.previous_amount is None:
            return None

        if sub.amount > sub.previous_amount:
            increase = sub.amount - sub.previous_amount
            increase_pct = (increase / sub.previous_amount) * 100

            return AIFlagResult(
                subscription_id=sub.id,
                flag="price_increase",
                reason=f"Price increased by ${float(increase):.2f} ({increase_pct:.0f}%)",
                confidence=1.0,
            )
        return None

    async def _detect_duplicates(
        self,
        subscriptions: list[Subscription],
    ) -> list[AIFlagResult]:
        """Detect potential duplicate subscriptions."""
        results: list[AIFlagResult] = []

        for i, sub in enumerate(subscriptions):
            if flag := self._check_duplicate(sub, subscriptions[i + 1:]):
                results.append(flag)

        return results

    def _check_duplicate(
        self,
        sub: Subscription,
        others: list[Subscription],
    ) -> AIFlagResult | None:
        """Check if a subscription is a duplicate of another."""
        sub_name_lower = sub.name.lower()

        for other in others:
            if other.id == sub.id:
                continue

            other_name_lower = other.name.lower()

            # Check for exact name match
            if sub_name_lower == other_name_lower:
                return AIFlagResult(
                    subscription_id=sub.id,
                    flag="duplicate",
                    reason=f"Duplicate of '{other.name}'",
                    confidence=1.0,
                )

            # Check for similar names (one contains the other)
            if len(sub_name_lower) >= 3 and len(other_name_lower) >= 3:
                if sub_name_lower in other_name_lower or other_name_lower in sub_name_lower:
                    return AIFlagResult(
                        subscription_id=sub.id,
                        flag="duplicate",
                        reason=f"Similar to '{other.name}'",
                        confidence=0.8,
                    )

            # Check for same amount and similar billing cycle
            if sub.amount == other.amount and sub.billing_cycle == other.billing_cycle:
                # Calculate name similarity
                similarity = self._calculate_similarity(sub_name_lower, other_name_lower)
                if similarity > 0.6:
                    return AIFlagResult(
                        subscription_id=sub.id,
                        flag="duplicate",
                        reason=f"May be duplicate of '{other.name}' (same price & cycle)",
                        confidence=0.7,
                    )

        return None

    def _calculate_similarity(self, s1: str, s2: str) -> float:
        """Calculate simple Jaccard similarity between two strings."""
        words1 = set(s1.split())
        words2 = set(s2.split())

        if not words1 or not words2:
            return 0.0

        intersection = len(words1 & words2)
        union = len(words1 | words2)

        return intersection / union if union > 0 else 0.0

    async def _detect_forgotten(
        self,
        subscriptions: list[Subscription],
    ) -> list[AIFlagResult]:
        """Detect forgotten subscriptions (added 90+ days ago, no interaction)."""
        results: list[AIFlagResult] = []

        for sub in subscriptions:
            if flag := self._check_forgotten(sub):
                results.append(flag)

        return results

    def _check_forgotten(self, sub: Subscription) -> AIFlagResult | None:
        """Check if a subscription appears to be forgotten."""
        now = datetime.now()
        days_since_created = (now - sub.created_at).days

        if days_since_created < 90:
            return None

        # Check if there's been any recent interaction (updated_at != created_at)
        days_since_updated = (now - sub.updated_at).days

        if days_since_updated >= 60:
            return AIFlagResult(
                subscription_id=sub.id,
                flag="forgotten",
                reason=f"No activity for {days_since_updated} days",
                confidence=0.8,
            )

        return None

    async def _detect_unused(
        self,
        subscriptions: list[Subscription],
    ) -> list[AIFlagResult]:
        """Detect unused subscriptions (no usage detected in 30+ days)."""
        results: list[AIFlagResult] = []

        for sub in subscriptions:
            if flag := self._check_unused(sub):
                results.append(flag)

        return results

    def _check_unused(self, sub: Subscription) -> AIFlagResult | None:
        """Check if a subscription appears to be unused."""
        if not sub.last_usage_detected:
            return None

        now = datetime.now()
        days_since_usage = (now - sub.last_usage_detected).days

        if days_since_usage >= 30:
            return AIFlagResult(
                subscription_id=sub.id,
                flag="unused",
                reason=f"Not used in {days_since_usage} days",
                confidence=0.9,
            )

        return None


class AIFlagSummary:
    """Summary of AI flags for a user."""

    def __init__(
        self,
        total_subscriptions: int,
        flagged_count: int,
        unused_count: int,
        duplicate_count: int,
        price_increase_count: int,
        trial_ending_count: int,
        forgotten_count: int,
        potential_monthly_savings: Decimal,
    ):
        self.total_subscriptions = total_subscriptions
        self.flagged_count = flagged_count
        self.unused_count = unused_count
        self.duplicate_count = duplicate_count
        self.price_increase_count = price_increase_count
        self.trial_ending_count = trial_ending_count
        self.forgotten_count = forgotten_count
        self.potential_monthly_savings = potential_monthly_savings


async def get_flag_summary(
    db: AsyncSession,
    tenant_id: UUID,
    user_id: UUID,
) -> AIFlagSummary:
    """Get a summary of AI flags for a user."""
    query = select(Subscription).where(
        and_(
            Subscription.tenant_id == tenant_id,
            Subscription.user_id == user_id,
            Subscription.is_active == True,
            Subscription.deleted_at.is_(None),
        )
    )
    result = await db.execute(query)
    subscriptions = result.scalars().all()

    total = len(subscriptions)
    unused_count = 0
    duplicate_count = 0
    price_increase_count = 0
    trial_ending_count = 0
    forgotten_count = 0
    potential_savings = Decimal("0.00")

    for sub in subscriptions:
        if sub.ai_flag == "unused":
            unused_count += 1
            potential_savings += sub.amount
        elif sub.ai_flag == "duplicate":
            duplicate_count += 1
            potential_savings += sub.amount
        elif sub.ai_flag == "price_increase":
            price_increase_count += 1
            if sub.previous_amount:
                potential_savings += sub.amount - sub.previous_amount
        elif sub.ai_flag == "trial_ending":
            trial_ending_count += 1
        elif sub.ai_flag == "forgotten":
            forgotten_count += 1
            potential_savings += sub.amount

    flagged_count = (
        unused_count + duplicate_count + price_increase_count +
        trial_ending_count + forgotten_count
    )

    return AIFlagSummary(
        total_subscriptions=total,
        flagged_count=flagged_count,
        unused_count=unused_count,
        duplicate_count=duplicate_count,
        price_increase_count=price_increase_count,
        trial_ending_count=trial_ending_count,
        forgotten_count=forgotten_count,
        potential_monthly_savings=potential_savings,
    )
