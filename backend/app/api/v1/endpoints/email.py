"""Email API endpoints for OAuth email connections and subscription scanning.

PRO FEATURE: All email endpoints require Pro subscription.
"""

import secrets
from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUserDep, DbSessionDep
from app.schemas.email import (
    StartOAuthRequest,
    CompleteOAuthRequest,
    ScanEmailsRequest,
    MarkEmailProcessedRequest,
    ConvertToSubscriptionRequest,
    OAuthUrlResponse,
    EmailConnectionResponse,
    EmailConnectionListResponse,
    ScannedEmailResponse,
    ScannedEmailListResponse,
    ScanResultResponse,
    SupportedProvidersResponse,
    KnownSenderResponse,
    KnownSendersListResponse,
)
from app.schemas.subscription import SubscriptionResponse
from app.services.email_connection_service import (
    EmailConnectionService,
    EmailConnectionError,
)
from app.services.email.factory import get_supported_providers
from app.services.email.parser_service import EmailParserService
from app.services.tier_service import TierService
from app.services.subscription_service import SubscriptionService

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


@router.get("/providers", response_model=SupportedProvidersResponse)
async def list_supported_providers() -> SupportedProvidersResponse:
    """
    List supported email providers.

    Returns list of provider identifiers that can be used for OAuth connection.
    Currently supports: gmail, outlook
    """
    providers = get_supported_providers()
    return SupportedProvidersResponse(providers=providers)


@router.post("/oauth/start", response_model=OAuthUrlResponse)
async def start_oauth_flow(
    request: StartOAuthRequest,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> OAuthUrlResponse:
    """
    Start OAuth flow for email connection.

    PRO FEATURE: Email scanning requires Pro subscription.

    Returns an authorization URL to redirect the user to for OAuth consent.
    The state parameter should be saved and verified on callback.
    """
    # Check tier
    tier_service = TierService(db)
    check = await tier_service.check_can_connect_email(
        current_user.tenant_id,
        current_user.user_id,
    )

    if not check.allowed:
        tier = await tier_service.get_tenant_tier(current_user.tenant_id)
        _raise_pro_required("Email scanning", tier)

    # Generate state token for CSRF protection
    state = secrets.token_urlsafe(32)

    # Start OAuth flow
    service = EmailConnectionService(db)
    try:
        authorization_url = await service.start_oauth_flow(
            tenant_id=current_user.tenant_id,
            user_id=current_user.user_id,
            provider=request.provider,
            redirect_uri=request.redirect_uri,
            state=state,
        )
    except EmailConnectionError as e:
        if e.error_code == "upgrade_required":
            tier = await tier_service.get_tenant_tier(current_user.tenant_id)
            _raise_pro_required("Email scanning", tier)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"message": e.message, "error_code": e.error_code},
        )

    return OAuthUrlResponse(
        authorization_url=authorization_url,
        state=state,
        provider=request.provider,
    )


@router.post("/oauth/complete", response_model=EmailConnectionResponse)
async def complete_oauth_flow(
    request: CompleteOAuthRequest,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> EmailConnectionResponse:
    """
    Complete OAuth flow by exchanging authorization code for tokens.

    PRO FEATURE: Email scanning requires Pro subscription.

    Called after user grants access on the provider's OAuth page.
    The code and redirect_uri must match what was used in the authorization.
    """
    # Check tier
    tier_service = TierService(db)
    check = await tier_service.check_can_connect_email(
        current_user.tenant_id,
        current_user.user_id,
    )

    if not check.allowed:
        tier = await tier_service.get_tenant_tier(current_user.tenant_id)
        _raise_pro_required("Email scanning", tier)

    # Complete OAuth flow
    service = EmailConnectionService(db)
    try:
        connection = await service.complete_oauth_flow(
            tenant_id=current_user.tenant_id,
            user_id=current_user.user_id,
            provider=request.provider,
            code=request.code,
            redirect_uri=request.redirect_uri,
        )
    except EmailConnectionError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"message": e.message, "error_code": e.error_code},
        )

    return _map_connection_to_response(connection)


