"""Email parser service for subscription detection."""

import re
from dataclasses import dataclass
from datetime import datetime
from typing import Literal

from app.services.email.schemas import (
    EmailMessage,
    DetectedSubscription,
    KnownSender,
)


@dataclass(frozen=True)
class AmountMatch:
    """Extracted amount from email."""

    amount: float
    currency: str
    raw_match: str


@dataclass(frozen=True)
class BillingCycleMatch:
    """Detected billing cycle from email."""

    cycle: Literal["weekly", "monthly", "quarterly", "yearly"]
    confidence: float


# Known subscription senders database
# This is a curated list of common subscription services
KNOWN_SENDERS: dict[str, KnownSender] = {
    # Streaming
    "netflix.com": KnownSender(
        domain="netflix.com",
        name="Netflix",
        category="streaming",
        logo_url="https://logo.clearbit.com/netflix.com",
    ),
    "hulu.com": KnownSender(
        domain="hulu.com",
        name="Hulu",
        category="streaming",
        logo_url="https://logo.clearbit.com/hulu.com",
    ),
    "disneyplus.com": KnownSender(
        domain="disneyplus.com",
        name="Disney+",
        category="streaming",
        logo_url="https://logo.clearbit.com/disneyplus.com",
    ),
    "hbomax.com": KnownSender(
        domain="hbomax.com",
        name="HBO Max",
        category="streaming",
        logo_url="https://logo.clearbit.com/hbomax.com",
    ),
    "max.com": KnownSender(
        domain="max.com",
        name="Max",
        category="streaming",
        logo_url="https://logo.clearbit.com/max.com",
    ),
    "primevideo.com": KnownSender(
        domain="primevideo.com",
        name="Prime Video",
        category="streaming",
        logo_url="https://logo.clearbit.com/primevideo.com",
    ),
    "amazon.com": KnownSender(
        domain="amazon.com",
        name="Amazon",
        category="shopping",
        logo_url="https://logo.clearbit.com/amazon.com",
    ),
    "peacocktv.com": KnownSender(
        domain="peacocktv.com",
        name="Peacock",
        category="streaming",
        logo_url="https://logo.clearbit.com/peacocktv.com",
    ),
    "paramountplus.com": KnownSender(
        domain="paramountplus.com",
        name="Paramount+",
        category="streaming",
        logo_url="https://logo.clearbit.com/paramountplus.com",
    ),
    "crunchyroll.com": KnownSender(
        domain="crunchyroll.com",
        name="Crunchyroll",
        category="streaming",
        logo_url="https://logo.clearbit.com/crunchyroll.com",
    ),
    # Music
    "spotify.com": KnownSender(
        domain="spotify.com",
        name="Spotify",
        category="music",
        logo_url="https://logo.clearbit.com/spotify.com",
    ),
    "apple.com": KnownSender(
        domain="apple.com",
        name="Apple",
        category="software",
        logo_url="https://logo.clearbit.com/apple.com",
    ),
    "tidal.com": KnownSender(
        domain="tidal.com",
        name="Tidal",
        category="music",
        logo_url="https://logo.clearbit.com/tidal.com",
    ),
    "deezer.com": KnownSender(
        domain="deezer.com",
        name="Deezer",
        category="music",
        logo_url="https://logo.clearbit.com/deezer.com",
    ),
    "pandora.com": KnownSender(
        domain="pandora.com",
        name="Pandora",
        category="music",
        logo_url="https://logo.clearbit.com/pandora.com",
    ),
    "soundcloud.com": KnownSender(
        domain="soundcloud.com",
        name="SoundCloud",
        category="music",
        logo_url="https://logo.clearbit.com/soundcloud.com",
    ),
    # Software & Productivity
    "adobe.com": KnownSender(
        domain="adobe.com",
        name="Adobe",
        category="software",
        logo_url="https://logo.clearbit.com/adobe.com",
    ),
    "microsoft.com": KnownSender(
        domain="microsoft.com",
        name="Microsoft",
        category="software",
        logo_url="https://logo.clearbit.com/microsoft.com",
    ),
    "notion.so": KnownSender(
        domain="notion.so",
        name="Notion",
        category="productivity",
        logo_url="https://logo.clearbit.com/notion.so",
    ),
    "slack.com": KnownSender(
        domain="slack.com",
        name="Slack",
        category="productivity",
        logo_url="https://logo.clearbit.com/slack.com",
    ),
    "zoom.us": KnownSender(
        domain="zoom.us",
        name="Zoom",
        category="productivity",
        logo_url="https://logo.clearbit.com/zoom.us",
    ),
    "dropbox.com": KnownSender(
        domain="dropbox.com",
        name="Dropbox",
        category="cloud_storage",
        logo_url="https://logo.clearbit.com/dropbox.com",
    ),
    "google.com": KnownSender(
        domain="google.com",
        name="Google",
        category="software",
        logo_url="https://logo.clearbit.com/google.com",
    ),
    "evernote.com": KnownSender(
        domain="evernote.com",
        name="Evernote",
        category="productivity",
        logo_url="https://logo.clearbit.com/evernote.com",
    ),
    "1password.com": KnownSender(
        domain="1password.com",
        name="1Password",
        category="software",
        logo_url="https://logo.clearbit.com/1password.com",
    ),
    "lastpass.com": KnownSender(
        domain="lastpass.com",
        name="LastPass",
        category="software",
        logo_url="https://logo.clearbit.com/lastpass.com",
    ),
    "canva.com": KnownSender(
        domain="canva.com",
        name="Canva",
        category="productivity",
        logo_url="https://logo.clearbit.com/canva.com",
    ),
    "figma.com": KnownSender(
        domain="figma.com",
        name="Figma",
        category="software",
        logo_url="https://logo.clearbit.com/figma.com",
    ),
    # Gaming
    "playstation.com": KnownSender(
        domain="playstation.com",
        name="PlayStation",
        category="gaming",
        logo_url="https://logo.clearbit.com/playstation.com",
    ),
    "xbox.com": KnownSender(
        domain="xbox.com",
        name="Xbox",
        category="gaming",
        logo_url="https://logo.clearbit.com/xbox.com",
    ),
    "steampowered.com": KnownSender(
        domain="steampowered.com",
        name="Steam",
        category="gaming",
        logo_url="https://logo.clearbit.com/steampowered.com",
    ),
    "epicgames.com": KnownSender(
        domain="epicgames.com",
        name="Epic Games",
        category="gaming",
        logo_url="https://logo.clearbit.com/epicgames.com",
    ),
    "nintendo.com": KnownSender(
        domain="nintendo.com",
        name="Nintendo",
        category="gaming",
        logo_url="https://logo.clearbit.com/nintendo.com",
    ),
    # Fitness
    "peloton.com": KnownSender(
        domain="peloton.com",
        name="Peloton",
        category="fitness",
        logo_url="https://logo.clearbit.com/peloton.com",
    ),
    "classpass.com": KnownSender(
        domain="classpass.com",
        name="ClassPass",
        category="fitness",
        logo_url="https://logo.clearbit.com/classpass.com",
    ),
    "myfitnesspal.com": KnownSender(
        domain="myfitnesspal.com",
        name="MyFitnessPal",
        category="fitness",
        logo_url="https://logo.clearbit.com/myfitnesspal.com",
    ),
    "strava.com": KnownSender(
        domain="strava.com",
        name="Strava",
        category="fitness",
        logo_url="https://logo.clearbit.com/strava.com",
    ),
    "headspace.com": KnownSender(
        domain="headspace.com",
        name="Headspace",
        category="fitness",
        logo_url="https://logo.clearbit.com/headspace.com",
    ),
    "calm.com": KnownSender(
        domain="calm.com",
        name="Calm",
        category="fitness",
        logo_url="https://logo.clearbit.com/calm.com",
    ),
    # Food Delivery
    "doordash.com": KnownSender(
        domain="doordash.com",
        name="DoorDash",
        category="food_delivery",
        logo_url="https://logo.clearbit.com/doordash.com",
    ),
    "ubereats.com": KnownSender(
        domain="ubereats.com",
        name="Uber Eats",
        category="food_delivery",
        logo_url="https://logo.clearbit.com/ubereats.com",
    ),
    "grubhub.com": KnownSender(
        domain="grubhub.com",
        name="Grubhub",
        category="food_delivery",
        logo_url="https://logo.clearbit.com/grubhub.com",
    ),
    "instacart.com": KnownSender(
        domain="instacart.com",
        name="Instacart",
        category="food_delivery",
        logo_url="https://logo.clearbit.com/instacart.com",
    ),
    # News & Media
    "nytimes.com": KnownSender(
        domain="nytimes.com",
        name="New York Times",
        category="news_media",
        logo_url="https://logo.clearbit.com/nytimes.com",
    ),
    "wsj.com": KnownSender(
        domain="wsj.com",
        name="Wall Street Journal",
        category="news_media",
        logo_url="https://logo.clearbit.com/wsj.com",
    ),
    "washingtonpost.com": KnownSender(
        domain="washingtonpost.com",
        name="Washington Post",
        category="news_media",
        logo_url="https://logo.clearbit.com/washingtonpost.com",
    ),
    "medium.com": KnownSender(
        domain="medium.com",
        name="Medium",
        category="news_media",
        logo_url="https://logo.clearbit.com/medium.com",
    ),
    # Education
    "coursera.org": KnownSender(
        domain="coursera.org",
        name="Coursera",
        category="education",
        logo_url="https://logo.clearbit.com/coursera.org",
    ),
    "udemy.com": KnownSender(
        domain="udemy.com",
        name="Udemy",
        category="education",
        logo_url="https://logo.clearbit.com/udemy.com",
    ),
    "skillshare.com": KnownSender(
        domain="skillshare.com",
        name="Skillshare",
        category="education",
        logo_url="https://logo.clearbit.com/skillshare.com",
    ),
    "masterclass.com": KnownSender(
        domain="masterclass.com",
        name="MasterClass",
        category="education",
        logo_url="https://logo.clearbit.com/masterclass.com",
    ),
    "duolingo.com": KnownSender(
        domain="duolingo.com",
        name="Duolingo",
        category="education",
        logo_url="https://logo.clearbit.com/duolingo.com",
    ),
    # Finance
    "robinhood.com": KnownSender(
        domain="robinhood.com",
        name="Robinhood",
        category="finance",
        logo_url="https://logo.clearbit.com/robinhood.com",
    ),
    "coinbase.com": KnownSender(
        domain="coinbase.com",
        name="Coinbase",
        category="finance",
        logo_url="https://logo.clearbit.com/coinbase.com",
    ),
    "acorns.com": KnownSender(
        domain="acorns.com",
        name="Acorns",
        category="finance",
        logo_url="https://logo.clearbit.com/acorns.com",
    ),
    # Cloud Storage
    "icloud.com": KnownSender(
        domain="icloud.com",
        name="iCloud",
        category="cloud_storage",
        logo_url="https://logo.clearbit.com/icloud.com",
    ),
    "box.com": KnownSender(
        domain="box.com",
        name="Box",
        category="cloud_storage",
        logo_url="https://logo.clearbit.com/box.com",
    ),
}

