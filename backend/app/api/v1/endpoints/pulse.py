"""Daily Pulse endpoints - the main home screen data."""

from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

from fastapi import APIRouter
from sqlalchemy import select

from app.api.deps import CurrentUserDep, DbSessionDep
from app.models.alert import Alert
from app.models.subscription import Subscription
from app.models.bank_account import BankAccount
from app.schemas.pulse import PulseResponse, PulseStatus, UpcomingCharge

router = APIRouter()


def calculate_pulse_status(
    safe_to_spend: Decimal,
    upcoming_total: Decimal,
) -> tuple[PulseStatus, str]:
    """
    Calculate pulse status based on safe-to-spend amount.

    Returns status and message.
    """
    if safe_to_spend <= Decimal("0"):
        return "freeze", "Stop non-essential spending"
    elif safe_to_spend < Decimal("50"):
        return "caution", "Be careful with spending"
    elif safe_to_spend < Decimal("100"):
        return "caution", "Watch your spending"
    else:
        return "safe", "You're good to spend"


@router.get("", response_model=PulseResponse)
async def get_pulse(
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> PulseResponse:
    """
    Get daily pulse - main home screen data.

    CRITICAL: All data filtered by tenant_id from JWT.

    Calculates:
    - Current status (SAFE/CAUTION/FREEZE)
    - Safe-to-spend amount
    - Upcoming charges in next 7 days
    - Quick stats
    """
    tenant_id = current_user.tenant_id
    user_id = current_user.user_id
    today = date.today()
    seven_days = today + timedelta(days=7)

    # Get active subscriptions
    subs_result = await db.execute(
        select(Subscription).where(
            Subscription.tenant_id == tenant_id,
            Subscription.user_id == user_id,
            Subscription.is_active == True,
            Subscription.is_paused == False,
            Subscription.deleted_at.is_(None),
        )
    )
    subscriptions = list(subs_result.scalars().all())

    # Get upcoming charges (next 7 days)
    upcoming_charges: list[UpcomingCharge] = []
    upcoming_total = Decimal("0")

    for sub in subscriptions:
        if today <= sub.next_billing_date <= seven_days:
            upcoming_charges.append(
                UpcomingCharge(
                    subscription_id=sub.id,
                    name=sub.name,
                    amount=sub.amount,
                    date=sub.next_billing_date,
                    logo_url=sub.logo_url,
                    color=sub.color,
                    is_warning=False,  # TODO: Check if will cause overdraft
                )
            )
            upcoming_total += sub.amount

    # Sort by date
    upcoming_charges.sort(key=lambda x: x.date)

    # Calculate monthly total
    monthly_total = Decimal("0")
    for sub in subscriptions:
        amount = sub.amount
        cycle = sub.billing_cycle

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

    # Get unread alerts count
    alerts_result = await db.execute(
        select(Alert).where(
            Alert.tenant_id == tenant_id,
            Alert.user_id == user_id,
            Alert.is_read == False,
            Alert.is_dismissed == False,
        )
    )
    unread_alerts = len(list(alerts_result.scalars().all()))

    # Get real balance from connected bank accounts (Pro feature)
    # Falls back to mock balance if no accounts connected
    accounts_result = await db.execute(
        select(BankAccount).where(
            BankAccount.tenant_id == tenant_id,
            BankAccount.user_id == user_id,
            BankAccount.is_active == True,
            BankAccount.include_in_pulse == True,
        )
    )
    bank_accounts = list(accounts_result.scalars().all())

    if bank_accounts:
        # Use real balance from connected accounts
        current_balance = Decimal("0")
        for acc in bank_accounts:
            if acc.account_type in ("checking", "savings"):
                balance = acc.available_balance or acc.current_balance or Decimal("0")
                current_balance += balance
    else:
        # No bank connected - use mock balance for demo
        current_balance = Decimal("500.00")

    has_bank_connected = len(bank_accounts) > 0

    # Calculate safe-to-spend
    safe_to_spend = current_balance - upcoming_total
    if safe_to_spend < Decimal("0"):
        safe_to_spend = Decimal("0")

    # Determine status
    status, status_message = calculate_pulse_status(safe_to_spend, upcoming_total)

    now = datetime.now(timezone.utc)

    return PulseResponse(
        status=status,
        status_message=status_message,
        safe_to_spend=safe_to_spend.quantize(Decimal("0.01")),
        current_balance=current_balance,
        upcoming_charges=upcoming_charges,
        upcoming_total=upcoming_total.quantize(Decimal("0.01")),
        active_subscriptions_count=len(subscriptions),
        monthly_subscription_total=monthly_total.quantize(Decimal("0.01")),
        unread_alerts_count=unread_alerts,
        calculated_at=now,
        next_refresh_at=now + timedelta(hours=1),
    )