@router.get("", response_model=EmailConnectionListResponse)
async def list_email_connections(
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> EmailConnectionListResponse:
    """
    List all email connections for the current user.

    Returns connections with their status and last scan information.
    """
    service = EmailConnectionService(db)
    connections = await service.get_connections(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
    )

    return EmailConnectionListResponse(
        connections=[_map_connection_to_response(c) for c in connections],
        count=len(connections),
    )


@router.get("/{connection_id}", response_model=EmailConnectionResponse)
async def get_email_connection(
    connection_id: UUID,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> EmailConnectionResponse:
    """
    Get a specific email connection by ID.

    Returns connection details including status and scan history.
    """
    service = EmailConnectionService(db)
    connection = await service.get_connection(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        connection_id=connection_id,
    )

    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Email connection not found",
        )

    return _map_connection_to_response(connection)


@router.post("/{connection_id}/scan", response_model=ScanResultResponse)
async def scan_emails(
    connection_id: UUID,
    request: ScanEmailsRequest,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> ScanResultResponse:
    """
    Scan emails for subscription-related content.

    PRO FEATURE: Email scanning requires Pro subscription.

    Searches inbox, all mail, spam, and promotions for:
    - Subscription confirmations
    - Payment receipts
    - Billing reminders
    - Price change notices
    - Trial ending warnings

    Returns detected subscriptions with confidence scores.
    """
    # Check tier
    tier_service = TierService(db)
    check = await tier_service.check_can_connect_email(
        current_user.tenant_id,
        current_user.user_id,
    )

    if not check.allowed:
        tier = await tier_service.get_tenant_tier(current_user.tenant_id)
        _raise_pro_required("Email scanning", tier)

    service = EmailConnectionService(db)

    # Get connection
    connection = await service.get_connection(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        connection_id=connection_id,
    )

    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Email connection not found",
        )

    # Scan emails
    try:
        scanned_emails = await service.scan_emails(
            connection=connection,
            max_emails=request.max_emails,
        )
    except EmailConnectionError as e:
        if e.error_code == "requires_reauth":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={
                    "message": "Email connection requires re-authentication",
                    "error_code": "requires_reauth",
                    "connection_id": str(connection_id),
                },
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"message": e.message, "error_code": e.error_code},
        )

    # Get updated connection (to check if more emails available)
    updated_connection = await service.get_connection(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        connection_id=connection_id,
    )

    return ScanResultResponse(
        connection_id=connection_id,
        emails_scanned=len(scanned_emails),
        subscriptions_detected=sum(1 for e in scanned_emails if e.confidence_score >= 0.5),
        has_more=bool(updated_connection and updated_connection.scan_cursor),
    )


@router.get("/{connection_id}/scanned", response_model=ScannedEmailListResponse)
async def list_scanned_emails(
    connection_id: UUID,
    current_user: CurrentUserDep,
    db: DbSessionDep,
    unprocessed_only: bool = False,
    min_confidence: float = 0.5,
    limit: int = 100,
) -> ScannedEmailListResponse:
    """
    List scanned emails with detected subscriptions.

    Returns emails that have been scanned and parsed for subscription data.
    Filter by:
    - unprocessed_only: Only show emails not yet converted to subscriptions
    - min_confidence: Minimum confidence score (0.0-1.0)
    - limit: Maximum results to return
    """
    service = EmailConnectionService(db)

    # Verify connection exists and belongs to user
    connection = await service.get_connection(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        connection_id=connection_id,
    )

    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Email connection not found",
        )

    emails = await service.get_scanned_emails(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        connection_id=connection_id,
        unprocessed_only=unprocessed_only,
        min_confidence=min_confidence,
        limit=limit,
    )

    return ScannedEmailListResponse(
        emails=[_map_scanned_email_to_response(e) for e in emails],
        count=len(emails),
        has_more=len(emails) == limit,
    )


@router.post(
    "/{connection_id}/scanned/{scanned_email_id}/process",
    response_model=ScannedEmailResponse,
)
async def mark_email_processed(
    connection_id: UUID,
    scanned_email_id: UUID,
    request: MarkEmailProcessedRequest,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> ScannedEmailResponse:
    """
    Mark a scanned email as processed.

    Call this after creating a subscription from the detected email data.
    Optionally link the created subscription to the email.
    """
    service = EmailConnectionService(db)

    # Verify connection exists and belongs to user
    connection = await service.get_connection(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        connection_id=connection_id,
    )

    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Email connection not found",
        )

    email = await service.mark_email_processed(
        tenant_id=current_user.tenant_id,
        scanned_email_id=scanned_email_id,
        subscription_id=request.subscription_id,
    )

    if not email:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scanned email not found",
        )

    return _map_scanned_email_to_response(email)