# Email type detection patterns
EMAIL_TYPE_PATTERNS: dict[
    Literal[
        "subscription_confirmation",
        "receipt",
        "billing_reminder",
        "price_change",
        "trial_ending",
        "payment_failed",
        "cancellation",
        "renewal_notice",
    ],
    list[str],
] = {
    "subscription_confirmation": [
        r"subscription\s+confirm",
        r"welcome\s+to\s+your\s+subscription",
        r"you(?:'re|'ve)\s+subscribed",
        r"subscription\s+started",
        r"thank\s+you\s+for\s+subscribing",
        r"subscription\s+activated",
    ],
    "receipt": [
        r"receipt\s+for",
        r"payment\s+receipt",
        r"your\s+receipt",
        r"order\s+confirm",
        r"payment\s+confirm",
        r"invoice\s+#",
        r"transaction\s+id",
        r"thank\s+you\s+for\s+your\s+(order|purchase|payment)",
    ],
    "billing_reminder": [
        r"payment\s+due",
        r"upcoming\s+payment",
        r"billing\s+reminder",
        r"payment\s+reminder",
        r"renew(s|al|ing)\s+(soon|on|in)",
        r"will\s+be\s+charged",
        r"next\s+billing\s+date",
        r"auto[\s-]?renew",
    ],
    "price_change": [
        r"price\s+(change|increase|update)",
        r"new\s+price",
        r"pricing\s+(change|update)",
        r"rate\s+increase",
        r"subscription\s+price",
        r"adjusting\s+(your\s+)?price",
    ],
    "trial_ending": [
        r"trial\s+(end|expir)",
        r"free\s+trial\s+(end|expir)",
        r"trial\s+period",
        r"trial\s+is\s+(about\s+to\s+)?end",
        r"days?\s+left\s+(in|on)\s+(your\s+)?trial",
        r"convert\s+to\s+paid",
    ],
    "payment_failed": [
        r"payment\s+failed",
        r"payment\s+declined",
        r"unable\s+to\s+process",
        r"card\s+declined",
        r"payment\s+unsuccessful",
        r"billing\s+issue",
        r"update\s+(your\s+)?payment",
        r"problem\s+with\s+(your\s+)?payment",
    ],
    "cancellation": [
        r"subscription\s+cancel",
        r"cancel(led|lation)\s+confirm",
        r"you(?:'ve)?\s+cancel(led)?",
        r"membership\s+cancel",
        r"sorry\s+to\s+see\s+you\s+go",
        r"subscription\s+end(ed|s)",
    ],
    "renewal_notice": [
        r"renewal\s+notice",
        r"subscription\s+renew",
        r"auto[\s-]?renewal",
        r"membership\s+renew",
        r"renewed?\s+for",
        r"will\s+renew",
        r"renewal\s+date",
    ],
}

