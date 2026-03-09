"""AWS SES v2 async email transport.

Uses aioboto3 for fully async SES v2 API calls.
Detects sandbox mode and handles SES-specific error codes.
"""

import logging
from dataclasses import dataclass

from app.core.config import settings

logger = logging.getLogger(__name__)


@dataclass
class EmailSendResult:
    """Result of an SES email send attempt."""

    success: bool
    message_id: str | None = None
    error: str | None = None


class SESEmailService:
    """Async AWS SES v2 email transport."""

    @staticmethod
    async def send(
        to: str,
        subject: str,
        plain_body: str,
        html_body: str,
    ) -> EmailSendResult:
        """Send an email via AWS SES v2.

        Args:
            to: Recipient email address.
            subject: Email subject line.
            plain_body: Plain text email body.
            html_body: HTML email body.

        Returns:
            EmailSendResult with success status and message ID or error.
        """
        if not settings.aws_access_key_id or not settings.aws_secret_access_key:
            logger.error("AWS credentials not configured — email NOT sent to %s", to)
            return EmailSendResult(success=False, error="AWS credentials not configured")

        try:
            import aioboto3

            session = aioboto3.Session(
                aws_access_key_id=settings.aws_access_key_id,
                aws_secret_access_key=settings.aws_secret_access_key,
                region_name=settings.aws_region,
            )

            from_address = f"{settings.ses_from_name} <{settings.ses_from_email}>"

            async with session.client("sesv2") as ses:
                send_kwargs: dict[str, object] = {
                    "FromEmailAddress": from_address,
                    "Destination": {"ToAddresses": [to]},
                    "Content": {
                        "Simple": {
                            "Subject": {"Data": subject, "Charset": "UTF-8"},
                            "Body": {
                                "Text": {"Data": plain_body, "Charset": "UTF-8"},
                                "Html": {"Data": html_body, "Charset": "UTF-8"},
                            },
                        }
                    },
                }

                if settings.ses_configuration_set:
                    send_kwargs["ConfigurationSetName"] = settings.ses_configuration_set

                response = await ses.send_email(**send_kwargs)

            message_id = response.get("MessageId", "")
            logger.info("SES email sent to %s: message_id=%s subject='%s'", to, message_id, subject)
            return EmailSendResult(success=True, message_id=message_id)

        except ImportError:
            logger.error("aioboto3 package not installed — email NOT sent to %s", to)
            return EmailSendResult(success=False, error="aioboto3 not installed")

        except Exception as e:
            error_str = str(e)

            # Detect SES sandbox mode
            if "Email address is not verified" in error_str:
                logger.warning(
                    "SES sandbox mode: recipient %s is not verified. "
                    "Request production access or verify the recipient in SES console.",
                    to,
                )
                return EmailSendResult(success=False, error="SES sandbox: recipient not verified")

            # Detect SES sending quota exceeded
            if "Daily message quota exceeded" in error_str:
                logger.error("SES daily sending quota exceeded")
                return EmailSendResult(success=False, error="SES quota exceeded")

            logger.error("SES send failed to %s: %s", to, error_str)
            return EmailSendResult(success=False, error=error_str)
