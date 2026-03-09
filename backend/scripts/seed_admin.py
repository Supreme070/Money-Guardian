"""Seed the first super_admin user.

Usage:
    python -m scripts.seed_admin --email admin@moneyguardian.co --password <password> --name "Admin User"

Run from the backend/ directory.
"""

import argparse
import asyncio
import sys
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.core.security import get_password_hash
from app.models.admin_user import AdminUser


async def seed_admin(email: str, password: str, full_name: str) -> None:
    engine = create_async_engine(str(settings.database_url))
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as db:
        # Check if email already exists
        result = await db.execute(
            select(AdminUser).where(AdminUser.email == email)
        )
        if result.scalar_one_or_none():
            print(f"Admin user with email {email} already exists.")
            return

        admin = AdminUser(
            id=uuid4(),
            email=email,
            hashed_password=get_password_hash(password),
            full_name=full_name,
            role="super_admin",
            is_active=True,
            mfa_enabled=False,
        )
        db.add(admin)
        await db.commit()
        print(f"Created super_admin: {email} (id={admin.id})")

    await engine.dispose()


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed first admin user")
    parser.add_argument("--email", required=True, help="Admin email")
    parser.add_argument("--password", required=True, help="Admin password (min 12 chars)")
    parser.add_argument("--name", required=True, help="Full name")
    args = parser.parse_args()

    if not args.email.endswith("@moneyguardian.co"):
        print("Error: Admin accounts must use @moneyguardian.co email addresses.")
        sys.exit(1)

    if len(args.password) < 12:
        print("Error: Password must be at least 12 characters.")
        sys.exit(1)

    asyncio.run(seed_admin(args.email, args.password, args.name))


if __name__ == "__main__":
    main()
