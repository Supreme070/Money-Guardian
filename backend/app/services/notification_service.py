"""Push notification service using Firebase Admin SDK."""

import logging
from typing import Literal
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.user import User

logger = logging.getLogger(__name__)

# Notification types
NotificationType = Literal[
    "subscription_reminder",
    "overdraft_warning",
    "price_increase",
    "trial_ending",
    "payment_failed",
    "general",
]


class NotificationPayload:
    """Strictly typed notification payload."""

    def __init__(
        self,
        title: str,
        body: str,
        notification_type: NotificationType,
        subscription_id: str | None = None,
        alert_id: str | None = None,
        data: dict[str, str] | None = None,
    ) -> None:
        self.title = title
        self.body = body
        self.notification_type = notification_type
        self.subscription_id = subscription_id
        self.alert_id = alert_id
        self.data = data or {}

    def build_data_payload(self) -> dict[str, str]:
        """Build FCM data payload as a flat string dict."""
        data_payload: dict[str, str] = {
            "type": self.notification_type,
            "click_action": "FLUTTER_NOTIFICATION_CLICK",
        }

        if self.subscription_id:
            data_payload["subscription_id"] = self.subscription_id
        if self.alert_id:
            data_payload["alert_id"] = self.alert_id
        if self.data:
            data_payload.update(self.data)

        return data_payload


