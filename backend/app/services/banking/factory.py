"""Factory for creating banking providers based on region."""

from typing import Literal

from app.services.banking.base import BankingProvider
from app.services.banking.plaid_provider import PlaidProvider
from app.services.banking.mono_provider import MonoProvider
from app.services.banking.stitch_provider import StitchProvider
from app.services.banking.truelayer_provider import TrueLayerProvider
from app.services.banking.tink_provider import TinkProvider


# All supported provider identifiers
ProviderType = Literal["plaid", "mono", "stitch", "truelayer", "tink"]


# Region to provider mapping
_REGION_PROVIDER_MAP: dict[str, ProviderType] = {
    # USA & Canada - Plaid (12,000+ institutions)
    "US": "plaid",
    "CA": "plaid",
    # UK & Ireland - TrueLayer (98% UK bank coverage)
    "GB": "truelayer",
    "IE": "truelayer",
    # Europe - Tink (Visa-backed, 2000+ banks across 19 countries)
    "FR": "tink",
    "DE": "tink",
    "ES": "tink",
    "IT": "tink",
    "NL": "tink",
    "SE": "tink",
    "FI": "tink",
    "NO": "tink",
    "DK": "tink",
    "PT": "tink",
    "AT": "tink",
    "BE": "tink",
    "PL": "tink",
    "LT": "tink",
    # Africa - Mono (Nigeria, Ghana, Kenya)
    "NG": "mono",
    "GH": "mono",
    "KE": "mono",
    # South Africa - Stitch
    "ZA": "stitch",
}


def get_provider_for_region(country_code: str) -> ProviderType:
    """
    Determine the best banking provider for a given country.

    Args:
        country_code: ISO 3166-1 alpha-2 country code (e.g., "US", "NG", "ZA", "GB")

    Returns:
        Provider identifier

    Raises:
        ValueError: If country is not supported
    """
    code = country_code.upper()
    if code not in _REGION_PROVIDER_MAP:
        raise ValueError(
            f"Country '{code}' is not supported. "
            f"Supported: {', '.join(sorted(_REGION_PROVIDER_MAP.keys()))}"
        )
    return _REGION_PROVIDER_MAP[code]


def get_banking_provider(
    provider: ProviderType,
) -> BankingProvider:
    """
    Get a banking provider instance.

    Args:
        provider: Provider identifier

    Returns:
        BankingProvider implementation

    Raises:
        ValueError: If provider is not supported or credentials not configured
    """
    if provider == "plaid":
        return PlaidProvider()
    elif provider == "mono":
        return MonoProvider()
    elif provider == "stitch":
        return StitchProvider()
    elif provider == "truelayer":
        return TrueLayerProvider()
    elif provider == "tink":
        return TinkProvider()
    else:
        raise ValueError(f"Unknown banking provider: {provider}")


def get_supported_regions() -> dict[str, list[str]]:
    """
    Get mapping of providers to their supported regions.

    Returns:
        Dictionary with provider names as keys and list of country codes as values
    """
    regions: dict[str, list[str]] = {}
    for country, provider in _REGION_PROVIDER_MAP.items():
        if provider not in regions:
            regions[provider] = []
        regions[provider].append(country)
    return regions


def is_region_supported(country_code: str) -> bool:
    """
    Check if a country is supported by any banking provider.

    Args:
        country_code: ISO 3166-1 alpha-2 country code

    Returns:
        True if the country has a supported provider
    """
    return country_code.upper() in _REGION_PROVIDER_MAP
