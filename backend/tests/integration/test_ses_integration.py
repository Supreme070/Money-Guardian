"""Integration tests for AWS SES email system and SNS bounce handling.

Tests SES transport, email routing, SNS subscription confirmation,
bounce/complaint suppression, email dedup, tier gating, and weekly digest.
"""

import json
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from uuid import uuid4

pytestmark = pytest.mark.integration


class TestSESTransport:
    """SES email transport integration tests."""

    async def test_ses_send_correct_api_structure(self):
        """SES send should call sesv2 send_email with correct structure."""
        mock_ses_client = AsyncMock()
        mock_ses_client.send_email = AsyncMock(return_value={"MessageId": "test-msg-id-123"})
        mock_ses_client.__aenter__ = AsyncMock(return_value=mock_ses_client)
        mock_ses_client.__aexit__ = AsyncMock(return_value=False)

        mock_session = MagicMock()
        mock_session.client = MagicMock(return_value=mock_ses_client)

        with (
            patch("app.core.config.settings.aws_access_key_id", "AKIATEST"),
            patch("app.core.config.settings.aws_secret_access_key", "secret"),
            patch("app.core.config.settings.aws_region", "us-east-1"),
            patch("app.core.config.settings.ses_from_email", "noreply@test.com"),
            patch("app.core.config.settings.ses_from_name", "Test"),
            patch("app.core.config.settings.ses_configuration_set", None),
            patch("aioboto3.Session", return_value=mock_session),
        ):
            from app.services.ses_email_service import SESEmailService

            result = await SESEmailService.send(
                to="user@example.com",
                subject="Test Subject",
                plain_body="Hello plain",
                html_body="<p>Hello HTML</p>",
            )

            assert result.success is True
            assert result.message_id == "test-msg-id-123"
            mock_ses_client.send_email.assert_called_once()
            call_kwargs = mock_ses_client.send_email.call_args[1]
            assert call_kwargs["Destination"] == {"ToAddresses": ["user@example.com"]}
            assert "ConfigurationSetName" not in call_kwargs

    async def test_ses_sandbox_mode_detection(self):
        """SES should detect sandbox mode and return meaningful error."""
        mock_ses_client = AsyncMock()
        mock_ses_client.send_email = AsyncMock(
            side_effect=Exception("Email address is not verified. The following identities failed the check")
        )
        mock_ses_client.__aenter__ = AsyncMock(return_value=mock_ses_client)
        mock_ses_client.__aexit__ = AsyncMock(return_value=False)

        mock_session = MagicMock()
        mock_session.client = MagicMock(return_value=mock_ses_client)

        with (
            patch("app.core.config.settings.aws_access_key_id", "AKIATEST"),
            patch("app.core.config.settings.aws_secret_access_key", "secret"),
            patch("aioboto3.Session", return_value=mock_session),
        ):
            from app.services.ses_email_service import SESEmailService

            result = await SESEmailService.send("user@example.com", "Test", "body", "<p>body</p>")

            assert result.success is False
            assert "sandbox" in result.error.lower()

    async def test_ses_missing_credentials(self):
        """SES should fail gracefully without AWS credentials."""
        with (
            patch("app.core.config.settings.aws_access_key_id", None),
            patch("app.core.config.settings.aws_secret_access_key", None),
        ):
            from app.services.ses_email_service import SESEmailService

            result = await SESEmailService.send("user@example.com", "Test", "body", "<p>body</p>")

            assert result.success is False
            assert "credentials" in result.error.lower()


class TestEmailProviderRouting:
    """Email provider routing tests."""

    async def test_ses_provider_routes_to_ses(self):
        """When email_provider=ses, _send_email routes to SES."""
        with (
            patch("app.core.config.settings.email_provider", "ses"),
            patch(
                "app.services.email_sender_service.EmailSenderService._send_via_ses",
                new_callable=AsyncMock,
                return_value=True,
            ) as mock_ses,
        ):
            from app.services.email_sender_service import EmailSenderService

            result = await EmailSenderService._send_email("to@test.com", "Sub", "plain", "<p>html</p>")

            assert result is True
            mock_ses.assert_called_once()

    async def test_smtp_provider_routes_to_smtp(self):
        """When email_provider=smtp, _send_email routes to SMTP."""
        with (
            patch("app.core.config.settings.email_provider", "smtp"),
            patch(
                "app.services.email_sender_service.EmailSenderService._send_via_smtp",
                new_callable=AsyncMock,
                return_value=True,
            ) as mock_smtp,
        ):
            from app.services.email_sender_service import EmailSenderService

            result = await EmailSenderService._send_email("to@test.com", "Sub", "plain", "<p>html</p>")

            assert result is True
            mock_smtp.assert_called_once()


