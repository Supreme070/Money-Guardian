"""Email sending service for verification and password reset emails.

Uses aiosmtplib for async SMTP email delivery.
"""

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

    Handles email verification and password reset flows.
    Uses aiosmtplib for async delivery.
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
        expires_at = datetime.now(timezone.utc) + timedelta(hours=24)

        # Store token on user
        await self.db.execute(
            update(User)
            .where(User.id == user_id)
            .values(
                email_verification_token=token,
                email_verification_token_expires_at=expires_at,
            )
        )
        await self.db.commit()

        # Build verification URL
        verify_url = (
            f"{settings.frontend_url}/verify-email?token={token}"
        )

        # Send email
        subject = "Verify your Money Guardian account"
        body = (
            f"Welcome to Money Guardian!\n\n"
            f"Please verify your email address by clicking the link below:\n\n"
            f"{verify_url}\n\n"
            f"This link expires in 24 hours.\n\n"
            f"If you didn't create an account, you can safely ignore this email.\n\n"
            f"— The Money Guardian Team"
        )

        html_body = f"""
        <div style="font-family: 'Mulish', Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 40px 20px;">
            <div style="text-align: center; margin-bottom: 32px;">
                <h1 style="color: #15294A; font-size: 24px; margin: 0;">Money Guardian</h1>
                <p style="color: #797878; font-size: 14px;">Stop losing money to dumb fees.</p>
            </div>
            <div style="background: #F1F1F3; border-radius: 12px; padding: 32px;">
                <h2 style="color: #1D2635; font-size: 20px; margin-top: 0;">Verify your email</h2>
                <p style="color: #797878; line-height: 1.6;">
                    Welcome! Please verify your email address to get started.
                </p>
                <div style="text-align: center; margin: 24px 0;">
                    <a href="{verify_url}"
                       style="display: inline-block; background: #375EFD; color: white;
                              padding: 14px 32px; border-radius: 8px; text-decoration: none;
                              font-weight: 700; font-size: 16px;">
                        Verify Email
                    </a>
                </div>
                <p style="color: #B9B9B9; font-size: 12px; text-align: center;">
                    This link expires in 24 hours.
                </p>
            </div>
            <p style="color: #B9B9B9; font-size: 12px; text-align: center; margin-top: 24px;">
                If you didn't create an account, ignore this email.
            </p>
        </div>
        """

        return await self._send_email(email, subject, body, html_body)

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
        expires_at = datetime.now(timezone.utc) + timedelta(hours=1)

        # Store token on user
        await self.db.execute(
            update(User)
            .where(User.id == user_id)
            .values(
                password_reset_token=token,
                password_reset_token_expires_at=expires_at,
            )
        )
        await self.db.commit()

        # Build reset URL
        reset_url = (
            f"{settings.frontend_url}/reset-password?token={token}"
        )

        subject = "Reset your Money Guardian password"
        body = (
            f"You requested a password reset for your Money Guardian account.\n\n"
            f"Click the link below to set a new password:\n\n"
            f"{reset_url}\n\n"
            f"This link expires in 1 hour.\n\n"
            f"If you didn't request this, you can safely ignore this email.\n\n"
            f"— The Money Guardian Team"
        )

        html_body = f"""
        <div style="font-family: 'Mulish', Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 40px 20px;">
            <div style="text-align: center; margin-bottom: 32px;">
                <h1 style="color: #15294A; font-size: 24px; margin: 0;">Money Guardian</h1>
            </div>
            <div style="background: #F1F1F3; border-radius: 12px; padding: 32px;">
                <h2 style="color: #1D2635; font-size: 20px; margin-top: 0;">Reset your password</h2>
                <p style="color: #797878; line-height: 1.6;">
                    You requested a password reset. Click below to set a new password.
                </p>
                <div style="text-align: center; margin: 24px 0;">
                    <a href="{reset_url}"
                       style="display: inline-block; background: #375EFD; color: white;
                              padding: 14px 32px; border-radius: 8px; text-decoration: none;
                              font-weight: 700; font-size: 16px;">
                        Reset Password
                    </a>
                </div>
                <p style="color: #B9B9B9; font-size: 12px; text-align: center;">
                    This link expires in 1 hour.
                </p>
            </div>
        </div>
        """

        return await self._send_email(email, subject, body, html_body)

    async def verify_email_token(
        self,
        token: str,
    ) -> bool:
        """
        Verify an email verification token and mark user as verified.

        Returns True if token is valid and user is verified.
        """
        result = await self.db.execute(
            select(User).where(
                User.email_verification_token == token,
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

        return True

    async def verify_password_reset_token(
        self,
        token: str,
    ) -> User | None:
        """
        Verify a password reset token.

        Returns the user if token is valid, None otherwise.
        """
        result = await self.db.execute(
            select(User).where(
                User.password_reset_token == token,
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
        """Send an email via SMTP."""
        if not settings.smtp_user or not settings.smtp_password:
            logger.info(
                "SMTP not configured. Would send to %s: subject='%s'",
                to_email,
                subject,
            )
            return True  # Return True in dev so flow continues

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

        except Exception as e:
            logger.error("Failed to send email to %s: %s", to_email, e)
            return False
