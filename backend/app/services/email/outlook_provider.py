"""Outlook email provider implementation using Microsoft Graph API."""

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


class OutlookProviderError(Exception):
    """Exception raised for Microsoft Graph API errors."""

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


class OutlookProvider(EmailProvider):
    """
    Outlook/Microsoft 365 implementation of EmailProvider.

    Uses Microsoft OAuth 2.0 and Microsoft Graph API.
    """

    # Microsoft OAuth URLs (using common tenant for personal + work accounts)
    _AUTHORIZE_URL = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
    _TOKEN_URL = "https://login.microsoftonline.com/common/oauth2/v2.0/token"

    # Microsoft Graph API base URL
    _API_BASE = "https://graph.microsoft.com/v1.0"

    # Required scopes for reading emails
    _SCOPES = [
        "https://graph.microsoft.com/Mail.Read",
        "https://graph.microsoft.com/User.Read",
        "offline_access",  # For refresh token
        "openid",
        "email",
    ]

    def __init__(self) -> None:
        """Initialize OutlookProvider with settings."""
        self._client_id = settings.microsoft_client_id
        self._client_secret = settings.microsoft_client_secret

        if not self._client_id or not self._client_secret:
            raise ValueError("Microsoft OAuth credentials not configured")

    @property
    def provider_name(self) -> Literal["outlook"]:
        """Return provider identifier."""
        return "outlook"

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
            "response_mode": "query",
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
                    "scope": " ".join(self._SCOPES),
                },
            )

            if response.status_code != 200:
                error_data = response.json()
                raise OutlookProviderError(
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
                    "scope": " ".join(self._SCOPES),
                },
            )

            if response.status_code != 200:
                error_data = response.json()
                raise OutlookProviderError(
                    message=error_data.get("error_description", "Token refresh failed"),
                    error_code=error_data.get("error"),
                    status_code=response.status_code,
                )

            data = response.json()
            return OAuthTokenResponse(
                access_token=data["access_token"],
                refresh_token=data.get("refresh_token", refresh_token),
                expires_in=data.get("expires_in", 3600),
                token_type=data.get("token_type", "Bearer"),
                scope=data.get("scope"),
            )

    async def get_user_profile(
        self,
        access_token: str,
    ) -> UserProfile:
        """Get Outlook account profile."""
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(
                f"{self._API_BASE}/me",
                headers={"Authorization": f"Bearer {access_token}"},
            )

            if response.status_code != 200:
                raise OutlookProviderError(
                    message="Failed to get user profile",
                    status_code=response.status_code,
                )

            data = response.json()
            return UserProfile(
                email_address=data.get("mail") or data.get("userPrincipalName", ""),
                display_name=data.get("displayName"),
            )

    async def search_subscription_emails(
        self,
        access_token: str,
        since_date: datetime,
        page_token: str | None = None,
        max_results: int = 50,
    ) -> EmailSearchResult:
        """Search for subscription-related emails using Microsoft Graph."""
        # Build OData filter for subscription-related emails
        filter_query = self._build_search_filter(since_date)

        # Build URL with proper pagination
        if page_token:
            url = page_token  # Microsoft returns full URL for next page
        else:
            params = {
                "$filter": filter_query,
                "$top": str(max_results),
                "$orderby": "receivedDateTime desc",
                "$select": "id,subject,from,toRecipients,receivedDateTime,bodyPreview,body,hasAttachments,isRead,categories",
            }
            url = f"{self._API_BASE}/me/messages?{urlencode(params)}"

        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.get(
                url,
                headers={"Authorization": f"Bearer {access_token}"},
            )

            if response.status_code != 200:
                raise OutlookProviderError(
                    message="Failed to search emails",
                    status_code=response.status_code,
                )

            data = response.json()
            messages = [
                self._parse_message(msg)
                for msg in data.get("value", [])
            ]

            return EmailSearchResult(
                messages=messages,
                next_page_token=data.get("@odata.nextLink"),
                result_size_estimate=len(messages),
            )

    async def get_email_by_id(
        self,
        access_token: str,
        message_id: str,
    ) -> EmailMessage | None:
        """Get a specific email by ID."""
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(
                f"{self._API_BASE}/me/messages/{message_id}",
                params={
                    "$select": "id,subject,from,toRecipients,receivedDateTime,bodyPreview,body,hasAttachments,isRead,categories",
                },
                headers={"Authorization": f"Bearer {access_token}"},
            )

            if response.status_code == 404:
                return None

            if response.status_code != 200:
                raise OutlookProviderError(
                    message="Failed to get email",
                    status_code=response.status_code,
                )

            return self._parse_message(response.json())

    async def revoke_access(
        self,
        access_token: str,
    ) -> bool:
        """
        Revoke OAuth access.

        Note: Microsoft doesn't have a direct revoke endpoint.
        The user must revoke access through their Microsoft account settings.
        We return True to indicate the connection should be removed locally.
        """
        return True

    def build_search_query(self, since_date: datetime) -> str:
        """Build search query - not used for Outlook, using OData filter instead."""
        return ""

    def _build_search_filter(self, since_date: datetime) -> str:
        """Build OData filter for subscription-related emails."""
        # Format date for OData
        date_str = since_date.strftime("%Y-%m-%dT%H:%M:%SZ")

        # Microsoft Graph OData filter
        # Search in subject and from for subscription keywords
        keywords = [
            "subscription",
            "receipt",
            "invoice",
            "payment",
            "billing",
            "renewal",
            "order",
            "trial",
            "noreply",
            "no-reply",
        ]

        # Build subject contains conditions
        subject_conditions = " or ".join([
            f"contains(subject, '{kw}')"
            for kw in keywords[:6]  # OData has limits on filter complexity
        ])

        return f"receivedDateTime ge {date_str} and ({subject_conditions})"

    def _parse_message(self, data: dict) -> EmailMessage:
        """Parse Microsoft Graph message response."""
        from_data = data.get("from", {}).get("emailAddress", {})
        from_address = from_data.get("address", "")
        from_name = from_data.get("name")

        # Parse to addresses
        to_addresses = [
            recipient.get("emailAddress", {}).get("address", "")
            for recipient in data.get("toRecipients", [])
            if recipient.get("emailAddress", {}).get("address")
        ]

        # Parse body
        body_data = data.get("body", {})
        body_content = body_data.get("content", "")
        content_type = body_data.get("contentType", "text")

        body_plain: str | None = None
        body_html: str | None = None

        if content_type.lower() == "html":
            body_html = body_content
        else:
            body_plain = body_content

        # Parse timestamp
        received_str = data.get("receivedDateTime", "")
        if received_str:
            # Microsoft uses ISO 8601 format
            received_at = datetime.fromisoformat(received_str.replace("Z", "+00:00"))
        else:
            received_at = datetime.now(timezone.utc)

        return EmailMessage(
            message_id=data["id"],
            thread_id=data.get("conversationId"),
            from_address=from_address,
            from_name=from_name,
            to_addresses=to_addresses,
            subject=data.get("subject", ""),
            snippet=data.get("bodyPreview"),
            body_plain=body_plain,
            body_html=body_html,
            received_at=received_at,
            labels=data.get("categories", []),
            is_read=data.get("isRead", False),
            has_attachments=data.get("hasAttachments", False),
        )
