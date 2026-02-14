"""Daily Pulse endpoints - the main home screen data."""

from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

import orjson
from fastapi import APIRouter
from sqlalchemy import func, select

from app.api.deps import CurrentUserDep, DbSessionDep
from app.core.cache import cache_delete, cache_get, cache_set
from app.models.alert import Alert
from app.models.subscription import Subscription
from app.models.bank_account import BankAccount
from app.models.transaction import Transaction
from app.schemas.pulse import PulseBreakdown, PulseResponse, PulseStatus, UpcomingCharge

router = APIRouter()

# Cache TTLs in seconds
_PULSE_CACHE_TTL = 300  # 5 minutes


def calculate_pulse_status(
    safe_to_spend: Decimal,
    has_bank_connected: bool,
) -> tuple[PulseStatus, str]:
    """
    Calculate pulse status based on safe-to-spend amount.

    If no bank is connected, status is based purely on upcoming charge volume.
    Returns (status, message).
    """
    if not has_bank_connected:
        # Without balance data we can't determine overdraft risk.
        # Default to "safe" with a prompt to connect a bank.
        return "safe", "Connect a bank for accurate protection"

    if safe_to_spend <= Decimal("0"):
        return "freeze", "Stop non-essential spending"
    elif safe_to_spend < Decimal("50"):
        return "caution", "Be careful with spending"
    elif safe_to_spend < Decimal("100"):
        return "caution", "Watch your spending"
    else:
        return "safe", "You're good to spend"


