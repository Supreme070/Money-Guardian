"""Email sending service for verification, password reset, and notification emails.

Routes through AWS SES (production) or SMTP (local dev) based on config.
"""

import hashlib
import logging
import secrets
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.user import User

logger = logging.getLogger(__name__)


class EmailSenderService:
    """
    Service for sending transactional emails.

    Handles email verification, password reset, and welcome flows.
    Routes through AWS SES (production) or SMTP (dev) based on config.
    """

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def send_verification_email(
        self,
        user_id: str,
        email: str,
    ) -> bool:
        """
        Generate verification token and send verification email.

        Returns True if email was sent successfully.
        """
        token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        expires_at = datetime.now(timezone.utc) + timedelta(hours=24)

        # Store hashed token - raw token goes in the email link
        await self.db.execute(
            update(User)
            .where(User.id == user_id)
            .values(
                email_verification_token=token_hash,
                email_verification_token_expires_at=expires_at,
            )
        )
        await self.db.commit()

        # Build verification URL with the raw (unhashed) token
        verify_url = f"{settings.frontend_url}/verify-email?token={token}"

        from app.services.email_template_service import EmailTemplateService

        content = EmailTemplateService.render_verification(verify_url)
        return await self._send_email(email, content.subject, content.plain_body, content.html_body)

    async def send_password_reset_email(
        self,
        user_id: str,
        email: str,
    ) -> bool:
        """
        Generate password reset token and send reset email.

        Returns True if email was sent successfully.
        """
        token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        expires_at = datetime.now(timezone.utc) + timedelta(hours=1)

        # Store hashed token - raw token goes in the email link
        await self.db.execute(
            update(User)
            .where(User.id == user_id)
            .values(
                password_reset_token=token_hash,
                password_reset_token_expires_at=expires_at,
            )
        )
        await self.db.commit()

        # Build reset URL with the raw (unhashed) token
        reset_url = f"{settings.frontend_url}/reset-password?token={token}"

        from app.services.email_template_service import EmailTemplateService

        content = EmailTemplateService.render_password_reset(reset_url)
        return await self._send_email(email, content.subject, content.plain_body, content.html_body)

    async def verify_email_token(
        self,
        token: str,
    ) -> bool:
        """
        Verify an email verification token and mark user as verified.

        Hashes the incoming token and compares against the stored hash.
        Returns True if token is valid and user is verified.
        """
        token_hash = hashlib.sha256(token.encode()).hexdigest()

        result = await self.db.execute(
            select(User).where(
                User.email_verification_token == token_hash,
                User.is_verified == False,
            )
        )
        user = result.scalar_one_or_none()

        if not user:
            return False

        if (
            user.email_verification_token_expires_at
            and user.email_verification_token_expires_at < datetime.now(timezone.utc)
        ):
            return False

        user.is_verified = True
        user.email_verification_token = None
        user.email_verification_token_expires_at = None
        await self.db.commit()

        # Send welcome email after successful verification
        await self._send_welcome_email(user.email, user.full_name)

        return True

    async def _send_welcome_email(self, email: str, full_name: str | None) -> bool:
        """Send a branded welcome email after email verification."""
        from app.services.email_template_service import EmailTemplateService

        content = EmailTemplateService.render_welcome(full_name or "there")
        return await self._send_email(email, content.subject, content.plain_body, content.html_body)

    async def verify_password_reset_token(
        self,
        token: str,
    ) -> User | None:
        """
        Verify a password reset token.

        Hashes the incoming token and compares against the stored hash.
        Returns the user if token is valid, None otherwise.
        """
        token_hash = hashlib.sha256(token.encode()).hexdigest()

        result = await self.db.execute(
            select(User).where(
                User.password_reset_token == token_hash,
            )
        )
        user = result.scalar_one_or_none()

        if not user:
            return None

        if (
            user.password_reset_token_expires_at
            and user.password_reset_token_expires_at < datetime.now(timezone.utc)
        ):
            return None

        return user

    @staticmethod
    async def _send_email(
        to_email: str,
        subject: str,
        plain_body: str,
        html_body: str,
    ) -> bool:
        """Send an email via SES or SMTP based on config.

        Routes through AWS SES when email_provider="ses",
        falls back to aiosmtplib when email_provider="smtp".
        """
        if settings.email_provider == "ses":
            return await EmailSenderService._send_via_ses(to_email, subject, plain_body, html_body)
        return await EmailSenderService._send_via_smtp(to_email, subject, plain_body, html_body)

    @staticmethod
    async def _send_via_ses(
        to_email: str,
        subject: str,
        plain_body: str,
        html_body: str,
    ) -> bool:
        """Send email via AWS SES v2."""
        from app.services.ses_email_service import SESEmailService

        result = await SESEmailService.send(to_email, subject, plain_body, html_body)
        return result.success

    @staticmethod
    async def _send_via_smtp(
        to_email: str,
        subject: str,
        plain_body: str,
        html_body: str,
    ) -> bool:
        """Send email via SMTP (local dev fallback)."""
        if not settings.smtp_user or not settings.smtp_password:
            if settings.environment == "production":
                logger.error(
                    "SMTP not configured in production. "
                    "Email NOT sent to %s: subject='%s'",
                    to_email,
                    subject,
                )
            else:
                logger.warning(
                    "SMTP not configured (dev). "
                    "Email NOT sent to %s: subject='%s'",
                    to_email,
                    subject,
                )
            return False

        try:
            import aiosmtplib

            message = EmailMessage()
            message["From"] = f"{settings.smtp_from_name} <{settings.smtp_from_email}>"
            message["To"] = to_email
            message["Subject"] = subject
            message.set_content(plain_body)
            message.add_alternative(html_body, subtype="html")

            await aiosmtplib.send(
                message,
                hostname=settings.smtp_host,
                port=settings.smtp_port,
                start_tls=True,
                username=settings.smtp_user,
                password=settings.smtp_password,
            )

            logger.info("Email sent to %s: %s", to_email, subject)
            return True

        except ImportError:
            logger.error(
                "aiosmtplib package not installed. Email NOT sent to %s",
                to_email,
            )
            return False

        except Exception as e:
            logger.error("Failed to send email to %s: %s", to_email, e)
            return False