# Currency patterns for amount extraction
CURRENCY_PATTERNS: list[tuple[str, str]] = [
    # Symbol patterns
    (r"\$\s*([\d,]+\.?\d*)", "USD"),
    (r"USD\s*([\d,]+\.?\d*)", "USD"),
    (r"([\d,]+\.?\d*)\s*USD", "USD"),
    (r"£\s*([\d,]+\.?\d*)", "GBP"),
    (r"GBP\s*([\d,]+\.?\d*)", "GBP"),
    (r"([\d,]+\.?\d*)\s*GBP", "GBP"),
    (r"€\s*([\d,]+\.?\d*)", "EUR"),
    (r"EUR\s*([\d,]+\.?\d*)", "EUR"),
    (r"([\d,]+\.?\d*)\s*EUR", "EUR"),
    (r"CA\$\s*([\d,]+\.?\d*)", "CAD"),
    (r"CAD\s*([\d,]+\.?\d*)", "CAD"),
    (r"([\d,]+\.?\d*)\s*CAD", "CAD"),
    (r"A\$\s*([\d,]+\.?\d*)", "AUD"),
    (r"AUD\s*([\d,]+\.?\d*)", "AUD"),
    (r"([\d,]+\.?\d*)\s*AUD", "AUD"),
    # African currencies
    (r"₦\s*([\d,]+\.?\d*)", "NGN"),
    (r"NGN\s*([\d,]+\.?\d*)", "NGN"),
    (r"([\d,]+\.?\d*)\s*NGN", "NGN"),
    (r"R\s*([\d,]+\.?\d*)", "ZAR"),
    (r"ZAR\s*([\d,]+\.?\d*)", "ZAR"),
    (r"([\d,]+\.?\d*)\s*ZAR", "ZAR"),
    (r"KES\s*([\d,]+\.?\d*)", "KES"),
    (r"([\d,]+\.?\d*)\s*KES", "KES"),
    (r"GHS\s*([\d,]+\.?\d*)", "GHS"),
    (r"([\d,]+\.?\d*)\s*GHS", "GHS"),
]