class NotificationService:
    """
    Service for sending push notifications via Firebase Cloud Messaging.

    IMPORTANT: Requires Firebase Admin SDK to be initialized.
    Set FIREBASE_CREDENTIALS_PATH in environment variables.
    """

    _initialized: bool = False
    _firebase_available: bool = False

    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self._ensure_initialized()

    @classmethod
    def _ensure_initialized(cls) -> None:
        """Initialize Firebase Admin SDK if not already done."""
        if cls._initialized:
            return

        try:
            import firebase_admin
            from firebase_admin import credentials

            # Check if already initialized
            try:
                firebase_admin.get_app()
                cls._firebase_available = True
                cls._initialized = True
                return
            except ValueError:
                pass

            # Initialize with credentials
            if settings.firebase_credentials_path:
                cred = credentials.Certificate(settings.firebase_credentials_path)
                firebase_admin.initialize_app(cred)
                cls._firebase_available = True
                logger.info("Firebase Admin SDK initialized successfully")
            else:
                logger.warning(
                    "FIREBASE_CREDENTIALS_PATH not set. "
                    "Push notifications will not be sent."
                )
                cls._firebase_available = False

        except ImportError:
            logger.warning(
                "firebase_admin package not installed. "
                "Push notifications will not be sent."
            )
            cls._firebase_available = False

        cls._initialized = True

    async def send_to_user(
        self,
        user_id: UUID,
        tenant_id: UUID,
        payload: NotificationPayload,
    ) -> bool:
        """
        Send notification to a specific user.

        Returns True if sent successfully, False otherwise.
        """
        # Get user's FCM token
        result = await self.db.execute(
            select(User).where(
                User.id == user_id,
                User.tenant_id == tenant_id,
                User.is_active == True,
            )
        )
        user = result.scalar_one_or_none()

        if user is None or user.fcm_token is None:
            return False

        # Check if user has notifications enabled
        if not user.push_notifications_enabled:
            return False

        return await self._send_fcm_message(user.fcm_token, payload)

    async def send_to_users(
        self,
        user_ids: list[UUID],
        tenant_id: UUID,
        payload: NotificationPayload,
    ) -> int:
        """
        Send notification to multiple users.

        Returns count of successfully sent notifications.
        """
        # Get users with FCM tokens
        result = await self.db.execute(
            select(User).where(
                User.id.in_(user_ids),
                User.tenant_id == tenant_id,
                User.is_active == True,
                User.fcm_token.isnot(None),
                User.push_notifications_enabled == True,
            )
        )
        users = result.scalars().all()

        sent_count = 0
        for user in users:
            if user.fcm_token and await self._send_fcm_message(user.fcm_token, payload):
                sent_count += 1

        return sent_count

    async def _send_fcm_message(
        self,
        fcm_token: str,
        payload: NotificationPayload,
    ) -> bool:
        """Send FCM message to a specific token."""
        if not self._firebase_available:
            logger.debug(
                "Firebase not available. Skipping notification: %s",
                payload.title,
            )
            return False

        try:
            from firebase_admin import messaging

            data_payload = payload.build_data_payload()

            message = messaging.Message(
                token=fcm_token,
                notification=messaging.Notification(
                    title=payload.title,
                    body=payload.body,
                ),
                data=data_payload,
                android=messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        channel_id="money_guardian_alerts",
                        sound="default",
                    ),
                ),
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(
                            sound="default",
                            badge=1,
                        ),
                    ),
                ),
            )

            response: str = messaging.send(message)
            logger.info(
                "FCM notification sent: %s (message_id=%s)",
                payload.title,
                response,
            )
            return True

        except Exception as e:
            logger.error("Failed to send FCM notification: %s", e)
            return False

    # Convenience methods for common notification types

    async def send_subscription_reminder(
        self,
        user_id: UUID,
        tenant_id: UUID,
        subscription_name: str,
        amount: float,
        days_until: int,
        subscription_id: str,
    ) -> bool:
        """Send reminder about upcoming subscription charge."""
        if days_until == 0:
            body = f"${amount:.2f} will be charged today"
        elif days_until == 1:
            body = f"${amount:.2f} will be charged tomorrow"
        else:
            body = f"${amount:.2f} will be charged in {days_until} days"

        payload = NotificationPayload(
            title=f"Upcoming: {subscription_name}",
            body=body,
            notification_type="subscription_reminder",
            subscription_id=subscription_id,
        )
        return await self.send_to_user(user_id, tenant_id, payload)

    async def send_overdraft_warning(
        self,
        user_id: UUID,
        tenant_id: UUID,
        current_balance: float,
        upcoming_charges: float,
        alert_id: str,
    ) -> bool:
        """Send overdraft warning notification."""
        shortfall = upcoming_charges - current_balance
        payload = NotificationPayload(
            title="Overdraft Risk Detected",
            body=f"Upcoming charges (${upcoming_charges:.2f}) exceed your balance. "
            f"You may need ${shortfall:.2f} more.",
            notification_type="overdraft_warning",
            alert_id=alert_id,
        )
        return await self.send_to_user(user_id, tenant_id, payload)

    async def send_price_increase_alert(
        self,
        user_id: UUID,
        tenant_id: UUID,
        subscription_name: str,
        old_price: float,
        new_price: float,
        subscription_id: str,
    ) -> bool:
        """Send alert about subscription price increase."""
        increase = new_price - old_price
        percent = (increase / old_price) * 100 if old_price > 0 else 0

        payload = NotificationPayload(
            title=f"Price Increase: {subscription_name}",
            body=f"Price increased from ${old_price:.2f} to ${new_price:.2f} "
            f"(+{percent:.0f}%)",
            notification_type="price_increase",
            subscription_id=subscription_id,
        )
        return await self.send_to_user(user_id, tenant_id, payload)

    async def send_trial_ending_reminder(
        self,
        user_id: UUID,
        tenant_id: UUID,
        subscription_name: str,
        days_until: int,
        amount_after_trial: float,
        subscription_id: str,
    ) -> bool:
        """Send reminder about trial ending."""
        if days_until == 0:
            body = f"Trial ends today. Will charge ${amount_after_trial:.2f}"
        elif days_until == 1:
            body = f"Trial ends tomorrow. Will charge ${amount_after_trial:.2f}"
        else:
            body = f"Trial ends in {days_until} days. Will charge ${amount_after_trial:.2f}"

        payload = NotificationPayload(
            title=f"Trial Ending: {subscription_name}",
            body=body,
            notification_type="trial_ending",
            subscription_id=subscription_id,
        )
        return await self.send_to_user(user_id, tenant_id, payload)
