"""Banking API endpoints for Plaid/Mono/Stitch integrations.

PRO FEATURE: All banking endpoints require Pro subscription.
"""

from typing import Literal
from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUserDep, DbSessionDep
from app.schemas.banking import (
    CreateLinkTokenRequest,
    ExchangeTokenRequest,
    UpdateAccountRequest,
    ConvertRecurringToSubscriptionRequest,
    LinkTokenResponse,
    BankConnectionResponse,
    BankConnectionListResponse,
    BankAccountResponse,
    SyncTransactionsResponse,
    RecurringTransactionsListResponse,
    RecurringTransactionResponse,
)
from app.schemas.subscription import SubscriptionResponse
from app.services.subscription_service import SubscriptionService
from app.services.bank_connection_service import (
    BankConnectionService,
    BankConnectionNotFoundError,
)
from app.services.tier_service import TierService

router = APIRouter()


def _raise_pro_required(feature: str, tier: str) -> None:
    """Raise 402 Payment Required for Pro features."""
    raise HTTPException(
        status_code=status.HTTP_402_PAYMENT_REQUIRED,
        detail={
            "message": f"{feature} requires Pro subscription",
            "upgrade_required": True,
            "feature": feature,
            "current_tier": tier,
        },
    )


@router.post("/link-token", response_model=LinkTokenResponse)
async def create_link_token(
    request: CreateLinkTokenRequest,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> LinkTokenResponse:
    """
    Create a link token for initiating Plaid/Mono/Stitch Link.

    PRO FEATURE: Bank connection requires Pro subscription.

    Returns a link token that should be passed to the Link SDK on the client.
    """
    # Check tier
    tier_service = TierService(db)
    check = await tier_service.check_can_connect_bank(
        current_user.tenant_id,
        current_user.user_id,
    )

    if not check.allowed:
        tier = await tier_service.get_tenant_tier(current_user.tenant_id)
        _raise_pro_required("Bank connection", tier)

    # Create link token
    service = BankConnectionService(db)
    result = await service.create_link_token(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        provider=request.provider,
    )

    return LinkTokenResponse(
        link_token=result["link_token"],
        expiration=result["expiration"],
        provider=result["provider"],
    )


@router.post("/exchange", response_model=BankConnectionResponse)
async def exchange_public_token(
    request: ExchangeTokenRequest,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> BankConnectionResponse:
    """
    Exchange public token for access token and create connection.

    PRO FEATURE: Bank connection requires Pro subscription.

    After successful Link completion, exchange the public token to:
    1. Get an access token (stored encrypted)
    2. Create bank connection record
    3. Create bank account records

    Returns the created connection with all accounts.
    """
    # Check tier
    tier_service = TierService(db)
    check = await tier_service.check_can_connect_bank(
        current_user.tenant_id,
        current_user.user_id,
    )

    if not check.allowed:
        tier = await tier_service.get_tenant_tier(current_user.tenant_id)
        _raise_pro_required("Bank connection", tier)

    # Exchange token and save
    service = BankConnectionService(db)
    connection = await service.exchange_and_save(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        public_token=request.public_token,
        provider=request.provider,
    )

    return _map_connection_to_response(connection)


@router.get("", response_model=BankConnectionListResponse)
async def list_bank_connections(
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> BankConnectionListResponse:
    """
    List all bank connections for the current user.

    Returns connections with their accounts and total combined balance.
    """
    service = BankConnectionService(db)
    connections = await service.list_connections(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
    )

    total_balance = await service.get_total_balance(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
    )

    account_count = sum(len(c.accounts) for c in connections)

    return BankConnectionListResponse(
        connections=[_map_connection_to_response(c) for c in connections],
        total_balance=float(total_balance),
        account_count=account_count,
    )


@router.get("/{connection_id}", response_model=BankConnectionResponse)
async def get_bank_connection(
    connection_id: UUID,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> BankConnectionResponse:
    """
    Get a specific bank connection by ID.

    Returns connection with all its accounts.
    """
    service = BankConnectionService(db)

    try:
        connection = await service.get_connection(
            tenant_id=current_user.tenant_id,
            connection_id=connection_id,
        )
    except BankConnectionNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bank connection not found",
        )

    return _map_connection_to_response(connection)


@router.post("/{connection_id}/sync", response_model=SyncTransactionsResponse)
async def sync_transactions(
    connection_id: UUID,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> SyncTransactionsResponse:
    """
    Manually trigger transaction sync for a connection.

    Uses incremental sync to fetch only new/modified transactions.
    Returns the count of new transactions added.
    """
    service = BankConnectionService(db)

    try:
        new_count = await service.sync_transactions(
            tenant_id=current_user.tenant_id,
            user_id=current_user.user_id,
            connection_id=connection_id,
        )
    except BankConnectionNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bank connection not found",
        )

    return SyncTransactionsResponse(
        new_transactions=new_count,
        connection_id=connection_id,
    )


@router.post("/{connection_id}/sync-balances", response_model=BankConnectionResponse)
async def sync_balances(
    connection_id: UUID,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> BankConnectionResponse:
    """
    Sync account balances for a connection.

    Fetches latest balances from the provider and updates local records.
    """
    service = BankConnectionService(db)

    try:
        await service.sync_balances(
            tenant_id=current_user.tenant_id,
            connection_id=connection_id,
        )
        connection = await service.get_connection(
            tenant_id=current_user.tenant_id,
            connection_id=connection_id,
        )
    except BankConnectionNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bank connection not found",
        )

    return _map_connection_to_response(connection)


@router.get(
    "/{connection_id}/recurring",
    response_model=RecurringTransactionsListResponse,
)
async def get_recurring_transactions(
    connection_id: UUID,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> RecurringTransactionsListResponse:
    """
    Get detected recurring transactions for a connection.

    Returns transactions that the provider has identified as recurring,
    useful for automatic subscription detection.
    """
    service = BankConnectionService(db)

    try:
        recurring = await service.get_recurring_subscriptions(
            tenant_id=current_user.tenant_id,
            user_id=current_user.user_id,
            connection_id=connection_id,
        )
    except BankConnectionNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bank connection not found",
        )

    return RecurringTransactionsListResponse(
        recurring_transactions=[
            RecurringTransactionResponse(
                stream_id=r.stream_id,
                account_id=r.account_id,
                description=r.description,
                merchant_name=r.merchant_name,
                average_amount=float(r.average_amount),
                currency=r.currency,
                frequency=r.frequency,
                last_date=r.last_date.isoformat(),
                next_expected_date=r.next_expected_date.isoformat() if r.next_expected_date else None,
                is_active=r.is_active,
            )
            for r in recurring
        ],
        count=len(recurring),
    )


@router.delete("/{connection_id}", status_code=status.HTTP_204_NO_CONTENT)
async def disconnect_bank(
    connection_id: UUID,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> None:
    """
    Disconnect (soft delete) a bank connection.

    Removes the connection from the provider and marks it as deleted locally.
    """
    service = BankConnectionService(db)

    try:
        await service.disconnect(
            tenant_id=current_user.tenant_id,
            connection_id=connection_id,
        )
    except BankConnectionNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bank connection not found",
        )


@router.post(
    "/{connection_id}/recurring/{stream_id}/convert",
    response_model=SubscriptionResponse,
)
async def convert_recurring_to_subscription(
    connection_id: UUID,
    stream_id: str,
    request: ConvertRecurringToSubscriptionRequest,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> SubscriptionResponse:
    """
    Convert a recurring bank transaction to a subscription.

    Creates a new subscription from a detected recurring transaction.
    The stream_id must match an existing recurring transaction.
    """
    bank_service = BankConnectionService(db)

    # Get the recurring transaction
    try:
        recurring_list = await bank_service.get_recurring_subscriptions(
            tenant_id=current_user.tenant_id,
            user_id=current_user.user_id,
            connection_id=connection_id,
        )
    except BankConnectionNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bank connection not found",
        )

    # Find the specific recurring transaction
    recurring = next(
        (r for r in recurring_list if r.stream_id == stream_id),
        None,
    )

    if recurring is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recurring transaction not found",
        )

    # Map frequency to billing cycle
    frequency_map = {
        "WEEKLY": "weekly",
        "BIWEEKLY": "monthly",  # Approximate to monthly
        "SEMI_MONTHLY": "monthly",
        "MONTHLY": "monthly",
        "ANNUALLY": "yearly",
        "QUARTERLY": "quarterly",
    }
    billing_cycle = frequency_map.get(recurring.frequency, "monthly")

    # Build subscription name with fallbacks
    sub_name = request.name or recurring.merchant_name or recurring.description
    if not sub_name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not determine subscription name from recurring transaction",
        )

    # Determine amount with override
    from decimal import Decimal
    sub_amount = Decimal(str(request.amount)) if request.amount else recurring.average_amount
    if sub_amount is None or sub_amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not determine subscription amount",
        )

    # Determine next billing date
    from datetime import date as date_type, timedelta
    next_date = request.next_billing_date or recurring.next_expected_date
    if next_date is None:
        next_date = date_type.today() + timedelta(days=30)
    # If next_date is a datetime, extract the date portion
    if hasattr(next_date, "date"):
        next_date = next_date.date()

    from app.schemas.subscription import SubscriptionCreate

    subscription_create = SubscriptionCreate(
        name=sub_name,
        amount=sub_amount,
        currency=recurring.currency or "USD",
        billing_cycle=request.billing_cycle or billing_cycle,
        next_billing_date=next_date,
        color=request.color,
        description=request.description or f"Auto-detected from bank: {recurring.description}",
        source="bank",
        bank_transaction_pattern=recurring.stream_id,
    )

    subscription_service = SubscriptionService(db)
    subscription = await subscription_service.create(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        request=subscription_create,
    )

    return SubscriptionResponse.model_validate(subscription)


