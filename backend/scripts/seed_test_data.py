"""
Seed script for Money Guardian test data.
Run: python scripts/seed_test_data.py
"""

import asyncio
import sys
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from uuid import uuid4

# Add parent directory to path
sys.path.insert(0, str(__file__).rsplit("/", 2)[0])

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
import bcrypt

from app.core.config import settings
from app.models.tenant import Tenant


def hash_password(password: str) -> str:
    """Hash password using bcrypt directly."""
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')


from app.models.user import User
from app.models.subscription import Subscription
from app.models.alert import Alert


async def seed_data():
    """Seed the database with test data."""

    engine = create_async_engine(settings.async_database_url, echo=True)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        # Create tenant
        tenant_id = uuid4()
        tenant = Tenant(
            id=tenant_id,
            name="Test Tenant",
            tier="free",
            status="active",
        )
        session.add(tenant)

        # Create user
        user_id = uuid4()
        user = User(
            id=user_id,
            tenant_id=tenant_id,
            email="test@moneyguardian.co",
            hashed_password=hash_password("Test123!"),
            full_name="Test User",
            is_active=True,
            is_verified=True,
        )
        session.add(user)

        # Create subscriptions
        now = datetime.now(timezone.utc)
        today = now.date()
        subscriptions_data = [
            {
                "name": "Netflix",
                "amount": Decimal("15.99"),
                "billing_cycle": "monthly",
                "next_billing_date": today + timedelta(days=3),
                "color": "#E50914",
                "ai_flag": "none",
            },
            {
                "name": "Spotify",
                "amount": Decimal("10.99"),
                "billing_cycle": "monthly",
                "next_billing_date": today + timedelta(days=7),
                "color": "#1DB954",
                "ai_flag": "none",
            },
            {
                "name": "Adobe Creative Cloud",
                "amount": Decimal("54.99"),
                "billing_cycle": "monthly",
                "next_billing_date": today + timedelta(days=2),
                "color": "#FF0000",
                "ai_flag": "price_increase",
                "ai_flag_reason": "Price increased from $52.99 last month",
                "previous_amount": Decimal("52.99"),
            },
            {
                "name": "Gym Membership",
                "amount": Decimal("29.99"),
                "billing_cycle": "monthly",
                "next_billing_date": today + timedelta(days=15),
                "color": "#FF6B00",
                "ai_flag": "unused",
                "ai_flag_reason": "No usage detected in 45 days",
                "last_usage_detected": datetime.now() - timedelta(days=45),  # naive datetime
            },
            {
                "name": "Disney+",
                "amount": Decimal("7.99"),
                "billing_cycle": "monthly",
                "next_billing_date": today + timedelta(days=5),
                "color": "#113CCF",
                "ai_flag": "trial_ending",
                "ai_flag_reason": "Free trial ends in 5 days",
                "trial_end_date": today + timedelta(days=5),  # date type
            },
            {
                "name": "iCloud Storage",
                "amount": Decimal("2.99"),
                "billing_cycle": "monthly",
                "next_billing_date": today + timedelta(days=20),
                "color": "#007AFF",
                "ai_flag": "none",
            },
            {
                "name": "YouTube Premium",
                "amount": Decimal("13.99"),
                "billing_cycle": "monthly",
                "next_billing_date": today + timedelta(days=12),
                "color": "#FF0000",
                "ai_flag": "duplicate",
                "ai_flag_reason": "Similar to Spotify - both are music streaming",
            },
        ]

        for sub_data in subscriptions_data:
            sub = Subscription(
                id=uuid4(),
                tenant_id=tenant_id,
                user_id=user_id,
                name=sub_data["name"],
                amount=sub_data["amount"],
                currency="USD",
                billing_cycle=sub_data["billing_cycle"],
                next_billing_date=sub_data["next_billing_date"],
                is_active=True,
                is_paused=False,
                ai_flag=sub_data["ai_flag"],
                ai_flag_reason=sub_data.get("ai_flag_reason"),
                previous_amount=sub_data.get("previous_amount"),
                last_usage_detected=sub_data.get("last_usage_detected"),
                trial_end_date=sub_data.get("trial_end_date"),
                source="manual",
                color=sub_data.get("color"),
            )
            session.add(sub)

        # Create alerts
        alerts_data = [
            {
                "alert_type": "overdraft_warning",
                "severity": "critical",
                "title": "Overdraft Risk",
                "message": "Adobe CC charge of $54.99 on {} may overdraft your account".format(
                    (today + timedelta(days=2)).strftime("%b %d")
                ),
                "amount": Decimal("54.99"),
                "alert_date": now + timedelta(days=2),
                "is_read": False,
            },
            {
                "alert_type": "trial_ending",
                "severity": "warning",
                "title": "Trial Ending Soon",
                "message": "Your Disney+ trial ends in 5 days. You will be charged $7.99",
                "amount": Decimal("7.99"),
                "alert_date": now + timedelta(days=5),
                "is_read": False,
            },
            {
                "alert_type": "upcoming_charge",
                "severity": "info",
                "title": "Upcoming Charge",
                "message": "Netflix subscription renews in 3 days",
                "amount": Decimal("15.99"),
                "alert_date": now + timedelta(days=3),
                "is_read": False,
            },
            {
                "alert_type": "price_increase",
                "severity": "warning",
                "title": "Price Increase",
                "message": "Adobe CC increased from $52.99 to $54.99",
                "amount": Decimal("54.99"),
                "alert_date": now,
                "is_read": True,
            },
            {
                "alert_type": "unused_subscription",
                "severity": "info",
                "title": "Unused Subscription",
                "message": "You haven't used Gym Membership in 45 days. Consider canceling?",
                "amount": Decimal("29.99"),
                "alert_date": now - timedelta(days=3),
                "is_read": True,
            },
        ]

        for alert_data in alerts_data:
            alert = Alert(
                id=uuid4(),
                tenant_id=tenant_id,
                user_id=user_id,
                alert_type=alert_data["alert_type"],
                severity=alert_data["severity"],
                title=alert_data["title"],
                message=alert_data["message"],
                amount=alert_data.get("amount"),
                alert_date=alert_data.get("alert_date"),
                is_read=alert_data["is_read"],
                is_dismissed=False,
                is_actioned=False,
            )
            session.add(alert)

        await session.commit()

        print("\n" + "="*50)
        print("TEST DATA SEEDED SUCCESSFULLY")
        print("="*50)
        print(f"\nTenant ID: {tenant_id}")
        print(f"User ID: {user_id}")
        print(f"Email: test@moneyguardian.co")
        print(f"Password: Test123!")
        print(f"\nSubscriptions: {len(subscriptions_data)}")
        print(f"Alerts: {len(alerts_data)}")
        print("="*50 + "\n")


if __name__ == "__main__":
    asyncio.run(seed_data())
