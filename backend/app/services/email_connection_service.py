"""Email connection service for managing OAuth email connections and scanning."""

from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Literal
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import encrypt_sensitive_data, decrypt_sensitive_data
from app.models.email_connection import EmailConnection
from app.models.scanned_email import ScannedEmail
from app.services.email.base import EmailProvider
from app.services.email.factory import get_email_provider
from app.services.email.parser_service import EmailParserService
from app.services.email.schemas import EmailMessage
from app.services.tier_service import TierService


class EmailConnectionError(Exception):
    """Exception raised for email connection errors."""

    def __init__(
        self,
        message: str,
        error_code: str | None = None,
    ) -> None:
        self.message = message
        self.error_code = error_code
        super().__init__(self.message)


class EmailConnectionService:
    """
    Service for managing email OAuth connections and scanning.

    PRO FEATURE: Email connections require Pro subscription.

    Handles:
    - OAuth flow initiation
    - Token exchange and storage
    - Token refresh
    - Email scanning for subscriptions
    - Scanned email storage
    """

    def __init__(self, db: AsyncSession) -> None:
        """Initialize with database session."""
        self.db = db
        self.tier_service = TierService(db)
        self.parser_service = EmailParserService()

    async def start_oauth_flow(
        self,
        tenant_id: UUID,
        user_id: UUID,
        provider: Literal["gmail", "outlook", "yahoo"],
        redirect_uri: str,
        state: str,
    ) -> str:
        """
        Start OAuth flow for email connection.

        PRO FEATURE: Requires Pro subscription.

        Args:
            tenant_id: Tenant UUID
            user_id: User UUID
            provider: Email provider ("gmail", "outlook", "yahoo")
            redirect_uri: OAuth callback URL
            state: CSRF state token

        Returns:
            Authorization URL to redirect user to

        Raises:
            EmailConnectionError: If tier check fails or provider not supported
        """
        # Check Pro feature access
        check = await self.tier_service.check_can_connect_email(tenant_id, user_id)
        if not check.allowed:
            raise EmailConnectionError(
                message=check.reason or "Email connection not allowed",
                error_code="upgrade_required" if check.upgrade_required else "limit_reached",
            )

        # Get email provider
        email_provider = get_email_provider(provider)

        # Generate authorization URL
        return email_provider.get_authorization_url(
            state=state,
            redirect_uri=redirect_uri,
        )

    async def complete_oauth_flow(
        self,
        tenant_id: UUID,
        user_id: UUID,
        provider: Literal["gmail", "outlook", "yahoo"],
        code: str,
        redirect_uri: str,
    ) -> EmailConnection:
        """
        Complete OAuth flow by exchanging code for tokens.

        Args:
            tenant_id: Tenant UUID
            user_id: User UUID
            provider: Email provider
            code: Authorization code from OAuth callback
            redirect_uri: Must match the one used in authorization

        Returns:
            Created EmailConnection

        Raises:
            EmailConnectionError: If token exchange fails
        """
        # Get email provider
        email_provider = get_email_provider(provider)

        # Exchange code for tokens
        token_response = await email_provider.exchange_code_for_tokens(
            code=code,
            redirect_uri=redirect_uri,
        )

        # Get user profile (email address)
        user_profile = await email_provider.get_user_profile(
            access_token=token_response.access_token,
        )

        # Check if connection already exists for this email
        existing = await self._get_connection_by_email(
            tenant_id=tenant_id,
            user_id=user_id,
            email_address=user_profile.email_address,
        )

        if existing:
            # Update existing connection
            existing.access_token = encrypt_sensitive_data(token_response.access_token)
            if token_response.refresh_token:
                existing.refresh_token = encrypt_sensitive_data(token_response.refresh_token)
            existing.token_expires_at = datetime.now(timezone.utc) + timedelta(
                seconds=token_response.expires_in
            )
            existing.scopes = token_response.scope
            existing.status = "connected"
            existing.error_message = None
            self.db.add(existing)
            await self.db.commit()
            await self.db.refresh(existing)
            return existing

        # Get scan depth based on tier
        scan_depth = await self.tier_service.get_email_scan_depth(tenant_id)

        # Create new connection
        connection = EmailConnection(
            tenant_id=tenant_id,
            user_id=user_id,
            provider=provider,
            email_address=user_profile.email_address,
            access_token=encrypt_sensitive_data(token_response.access_token),
            refresh_token=(
                encrypt_sensitive_data(token_response.refresh_token)
                if token_response.refresh_token
                else None
            ),
            token_expires_at=datetime.now(timezone.utc)
            + timedelta(seconds=token_response.expires_in),
            scopes=token_response.scope,
            status="connected",
            scan_depth_days=scan_depth,
        )

        self.db.add(connection)
        await self.db.commit()
        await self.db.refresh(connection)

        return connection

    async def refresh_token_if_needed(
        self,
        connection: EmailConnection,
    ) -> EmailConnection:
        """
        Refresh access token if expired or about to expire.

        Args:
            connection: Email connection to refresh

        Returns:
            Updated connection

        Raises:
            EmailConnectionError: If refresh fails
        """
        # Check if token needs refresh (5 minutes buffer)
        if connection.token_expires_at:
            buffer = timedelta(minutes=5)
            if connection.token_expires_at > datetime.now(timezone.utc) + buffer:
                return connection

        if not connection.refresh_token:
            connection.status = "requires_reauth"
            connection.error_message = "No refresh token available"
            self.db.add(connection)
            await self.db.commit()
            raise EmailConnectionError(
                message="Token expired and no refresh token available",
                error_code="requires_reauth",
            )

        # Get provider and refresh token
        provider_name = connection.provider
        if provider_name not in ("gmail", "outlook", "yahoo"):
            raise EmailConnectionError(
                message=f"Unknown provider: {provider_name}",
                error_code="invalid_provider",
            )

        email_provider = get_email_provider(provider_name)  # type: ignore[arg-type]
        decrypted_refresh = decrypt_sensitive_data(connection.refresh_token)

        try:
            token_response = await email_provider.refresh_access_token(
                refresh_token=decrypted_refresh,
            )

            # Update connection
            connection.access_token = encrypt_sensitive_data(token_response.access_token)
            if token_response.refresh_token:
                connection.refresh_token = encrypt_sensitive_data(token_response.refresh_token)
            connection.token_expires_at = datetime.now(timezone.utc) + timedelta(
                seconds=token_response.expires_in
            )
            connection.status = "connected"
            connection.error_message = None

            self.db.add(connection)
            await self.db.commit()
            await self.db.refresh(connection)

            return connection

        except Exception as e:
            connection.status = "error"
            connection.error_message = str(e)
            self.db.add(connection)
            await self.db.commit()
            raise EmailConnectionError(
                message=f"Token refresh failed: {e}",
                error_code="refresh_failed",
            )

    async def scan_emails(
        self,
        connection: EmailConnection,
        max_emails: int = 100,
    ) -> list[ScannedEmail]:
        """
        Scan emails for subscription-related content.

        Args:
            connection: Email connection to scan
            max_emails: Maximum emails to scan in this batch

        Returns:
            List of scanned emails with detected subscriptions

        Raises:
            EmailConnectionError: If scan fails
        """
        # Ensure token is fresh
        connection = await self.refresh_token_if_needed(connection)

        # Get provider
        provider_name = connection.provider
        if provider_name not in ("gmail", "outlook", "yahoo"):
            raise EmailConnectionError(
                message=f"Unknown provider: {provider_name}",
                error_code="invalid_provider",
            )

        email_provider = get_email_provider(provider_name)  # type: ignore[arg-type]
        decrypted_token = decrypt_sensitive_data(connection.access_token)

        # Calculate scan date based on depth
        since_date = datetime.now(timezone.utc) - timedelta(days=connection.scan_depth_days)

        # Use oldest scanned email as boundary if available
        if connection.oldest_email_scanned:
            since_date = max(since_date, connection.oldest_email_scanned)

        try:
            # Mark scan start
            connection.last_scan_at = datetime.now(timezone.utc)
            self.db.add(connection)

            # Search for subscription emails
            search_result = await email_provider.search_subscription_emails(
                access_token=decrypted_token,
                since_date=since_date,
                page_token=connection.scan_cursor,
                max_results=max_emails,
            )

            # Parse emails for subscriptions
            scanned_emails: list[ScannedEmail] = []

            for email_msg in search_result.messages:
                # Check if already scanned
                existing = await self._get_scanned_email_by_message_id(
                    tenant_id=connection.tenant_id,
                    provider_message_id=email_msg.message_id,
                )
                if existing:
                    continue

                # Parse email for subscription data
                detection = self.parser_service.parse_email(email_msg)

                if detection:
                    scanned_email = ScannedEmail(
                        tenant_id=connection.tenant_id,
                        user_id=connection.user_id,
                        connection_id=connection.id,
                        provider_message_id=email_msg.message_id,
                        thread_id=email_msg.thread_id,
                        from_address=email_msg.from_address,
                        from_name=email_msg.from_name,
                        subject=email_msg.subject,
                        received_at=email_msg.received_at,
                        email_type=detection.email_type,
                        confidence_score=Decimal(str(detection.confidence_score)),
                        merchant_name=detection.merchant_name,
                        detected_amount=(
                            Decimal(str(detection.amount)) if detection.amount else None
                        ),
                        currency=detection.currency,
                        billing_cycle=detection.billing_cycle,
                        next_billing_date=detection.next_billing_date,
                        is_processed=False,
                        is_subscription_created=False,
                    )

                    self.db.add(scanned_email)
                    scanned_emails.append(scanned_email)

            # Update connection tracking
            connection.scan_cursor = search_result.next_page_token
            connection.last_successful_scan_at = datetime.now(timezone.utc)

            # Update oldest email scanned
            if search_result.messages:
                oldest_in_batch = min(m.received_at for m in search_result.messages)
                if not connection.oldest_email_scanned or oldest_in_batch < connection.oldest_email_scanned:
                    connection.oldest_email_scanned = oldest_in_batch

            self.db.add(connection)
            await self.db.commit()

            # Refresh scanned emails to get IDs
            for email in scanned_emails:
                await self.db.refresh(email)

            return scanned_emails

        except Exception as e:
            connection.status = "error"
            connection.error_message = str(e)
            self.db.add(connection)
            await self.db.commit()
            raise EmailConnectionError(
                message=f"Email scan failed: {e}",
                error_code="scan_failed",
            )

    async def disconnect(
        self,
        tenant_id: UUID,
        user_id: UUID,
        connection_id: UUID,
    ) -> bool:
        """
        Disconnect an email account.

        Args:
            tenant_id: Tenant UUID
            user_id: User UUID
            connection_id: Connection to disconnect

        Returns:
            True if disconnected

        Raises:
            EmailConnectionError: If connection not found
        """
        connection = await self.get_connection(
            tenant_id=tenant_id,
            user_id=user_id,
            connection_id=connection_id,
        )

        if not connection:
            raise EmailConnectionError(
                message="Email connection not found",
                error_code="not_found",
            )

        # Try to revoke access token
        try:
            provider_name = connection.provider
            if provider_name in ("gmail", "outlook", "yahoo"):
                email_provider = get_email_provider(provider_name)  # type: ignore[arg-type]
                decrypted_token = decrypt_sensitive_data(connection.access_token)
                await email_provider.revoke_access(decrypted_token)
        except Exception:
            # Continue even if revoke fails
            pass

        # Soft delete connection
        connection.deleted_at = datetime.now(timezone.utc)
        connection.status = "disconnected"
        self.db.add(connection)
        await self.db.commit()

        return True

    async def get_connection(
        self,
        tenant_id: UUID,
        user_id: UUID,
        connection_id: UUID,
    ) -> EmailConnection | None:
        """Get a specific email connection."""
        result = await self.db.execute(
            select(EmailConnection).where(
                EmailConnection.id == connection_id,
                EmailConnection.tenant_id == tenant_id,
                EmailConnection.user_id == user_id,
                EmailConnection.deleted_at.is_(None),
            )
        )
        return result.scalar_one_or_none()

    async def get_connections(
        self,
        tenant_id: UUID,
        user_id: UUID,
    ) -> list[EmailConnection]:
        """Get all email connections for user."""
        result = await self.db.execute(
            select(EmailConnection)
            .where(
                EmailConnection.tenant_id == tenant_id,
                EmailConnection.user_id == user_id,
                EmailConnection.deleted_at.is_(None),
            )
            .order_by(EmailConnection.created_at.desc())
        )
        return list(result.scalars().all())

    async def get_scanned_emails(
        self,
        tenant_id: UUID,
        user_id: UUID,
        connection_id: UUID | None = None,
        unprocessed_only: bool = False,
        min_confidence: float = 0.5,
        limit: int = 100,
    ) -> list[ScannedEmail]:
        """
        Get scanned emails with subscription detections.

        Args:
            tenant_id: Tenant UUID
            user_id: User UUID
            connection_id: Optional filter by connection
            unprocessed_only: Only return unprocessed emails
            min_confidence: Minimum confidence score
            limit: Max results to return

        Returns:
            List of scanned emails
        """
        query = (
            select(ScannedEmail)
            .where(
                ScannedEmail.tenant_id == tenant_id,
                ScannedEmail.user_id == user_id,
                ScannedEmail.confidence_score >= Decimal(str(min_confidence)),
            )
            .order_by(ScannedEmail.received_at.desc())
            .limit(limit)
        )

        if connection_id:
            query = query.where(ScannedEmail.connection_id == connection_id)

        if unprocessed_only:
            query = query.where(ScannedEmail.is_processed.is_(False))

        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def mark_email_processed(
        self,
        tenant_id: UUID,
        scanned_email_id: UUID,
        subscription_id: UUID | None = None,
    ) -> ScannedEmail | None:
        """
        Mark a scanned email as processed.

        Args:
            tenant_id: Tenant UUID
            scanned_email_id: Scanned email to mark
            subscription_id: Optional linked subscription

        Returns:
            Updated scanned email or None
        """
        result = await self.db.execute(
            select(ScannedEmail).where(
                ScannedEmail.id == scanned_email_id,
                ScannedEmail.tenant_id == tenant_id,
            )
        )
        email = result.scalar_one_or_none()

        if email:
            email.is_processed = True
            if subscription_id:
                email.subscription_id = subscription_id
                email.is_subscription_created = True
            self.db.add(email)
            await self.db.commit()
            await self.db.refresh(email)

        return email

    async def _get_connection_by_email(
        self,
        tenant_id: UUID,
        user_id: UUID,
        email_address: str,
    ) -> EmailConnection | None:
        """Get connection by email address."""
        result = await self.db.execute(
            select(EmailConnection).where(
                EmailConnection.tenant_id == tenant_id,
                EmailConnection.user_id == user_id,
                EmailConnection.email_address == email_address,
                EmailConnection.deleted_at.is_(None),
            )
        )
        return result.scalar_one_or_none()

    async def _get_scanned_email_by_message_id(
        self,
        tenant_id: UUID,
        provider_message_id: str,
    ) -> ScannedEmail | None:
        """Get scanned email by provider message ID."""
        result = await self.db.execute(
            select(ScannedEmail).where(
                ScannedEmail.tenant_id == tenant_id,
                ScannedEmail.provider_message_id == provider_message_id,
            )
        )
        return result.scalar_one_or_none()