def _map_subscription_to_response(subscription) -> SubscriptionResponse:
    """Map Subscription model to response schema."""
    return SubscriptionResponse(
        id=subscription.id,
        name=subscription.name,
        amount=float(subscription.amount),
        currency=subscription.currency,
        billing_cycle=subscription.billing_cycle,
        next_billing_date=subscription.next_billing_date,
        color=subscription.color,
        description=subscription.description,
        status=subscription.status,
        source=subscription.source,
        external_id=subscription.external_id,
        logo_url=subscription.logo_url,
        ai_flags=subscription.ai_flags or [],
        waste_score=subscription.waste_score,
        is_paused=subscription.is_paused,
        paused_at=subscription.paused_at,
        cancelled_at=subscription.cancelled_at,
        created_at=subscription.created_at,
        updated_at=subscription.updated_at,
    )


def _map_connection_to_response(connection) -> BankConnectionResponse:
    """Map BankConnection model to response schema."""
    return BankConnectionResponse(
        id=connection.id,
        provider=connection.provider,
        institution_name=connection.institution_name,
        institution_logo=connection.institution_logo,
        status=connection.status,
        error_code=connection.error_code,
        error_message=connection.error_message,
        last_sync_at=connection.last_sync_at,
        created_at=connection.created_at,
        updated_at=connection.updated_at,
        accounts=[
            BankAccountResponse(
                id=acc.id,
                name=acc.name,
                official_name=acc.official_name,
                mask=acc.mask,
                account_type=acc.account_type,
                account_subtype=acc.account_subtype,
                current_balance=float(acc.current_balance) if acc.current_balance else None,
                available_balance=float(acc.available_balance) if acc.available_balance else None,
                limit=float(acc.limit) if acc.limit else None,
                currency=acc.currency,
                is_active=acc.is_active,
                is_primary=acc.is_primary,
                include_in_pulse=acc.include_in_pulse,
                balance_updated_at=acc.balance_updated_at,
            )
            for acc in connection.accounts
        ],
    )