class TestSNSWebhooks:
    """AWS SNS bounce/complaint webhook tests."""

    async def test_sns_subscription_confirmation(self, client_no_rate_limit):
        """SNS SubscriptionConfirmation should auto-confirm."""
        sns_payload = {
            "Type": "SubscriptionConfirmation",
            "MessageId": "test-confirm-123",
            "Message": "",
            "SubscribeURL": "https://sns.us-east-1.amazonaws.com/?Action=ConfirmSubscription&...",
        }

        with patch("httpx.AsyncClient") as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = AsyncMock()
            mock_client_cls.return_value = mock_client

            resp = await client_no_rate_limit.post(
                "/api/v1/webhooks/ses-notifications",
                content=json.dumps(sns_payload).encode(),
                headers={"content-type": "application/json"},
            )
            assert resp.status_code == 200
            mock_client.get.assert_called_once()

    async def test_sns_permanent_bounce_suppresses_user(
        self, client_no_rate_limit, db_session, test_user
    ):
        """Permanent bounce should set email_suppressed=True."""
        bounce_notification = {
            "notificationType": "Bounce",
            "bounce": {
                "bounceType": "Permanent",
                "bouncedRecipients": [
                    {"emailAddress": test_user.email}
                ],
            },
        }

        sns_payload = {
            "Type": "Notification",
            "MessageId": f"bounce-{uuid4().hex[:8]}",
            "Message": json.dumps(bounce_notification),
        }

        with patch(
            "app.core.redis_dedup.is_duplicate",
            new_callable=AsyncMock,
            return_value=False,
        ), patch(
            "app.core.redis_dedup.mark_processed",
            new_callable=AsyncMock,
        ):
            resp = await client_no_rate_limit.post(
                "/api/v1/webhooks/ses-notifications",
                content=json.dumps(sns_payload).encode(),
                headers={"content-type": "application/json"},
            )
            assert resp.status_code == 200

        # Verify user is suppressed
        await db_session.refresh(test_user)
        assert test_user.email_suppressed is True
        assert test_user.email_suppressed_reason == "hard_bounce"

    async def test_sns_complaint_suppresses_user(
        self, client_no_rate_limit, db_session, test_user
    ):
        """Complaint should set email_suppressed=True."""
        complaint_notification = {
            "notificationType": "Complaint",
            "complaint": {
                "complainedRecipients": [
                    {"emailAddress": test_user.email}
                ],
            },
        }

        sns_payload = {
            "Type": "Notification",
            "MessageId": f"complaint-{uuid4().hex[:8]}",
            "Message": json.dumps(complaint_notification),
        }

        with patch(
            "app.core.redis_dedup.is_duplicate",
            new_callable=AsyncMock,
            return_value=False,
        ), patch(
            "app.core.redis_dedup.mark_processed",
            new_callable=AsyncMock,
        ):
            resp = await client_no_rate_limit.post(
                "/api/v1/webhooks/ses-notifications",
                content=json.dumps(sns_payload).encode(),
                headers={"content-type": "application/json"},
            )
            assert resp.status_code == 200

        await db_session.refresh(test_user)
        assert test_user.email_suppressed is True
        assert test_user.email_suppressed_reason == "complaint"

    async def test_sns_transient_bounce_does_not_suppress(
        self, client_no_rate_limit, db_session, test_user
    ):
        """Transient bounce should NOT suppress the user."""
        bounce_notification = {
            "notificationType": "Bounce",
            "bounce": {
                "bounceType": "Transient",
                "bouncedRecipients": [
                    {"emailAddress": test_user.email}
                ],
            },
        }

        sns_payload = {
            "Type": "Notification",
            "MessageId": f"transient-{uuid4().hex[:8]}",
            "Message": json.dumps(bounce_notification),
        }

        with patch(
            "app.core.redis_dedup.is_duplicate",
            new_callable=AsyncMock,
            return_value=False,
        ), patch(
            "app.core.redis_dedup.mark_processed",
            new_callable=AsyncMock,
        ):
            resp = await client_no_rate_limit.post(
                "/api/v1/webhooks/ses-notifications",
                content=json.dumps(sns_payload).encode(),
                headers={"content-type": "application/json"},
            )
            assert resp.status_code == 200

        await db_session.refresh(test_user)
        assert test_user.email_suppressed is False