def _normalize_to_monthly(amount: Decimal, cycle: str) -> Decimal:
    """Convert any billing cycle amount to its monthly equivalent."""
    if cycle == "weekly":
        return amount * Decimal("4.33")
    elif cycle == "monthly":
        return amount
    elif cycle == "quarterly":
        return amount / Decimal("3")
    elif cycle == "yearly":
        return amount / Decimal("12")
    return amount


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
    - Upcoming charges in next 7 days with overdraft warnings
    - Quick stats
    """
    tenant_id = current_user.tenant_id
    user_id = current_user.user_id

    # ── Cache check ────────────────────────────────────────────────
    cache_key = f"pulse:{tenant_id}:{user_id}"
    cached = await cache_get(cache_key)
    if cached is not None:
        return PulseResponse.model_validate(orjson.loads(cached))

    today = date.today()
    seven_days = today + timedelta(days=7)

    # ── Active subscriptions ─────────────────────────────────────────
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

    # ── Bank balance ─────────────────────────────────────────────────
    accounts_result = await db.execute(
        select(BankAccount).where(
            BankAccount.tenant_id == tenant_id,
            BankAccount.user_id == user_id,
            BankAccount.is_active == True,
            BankAccount.include_in_pulse == True,
        )
    )
    bank_accounts = list(accounts_result.scalars().all())
    has_bank_connected = len(bank_accounts) > 0

    current_balance = Decimal("0")
    if has_bank_connected:
        for acc in bank_accounts:
            if acc.account_type in ("checking", "savings"):
                balance = acc.available_balance or acc.current_balance or Decimal("0")
                current_balance += balance

    # ── Upcoming charges (next 7 days) with overdraft detection ──────
    # Collect raw charges, then walk with a running balance to flag warnings.
    raw_upcoming: list[tuple[Subscription, date]] = []
    upcoming_total = Decimal("0")

    for sub in subscriptions:
        if today <= sub.next_billing_date <= seven_days:
            raw_upcoming.append((sub, sub.next_billing_date))
            upcoming_total += sub.amount

    # Sort chronologically so running-balance walk is accurate
    raw_upcoming.sort(key=lambda pair: pair[1])

    # Walk chronologically: deduct each charge from a running balance.
    # If the running balance goes negative, that charge is a warning.
    running_balance = current_balance
    upcoming_charges: list[UpcomingCharge] = []

    for sub, charge_date in raw_upcoming:
        running_balance -= sub.amount
        # Only flag overdraft warnings when we have real balance data
        is_warning = has_bank_connected and running_balance < Decimal("0")

        upcoming_charges.append(
            UpcomingCharge(
                subscription_id=sub.id,
                name=sub.name,
                amount=sub.amount,
                date=charge_date,
                logo_url=sub.logo_url,
                color=sub.color,
                is_warning=is_warning,
            )
        )

    # ── Monthly total (normalized across all billing cycles) ─────────
    monthly_total = Decimal("0")
    for sub in subscriptions:
        monthly_total += _normalize_to_monthly(sub.amount, sub.billing_cycle)

    # ── Unread alerts count (scalar query, not loading all rows) ─────
    alerts_count_result = await db.execute(
        select(func.count(Alert.id)).where(
            Alert.tenant_id == tenant_id,
            Alert.user_id == user_id,
            Alert.is_read == False,
            Alert.is_dismissed == False,
        )
    )
    unread_alerts: int = alerts_count_result.scalar_one()

    # ── Safe-to-spend ────────────────────────────────────────────────
    if has_bank_connected:
        safe_to_spend = current_balance - upcoming_total
        if safe_to_spend < Decimal("0"):
            safe_to_spend = Decimal("0")
    else:
        # No bank connected — we cannot compute a real safe-to-spend.
        # Return 0 so the UI knows to show the "connect bank" prompt.
        safe_to_spend = Decimal("0")

    # ── Status ───────────────────────────────────────────────────────
    status, status_message = calculate_pulse_status(safe_to_spend, has_bank_connected)

    now = datetime.now(timezone.utc)

    response = PulseResponse(
        status=status,
        status_message=status_message,
        safe_to_spend=safe_to_spend.quantize(Decimal("0.01")),
        current_balance=current_balance.quantize(Decimal("0.01")),
        has_bank_connected=has_bank_connected,
        upcoming_charges=upcoming_charges,
        upcoming_total=upcoming_total.quantize(Decimal("0.01")),
        active_subscriptions_count=len(subscriptions),
        monthly_subscription_total=monthly_total.quantize(Decimal("0.01")),
        unread_alerts_count=unread_alerts,
        calculated_at=now,
        next_refresh_at=now + timedelta(hours=1),
    )

    # ── Cache the result ───────────────────────────────────────────
    await cache_set(cache_key, response.model_dump(mode="json"), _PULSE_CACHE_TTL)

    return response


@router.get("/breakdown", response_model=PulseBreakdown)
async def get_pulse_breakdown(
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> PulseBreakdown:
    """
    Detailed breakdown of pulse calculation.

    Provides 7-day and 30-day forecasts, average daily spend,
    and overdraft risk prediction.
    """
    tenant_id = current_user.tenant_id
    user_id = current_user.user_id
    today = date.today()
    seven_days = today + timedelta(days=7)
    thirty_days = today + timedelta(days=30)

    # ── Bank balance ─────────────────────────────────────────
    accounts_result = await db.execute(
        select(BankAccount).where(
            BankAccount.tenant_id == tenant_id,
            BankAccount.user_id == user_id,
            BankAccount.is_active == True,  # noqa: E712
            BankAccount.include_in_pulse == True,  # noqa: E712
        )
    )
    bank_accounts = list(accounts_result.scalars().all())
    has_bank = len(bank_accounts) > 0

    current_balance = Decimal("0")
    if has_bank:
        for acc in bank_accounts:
            if acc.account_type in ("checking", "savings"):
                balance = acc.available_balance or acc.current_balance or Decimal("0")
                current_balance += balance

    # ── Upcoming charges (7 days and 30 days) ────────────────
    subs_result = await db.execute(
        select(Subscription).where(
            Subscription.tenant_id == tenant_id,
            Subscription.user_id == user_id,
            Subscription.is_active == True,  # noqa: E712
            Subscription.is_paused == False,  # noqa: E712
            Subscription.deleted_at.is_(None),
        )
    )
    subscriptions = list(subs_result.scalars().all())

    charges_7 = Decimal("0")
    charges_30 = Decimal("0")
    for sub in subscriptions:
        if today <= sub.next_billing_date <= seven_days:
            charges_7 += sub.amount
        if today <= sub.next_billing_date <= thirty_days:
            charges_30 += sub.amount

    # ── Average daily spend (last 30 days of debit transactions) ─
    thirty_days_ago = today - timedelta(days=30)
    spend_result = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0)).where(
            Transaction.tenant_id == tenant_id,
            Transaction.user_id == user_id,
            Transaction.transaction_type == "debit",
            Transaction.transaction_date >= thirty_days_ago,
            Transaction.is_pending == False,  # noqa: E712
        )
    )
    total_spend_30: Decimal = spend_result.scalar_one()
    average_daily_spend = total_spend_30 / Decimal("30")

    # ── Predictions ──────────────────────────────────────────
    predicted_7 = current_balance - charges_7 - (average_daily_spend * Decimal("7"))
    predicted_30 = current_balance - charges_30 - (average_daily_spend * Decimal("30"))

    # ── Overdraft risk date ──────────────────────────────────
    # Walk day-by-day subtracting average spend + known charges
    overdraft_risk_date: date | None = None
    if has_bank and average_daily_spend > 0:
        running = current_balance
        for day_offset in range(1, 91):  # Look 90 days ahead
            check_date = today + timedelta(days=day_offset)
            running -= average_daily_spend
            # Subtract any subscriptions due on this date
            for sub in subscriptions:
                if sub.next_billing_date == check_date:
                    running -= sub.amount
            if running < Decimal("0"):
                overdraft_risk_date = check_date
                break

    # ── Status ───────────────────────────────────────────────
    safe_to_spend = max(current_balance - charges_7, Decimal("0"))
    status, status_reason = calculate_pulse_status(safe_to_spend, has_bank)

    return PulseBreakdown(
        current_balance=float(current_balance.quantize(Decimal("0.01"))),
        upcoming_charges_7_days=float(charges_7.quantize(Decimal("0.01"))),
        upcoming_charges_30_days=float(charges_30.quantize(Decimal("0.01"))),
        average_daily_spend=float(average_daily_spend.quantize(Decimal("0.01"))),
        predicted_balance_7_days=float(predicted_7.quantize(Decimal("0.01"))),
        predicted_balance_30_days=float(predicted_30.quantize(Decimal("0.01"))),
        overdraft_risk_date=overdraft_risk_date,
        status=status,
        status_reason=status_reason,
    )


@router.post("/refresh", response_model=PulseResponse)
async def refresh_pulse(
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> PulseResponse:
    """
    Force-refresh the pulse calculation.

    Same as GET /pulse but as POST to signal intent to recalculate.
    Call after adding subscriptions, syncing bank, or other changes.
    """
    # Invalidate the cached pulse so get_pulse recomputes from DB
    cache_key = f"pulse:{current_user.tenant_id}:{current_user.user_id}"
    await cache_delete(cache_key)

    return await get_pulse(current_user=current_user, db=db)