@router.post(
    "/{connection_id}/scanned/{scanned_email_id}/convert",
    response_model=SubscriptionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def convert_email_to_subscription(
    connection_id: UUID,
    scanned_email_id: UUID,
    request: ConvertToSubscriptionRequest,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> SubscriptionResponse:
    """
    Convert a scanned email to a subscription.

    Creates a new subscription from the detected email data and marks
    the email as processed. Optional overrides can be provided for
    name, amount, billing cycle, etc.

    Returns the created subscription.
    """
    from datetime import date, timezone
    from app.schemas.subscription import SubscriptionCreate

    email_service = EmailConnectionService(db)

    # Verify connection exists and belongs to user
    connection = await email_service.get_connection(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        connection_id=connection_id,
    )

    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Email connection not found",
        )

    # Get the scanned email
    scanned_emails = await email_service.get_scanned_emails(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        connection_id=connection_id,
        unprocessed_only=False,
        min_confidence=0.0,
        limit=1000,
    )

    # Find the specific email
    scanned_email = next(
        (e for e in scanned_emails if e.id == scanned_email_id),
        None,
    )

    if not scanned_email:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scanned email not found",
        )

    if scanned_email.is_subscription_created:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Subscription already created from this email",
        )

    # Build subscription from email data + overrides
    name = request.name or scanned_email.merchant_name
    if not name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Subscription name required (detected merchant_name was empty)",
        )

    amount = request.amount
    if amount is None and scanned_email.detected_amount:
        amount = float(scanned_email.detected_amount)
    if amount is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Subscription amount required (no amount detected from email)",
        )

    billing_cycle = request.billing_cycle or scanned_email.billing_cycle
    if billing_cycle is None:
        billing_cycle = "monthly"  # Default

    next_billing_date = request.next_billing_date
    if next_billing_date is None:
        if scanned_email.next_billing_date:
            next_billing_date = scanned_email.next_billing_date
        else:
            # Default to one cycle from now
            from datetime import timedelta
            today = date.today()
            if billing_cycle == "weekly":
                next_billing_date = today + timedelta(weeks=1)
            elif billing_cycle == "monthly":
                next_billing_date = today + timedelta(days=30)
            elif billing_cycle == "quarterly":
                next_billing_date = today + timedelta(days=90)
            else:  # yearly
                next_billing_date = today + timedelta(days=365)

    # Create subscription
    subscription_service = SubscriptionService(db)

    subscription_create = SubscriptionCreate(
        name=name,
        amount=amount,
        billing_cycle=billing_cycle,  # type: ignore[arg-type]
        next_billing_date=next_billing_date if isinstance(next_billing_date, date) else next_billing_date.date(),
        color=request.color,
        description=request.description,
        source="gmail",  # Source is from email
    )

    subscription = await subscription_service.create(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        request=subscription_create,
    )

    # Mark email as processed
    await email_service.mark_email_processed(
        tenant_id=current_user.tenant_id,
        scanned_email_id=scanned_email_id,
        subscription_id=subscription.id,
    )

    return SubscriptionResponse.model_validate(subscription)


@router.delete("/{connection_id}", status_code=status.HTTP_204_NO_CONTENT)
async def disconnect_email(
    connection_id: UUID,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> None:
    """
    Disconnect (soft delete) an email connection.

    Revokes OAuth access token and removes the connection.
    Scanned emails are retained for historical reference.
    """
    service = EmailConnectionService(db)

    try:
        await service.disconnect(
            tenant_id=current_user.tenant_id,
            user_id=current_user.user_id,
            connection_id=connection_id,
        )
    except EmailConnectionError as e:
        if e.error_code == "not_found":
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Email connection not found",
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"message": e.message, "error_code": e.error_code},
        )


@router.get("/known-senders/all", response_model=KnownSendersListResponse)
async def list_known_senders() -> KnownSendersListResponse:
    """
    List all known subscription senders.

    Returns database of known subscription services used for
    automatic merchant detection during email parsing.
    """
    parser_service = EmailParserService()
    senders = parser_service.get_all_known_senders()

    return KnownSendersListResponse(
        senders=[
            KnownSenderResponse(
                domain=s.domain,
                name=s.name,
                category=s.category,
                logo_url=s.logo_url,
            )
            for s in senders
        ],
        count=len(senders),
    )


def _map_connection_to_response(connection) -> EmailConnectionResponse:
    """Map EmailConnection model to response schema."""
    # Handle both Literal type and string
    provider = connection.provider
    if provider not in ("gmail", "outlook", "yahoo"):
        provider = "gmail"  # Default fallback

    status_value = connection.status
    if status_value not in ("pending", "connected", "error", "disconnected", "requires_reauth"):
        status_value = "connected"

    return EmailConnectionResponse(
        id=connection.id,
        provider=provider,  # type: ignore[arg-type]
        email_address=connection.email_address,
        status=status_value,  # type: ignore[arg-type]
        error_message=connection.error_message,
        last_scan_at=connection.last_scan_at,
        last_successful_scan_at=connection.last_successful_scan_at,
        scan_depth_days=connection.scan_depth_days,
        created_at=connection.created_at,
        updated_at=connection.updated_at,
    )


def _map_scanned_email_to_response(email) -> ScannedEmailResponse:
    """Map ScannedEmail model to response schema."""
    # Handle email type
    email_type = email.email_type
    valid_types = (
        "subscription_confirmation",
        "receipt",
        "billing_reminder",
        "price_change",
        "trial_ending",
        "payment_failed",
        "cancellation",
        "renewal_notice",
        "other",
    )
    if email_type not in valid_types:
        email_type = "other"

    # Handle billing cycle
    billing_cycle = email.billing_cycle
    if billing_cycle and billing_cycle not in ("weekly", "monthly", "quarterly", "yearly"):
        billing_cycle = None

    return ScannedEmailResponse(
        id=email.id,
        connection_id=email.connection_id,
        provider_message_id=email.provider_message_id,
        from_address=email.from_address,
        from_name=email.from_name,
        subject=email.subject,
        received_at=email.received_at,
        email_type=email_type,  # type: ignore[arg-type]
        confidence_score=float(email.confidence_score),
        merchant_name=email.merchant_name,
        detected_amount=float(email.detected_amount) if email.detected_amount else None,
        currency=email.currency,
        billing_cycle=billing_cycle,  # type: ignore[arg-type]
        next_billing_date=email.next_billing_date,
        is_processed=email.is_processed,
        is_subscription_created=email.is_subscription_created,
        subscription_id=email.subscription_id,
    )