# Billing cycle patterns
BILLING_CYCLE_PATTERNS: dict[Literal["weekly", "monthly", "quarterly", "yearly"], list[str]] = {
    "weekly": [
        r"per\s+week",
        r"weekly",
        r"/\s*week",
        r"every\s+week",
        r"each\s+week",
    ],
    "monthly": [
        r"per\s+month",
        r"monthly",
        r"/\s*mo(?:nth)?",
        r"every\s+month",
        r"each\s+month",
        r"billed\s+monthly",
    ],
    "quarterly": [
        r"per\s+quarter",
        r"quarterly",
        r"every\s+3\s+months?",
        r"every\s+three\s+months?",
        r"billed\s+quarterly",
    ],
    "yearly": [
        r"per\s+year",
        r"yearly",
        r"annual(ly)?",
        r"/\s*yr",
        r"/\s*year",
        r"every\s+year",
        r"each\s+year",
        r"billed\s+annually",
        r"billed\s+yearly",
    ],
}


class EmailParserService:
    """
    Service for parsing emails to detect subscriptions.

    Uses pattern matching and known sender database to:
    - Identify subscription-related emails
    - Extract merchant name, amount, currency
    - Detect billing cycle
    - Calculate confidence scores
    """

    def parse_email(self, email: EmailMessage) -> DetectedSubscription | None:
        """
        Parse an email to detect subscription information.

        Args:
            email: Email message to parse

        Returns:
            DetectedSubscription if subscription detected, None otherwise
        """
        # Get text content for parsing
        text_content = self._get_text_content(email)

        # Detect email type
        email_type = self._detect_email_type(email.subject, text_content)
        if email_type == "other":
            # Check if it's from a known sender
            known_sender = self._get_known_sender(email.from_address)
            if not known_sender:
                return None

        # Calculate base confidence
        confidence = self._calculate_confidence(email, email_type)

        if confidence < 0.3:
            return None

        # Extract merchant name
        merchant_name = self._extract_merchant_name(email)

        # Extract amount
        amount_match = self._extract_amount(text_content)

        # Detect billing cycle
        billing_cycle_match = self._detect_billing_cycle(text_content)

        return DetectedSubscription(
            email_type=email_type,
            confidence_score=min(confidence, 1.0),
            merchant_name=merchant_name,
            amount=amount_match.amount if amount_match else None,
            currency=amount_match.currency if amount_match else None,
            billing_cycle=billing_cycle_match.cycle if billing_cycle_match else None,
            next_billing_date=None,  # Would need more advanced NLP to extract
            source_email_id=email.message_id,
        )

    def parse_emails_batch(
        self,
        emails: list[EmailMessage],
    ) -> list[DetectedSubscription]:
        """
        Parse multiple emails for subscription detection.

        Args:
            emails: List of emails to parse

        Returns:
            List of detected subscriptions (filtered, deduplicated)
        """
        detections: list[DetectedSubscription] = []

        for email in emails:
            detection = self.parse_email(email)
            if detection:
                detections.append(detection)

        # Sort by confidence (highest first)
        detections.sort(key=lambda d: d.confidence_score, reverse=True)

        return detections

    def _get_text_content(self, email: EmailMessage) -> str:
        """Extract text content from email."""
        if email.body_plain:
            return email.body_plain

        if email.body_html:
            # Basic HTML to text conversion
            text = re.sub(r"<[^>]+>", " ", email.body_html)
            text = re.sub(r"\s+", " ", text)
            return text.strip()

        return email.snippet or ""

    def _detect_email_type(
        self,
        subject: str,
        body: str,
    ) -> Literal[
        "subscription_confirmation",
        "receipt",
        "billing_reminder",
        "price_change",
        "trial_ending",
        "payment_failed",
        "cancellation",
        "renewal_notice",
        "other",
    ]:
        """Detect the type of subscription email."""
        combined = f"{subject} {body}".lower()

        # Check each email type pattern
        best_match: (
            Literal[
                "subscription_confirmation",
                "receipt",
                "billing_reminder",
                "price_change",
                "trial_ending",
                "payment_failed",
                "cancellation",
                "renewal_notice",
                "other",
            ]
            | None
        ) = None
        best_count = 0

        for email_type, patterns in EMAIL_TYPE_PATTERNS.items():
            match_count = 0
            for pattern in patterns:
                if re.search(pattern, combined, re.IGNORECASE):
                    match_count += 1

            if match_count > best_count:
                best_count = match_count
                best_match = email_type

        return best_match if best_match else "other"

    def _get_known_sender(self, from_address: str) -> KnownSender | None:
        """Check if sender is in known senders database."""
        # Extract domain from email
        if "@" in from_address:
            domain = from_address.split("@")[1].lower()
        else:
            domain = from_address.lower()

        # Direct match
        if domain in KNOWN_SENDERS:
            return KNOWN_SENDERS[domain]

        # Check for subdomain matches
        for known_domain, sender in KNOWN_SENDERS.items():
            if domain.endswith(f".{known_domain}") or known_domain.endswith(f".{domain}"):
                return sender

        return None

    def _calculate_confidence(
        self,
        email: EmailMessage,
        email_type: str,
    ) -> float:
        """Calculate confidence score for subscription detection."""
        score = 0.0

        # Known sender bonus
        known_sender = self._get_known_sender(email.from_address)
        if known_sender:
            score += 0.4

        # Email type bonus
        if email_type != "other":
            score += 0.3

        # Subject keywords
        subject_lower = email.subject.lower()
        subscription_keywords = [
            "subscription",
            "receipt",
            "invoice",
            "payment",
            "billing",
            "renewal",
            "order",
            "purchase",
            "membership",
        ]
        for keyword in subscription_keywords:
            if keyword in subject_lower:
                score += 0.1
                break

        # From address patterns
        from_lower = email.from_address.lower()
        sender_patterns = ["noreply", "no-reply", "billing", "receipt", "invoice", "payment"]
        for pattern in sender_patterns:
            if pattern in from_lower:
                score += 0.1
                break

        # Amount detected bonus
        text_content = self._get_text_content(email)
        if self._extract_amount(text_content):
            score += 0.1

        return min(score, 1.0)

    def _extract_merchant_name(self, email: EmailMessage) -> str | None:
        """Extract merchant name from email."""
        # First, check known senders
        known_sender = self._get_known_sender(email.from_address)
        if known_sender:
            return known_sender.name

        # Try from_name if available
        if email.from_name:
            # Clean up common patterns
            name = email.from_name
            name = re.sub(r"\s*(support|billing|noreply|no-reply)\s*", "", name, flags=re.IGNORECASE)
            name = name.strip()
            if name and len(name) > 1:
                return name

        # Try to extract from domain
        if "@" in email.from_address:
            domain = email.from_address.split("@")[1]
            # Remove common TLDs and clean up
            name = domain.split(".")[0]
            if name not in ["mail", "email", "noreply", "billing"]:
                return name.title()

        return None

    def _extract_amount(self, text: str) -> AmountMatch | None:
        """Extract monetary amount from text."""
        for pattern, currency in CURRENCY_PATTERNS:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                amount_str = match.group(1)
                # Clean amount string
                amount_str = amount_str.replace(",", "")
                try:
                    amount = float(amount_str)
                    # Filter unrealistic amounts
                    if 0.01 <= amount <= 10000:
                        return AmountMatch(
                            amount=amount,
                            currency=currency,
                            raw_match=match.group(0),
                        )
                except ValueError:
                    continue

        return None

    def _detect_billing_cycle(self, text: str) -> BillingCycleMatch | None:
        """Detect billing cycle from text."""
        text_lower = text.lower()

        for cycle, patterns in BILLING_CYCLE_PATTERNS.items():
            for pattern in patterns:
                if re.search(pattern, text_lower):
                    # Higher confidence for more specific patterns
                    confidence = 0.8 if "/" in pattern else 0.9
                    return BillingCycleMatch(
                        cycle=cycle,
                        confidence=confidence,
                    )

        return None

    def get_known_sender(self, domain: str) -> KnownSender | None:
        """
        Get known sender info by domain.

        Args:
            domain: Email domain to look up

        Returns:
            KnownSender or None
        """
        return KNOWN_SENDERS.get(domain.lower())

    def get_all_known_senders(self) -> list[KnownSender]:
        """Get all known subscription senders."""
        return list(KNOWN_SENDERS.values())
