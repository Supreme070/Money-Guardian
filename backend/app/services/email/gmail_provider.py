"""Gmail email provider implementation using Google OAuth and Gmail API."""

import base64
from datetime import datetime, timezone
from typing import Literal
from urllib.parse import urlencode

import httpx

from app.core.config import settings
from app.services.email.base import EmailProvider
from app.services.email.schemas import (
    OAuthTokenResponse,
    EmailMessage,
    EmailSearchResult,
    UserProfile,
)


class GmailProviderError(Exception):
    """Exception raised for Gmail API errors."""

    def __init__(
        self,
        message: str,
        error_code: str | None = None,
        status_code: int | None = None,
    ) -> None:
        self.message = message
        self.error_code = error_code
        self.status_code = status_code
        super().__init__(self.message)


class GmailProvider(EmailProvider):
    """
    Gmail implementation of EmailProvider.

    Uses Google OAuth 2.0 and Gmail API v1.
    """

    # Google OAuth URLs
    _AUTHORIZE_URL = "https://accounts.google.com/o/oauth2/v2/auth"
    _TOKEN_URL = "https://oauth2.googleapis.com/token"
    _REVOKE_URL = "https://oauth2.googleapis.com/revoke"

    # Gmail API base URL
    _API_BASE = "https://gmail.googleapis.com/gmail/v1"

    # Required scopes for reading emails
    _SCOPES = [
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/userinfo.email",
        "openid",
    ]

    def __init__(self) -> None:
        """Initialize GmailProvider with settings."""
        self._client_id = settings.google_client_id
        self._client_secret = settings.google_client_secret

        if not self._client_id or not self._client_secret:
            raise ValueError("Google OAuth credentials not configured")

    @property
    def provider_name(self) -> Literal["gmail"]:
        """Return provider identifier."""
        return "gmail"

    @property
    def oauth_authorize_url(self) -> str:
        """Return OAuth authorization URL."""
        return self._AUTHORIZE_URL

    @property
    def oauth_token_url(self) -> str:
        """Return OAuth token exchange URL."""
        return self._TOKEN_URL

    @property
    def required_scopes(self) -> list[str]:
        """Return required OAuth scopes."""
        return self._SCOPES

    def get_authorization_url(
        self,
        state: str,
        redirect_uri: str,
    ) -> str:
        """Build OAuth authorization URL."""
        params = {
            "client_id": self._client_id,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "scope": " ".join(self._SCOPES),
            "state": state,
            "access_type": "offline",  # Get refresh token
            "prompt": "consent",  # Always show consent screen
        }
        return f"{self._AUTHORIZE_URL}?{urlencode(params)}"

    async def exchange_code_for_tokens(
        self,
        code: str,
        redirect_uri: str,
    ) -> OAuthTokenResponse:
        """Exchange authorization code for tokens."""
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                self._TOKEN_URL,
                data={
                    "client_id": self._client_id,
                    "client_secret": self._client_secret,
                    "code": code,
                    "grant_type": "authorization_code",
                    "redirect_uri": redirect_uri,
                },
            )

            if response.status_code != 200:
                error_data = response.json()
                raise GmailProviderError(
                    message=error_data.get("error_description", "Token exchange failed"),
                    error_code=error_data.get("error"),
                    status_code=response.status_code,
                )

            data = response.json()
            return OAuthTokenResponse(
                access_token=data["access_token"],
                refresh_token=data.get("refresh_token"),
                expires_in=data.get("expires_in", 3600),
                token_type=data.get("token_type", "Bearer"),
                scope=data.get("scope"),
            )

    async def refresh_access_token(
        self,
        refresh_token: str,
    ) -> OAuthTokenResponse:
        """Refresh an expired access token."""
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                self._TOKEN_URL,
                data={
                    "client_id": self._client_id,
                    "client_secret": self._client_secret,
                    "refresh_token": refresh_token,
                    "grant_type": "refresh_token",
                },
            )

            if response.status_code != 200:
                error_data = response.json()
                raise GmailProviderError(
                    message=error_data.get("error_description", "Token refresh failed"),
                    error_code=error_data.get("error"),
                    status_code=response.status_code,
                )

            data = response.json()
            return OAuthTokenResponse(
                access_token=data["access_token"],
                refresh_token=refresh_token,  # Refresh token doesn't change
                expires_in=data.get("expires_in", 3600),
                token_type=data.get("token_type", "Bearer"),
                scope=data.get("scope"),
            )

    async def get_user_profile(
        self,
        access_token: str,
    ) -> UserProfile:
        """Get Gmail account profile."""
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(
                f"{self._API_BASE}/users/me/profile",
                headers={"Authorization": f"Bearer {access_token}"},
            )

            if response.status_code != 200:
                raise GmailProviderError(
                    message="Failed to get user profile",
                    status_code=response.status_code,
                )

            data = response.json()
            return UserProfile(
                email_address=data["emailAddress"],
                display_name=None,  # Gmail API doesn't return display name here
            )

    async def search_subscription_emails(
        self,
        access_token: str,
        since_date: datetime,
        page_token: str | None = None,
        max_results: int = 50,
    ) -> EmailSearchResult:
        """Search for subscription-related emails."""
        query = self.build_search_query(since_date)

        params: dict[str, str | int | bool] = {
            "q": query,
            "maxResults": max_results,
            "includeSpamTrash": True,  # Search spam & trash too
        }
        if page_token:
            params["pageToken"] = page_token

        async with httpx.AsyncClient(timeout=60.0) as client:
            # Search for message IDs
            response = await client.get(
                f"{self._API_BASE}/users/me/messages",
                params=params,
                headers={"Authorization": f"Bearer {access_token}"},
            )

            if response.status_code != 200:
                raise GmailProviderError(
                    message="Failed to search emails",
                    status_code=response.status_code,
                )

            data = response.json()
            message_refs = data.get("messages", [])

            # Fetch full message details
            messages: list[EmailMessage] = []
            for ref in message_refs:
                msg = await self._get_message_detail(client, access_token, ref["id"])
                if msg:
                    messages.append(msg)

            return EmailSearchResult(
                messages=messages,
                next_page_token=data.get("nextPageToken"),
                result_size_estimate=data.get("resultSizeEstimate", len(messages)),
            )

    async def get_email_by_id(
        self,
        access_token: str,
        message_id: str,
    ) -> EmailMessage | None:
        """Get a specific email by ID."""
        async with httpx.AsyncClient(timeout=30.0) as client:
            return await self._get_message_detail(client, access_token, message_id)

    async def revoke_access(
        self,
        access_token: str,
    ) -> bool:
        """Revoke OAuth access."""
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                self._REVOKE_URL,
                params={"token": access_token},
            )
            return response.status_code == 200

    async def _get_message_detail(
        self,
        client: httpx.AsyncClient,
        access_token: str,
        message_id: str,
    ) -> EmailMessage | None:
        """Fetch full message details."""
        response = await client.get(
            f"{self._API_BASE}/users/me/messages/{message_id}",
            params={"format": "full"},
            headers={"Authorization": f"Bearer {access_token}"},
        )

        if response.status_code != 200:
            return None

        data = response.json()
        return self._parse_message(data)

    def _parse_message(self, data: dict[str, object]) -> EmailMessage:
        """Parse Gmail API message response."""
        headers = {
            h["name"].lower(): h["value"]
            for h in data.get("payload", {}).get("headers", [])
        }

        # Parse from address
        from_header = headers.get("from", "")
        from_address, from_name = self._parse_email_address(from_header)

        # Parse to addresses
        to_header = headers.get("to", "")
        to_addresses = [
            addr.strip()
            for addr in to_header.split(",")
            if addr.strip()
        ]

        # Extract body
        body_plain, body_html = self._extract_body(data.get("payload", {}))

        # Parse timestamp
        internal_date = int(data.get("internalDate", "0"))
        received_at = datetime.fromtimestamp(internal_date / 1000, tz=timezone.utc)

        # Get labels
        labels = data.get("labelIds", [])

        return EmailMessage(
            message_id=data["id"],
            thread_id=data.get("threadId"),
            from_address=from_address,
            from_name=from_name,
            to_addresses=to_addresses,
            subject=headers.get("subject", ""),
            snippet=data.get("snippet"),
            body_plain=body_plain,
            body_html=body_html,
            received_at=received_at,
            labels=labels,
            is_read="UNREAD" not in labels,
            has_attachments=self._has_attachments(data.get("payload", {})),
        )

    @staticmethod
    def _parse_email_address(header: str) -> tuple[str, str | None]:
        """Parse email address from header (e.g., 'Name <email@example.com>')."""
        if "<" in header and ">" in header:
            name_part = header.split("<")[0].strip().strip('"').strip("'")
            email_part = header.split("<")[1].rstrip(">").strip()
            return email_part, name_part if name_part else None
        return header.strip(), None

    def _extract_body(self, payload: dict[str, object]) -> tuple[str | None, str | None]:
        """Extract plain text and HTML body from message payload."""
        body_plain: str | None = None
        body_html: str | None = None

        mime_type = payload.get("mimeType", "")

        # Single part message
        if "body" in payload and payload["body"].get("data"):
            decoded = self._decode_base64(payload["body"]["data"])
            if "text/plain" in mime_type:
                body_plain = decoded
            elif "text/html" in mime_type:
                body_html = decoded

        # Multipart message
        if "parts" in payload:
            for part in payload["parts"]:
                part_mime = part.get("mimeType", "")
                part_body = part.get("body", {}).get("data")

                if part_body:
                    decoded = self._decode_base64(part_body)
                    if "text/plain" in part_mime and not body_plain:
                        body_plain = decoded
                    elif "text/html" in part_mime and not body_html:
                        body_html = decoded

                # Nested parts (multipart/alternative)
                if "parts" in part:
                    nested_plain, nested_html = self._extract_body(part)
                    if nested_plain and not body_plain:
                        body_plain = nested_plain
                    if nested_html and not body_html:
                        body_html = nested_html

        return body_plain, body_html

    @staticmethod
    def _decode_base64(data: str) -> str:
        """Decode base64url encoded string."""
        # Gmail uses URL-safe base64
        decoded_bytes = base64.urlsafe_b64decode(data)
        return decoded_bytes.decode("utf-8", errors="replace")

    @staticmethod
    def _has_attachments(payload: dict[str, object]) -> bool:
        """Check if message has attachments."""
        if payload.get("filename"):
            return True

        for part in payload.get("parts", []):
            if part.get("filename"):
                return True
            if GmailProvider._has_attachments(part):
                return True

        return False