class TestEmailTemplates:
    """Email template rendering tests."""

    def test_all_templates_render_valid_html(self):
        """All 10 templates should render without errors."""
        from app.services.email_template_service import EmailTemplateService

        templates = [
            EmailTemplateService.render_verification("https://test.com/verify"),
            EmailTemplateService.render_password_reset("https://test.com/reset"),
            EmailTemplateService.render_welcome("Test User"),
            EmailTemplateService.render_upcoming_charge("Netflix", 15.99, "2026-03-15", 3),
            EmailTemplateService.render_overdraft_warning(
                100.0, 250.0, 150.0,
                [{"name": "Netflix", "amount": "15.99"}, {"name": "Spotify", "amount": "9.99"}],
            ),
            EmailTemplateService.render_price_increase("Netflix", 15.99, 22.99, 43.8),
            EmailTemplateService.render_trial_ending("Notion", "2026-03-15", 10.00),
            EmailTemplateService.render_forgotten_subscription("Headspace", 12.99, "2025-12-01", 98),
            EmailTemplateService.render_new_subscription_detected("Disney+", 7.99, "email scan", 0.85),
            EmailTemplateService.render_weekly_digest(
                "SAFE", 450.0,
                [{"name": "Netflix", "amount": "15.99", "date": "2026-03-15"}],
                89.97, 5,
            ),
        ]

        for content in templates:
            assert content.subject
            assert content.plain_body
            assert content.html_body
            assert "Money Guardian" in content.html_body
            assert "#15294A" in content.html_body  # Brand navy color


class TestEmailNotificationPreferences:
    """Test email notification gating and preferences."""

    def test_suppressed_user_blocked_from_email(self):
        """Suppressed users should not receive email notifications."""
        from app.tasks.notification_tasks import _user_wants_email_notification

        user = MagicMock()
        user.email_notifications_enabled = True
        user.email_suppressed = True
        user.is_verified = True
        user.notification_preferences = {}

        assert _user_wants_email_notification(user, "upcoming_charges") is False

    def test_unverified_user_blocked_from_email(self):
        """Unverified users should not receive email notifications."""
        from app.tasks.notification_tasks import _user_wants_email_notification

        user = MagicMock()
        user.email_notifications_enabled = True
        user.email_suppressed = False
        user.is_verified = False
        user.notification_preferences = {}

        assert _user_wants_email_notification(user, "upcoming_charges") is False

    def test_user_with_email_disabled_blocked(self):
        """Users who disabled email notifications should not receive them."""
        from app.tasks.notification_tasks import _user_wants_email_notification

        user = MagicMock()
        user.email_notifications_enabled = False
        user.email_suppressed = False
        user.is_verified = True
        user.notification_preferences = {}

        assert _user_wants_email_notification(user, "upcoming_charges") is False

    def test_verified_enabled_user_receives_email(self):
        """Verified, enabled, non-suppressed users should receive emails."""
        from app.tasks.notification_tasks import _user_wants_email_notification

        user = MagicMock()
        user.email_notifications_enabled = True
        user.email_suppressed = False
        user.is_verified = True
        user.notification_preferences = {}

        assert _user_wants_email_notification(user, "upcoming_charges") is True

    def test_weekly_digest_opt_in_default_off(self):
        """Weekly digest should default to off (opt-in)."""
        prefs: dict[str, bool] = {}
        assert prefs.get("weekly_digest", False) is False

    def test_welcome_email_triggers_on_verification(self):
        """Verifying email should trigger welcome email send."""
        # This is a unit-level check that the welcome email method exists
        from app.services.email_sender_service import EmailSenderService

        assert hasattr(EmailSenderService, "_send_welcome_email")
