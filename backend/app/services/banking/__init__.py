"""Banking services for Plaid/Mono/Stitch integrations."""

from app.services.banking.base import BankingProvider
from app.services.banking.plaid_provider import PlaidProvider, PlaidProviderError
from app.services.banking.mono_provider import MonoProvider, MonoProviderError
from app.services.banking.stitch_provider import StitchProvider, StitchProviderError
from app.services.banking.schemas import (
    LinkTokenResponse,
    ExchangeTokenResponse,
    AccountInfo,
    BalanceInfo,
    TransactionInfo,
    RecurringTransactionInfo,
    TransactionSyncResponse,
)
from app.services.banking.factory import (
    get_banking_provider,
    get_provider_for_region,
    get_supported_regions,
    is_region_supported,
)

__all__ = [
    # Base
    "BankingProvider",
    # Providers
    "PlaidProvider",
    "PlaidProviderError",
    "MonoProvider",
    "MonoProviderError",
    "StitchProvider",
    "StitchProviderError",
    # Schemas
    "LinkTokenResponse",
    "ExchangeTokenResponse",
    "AccountInfo",
    "BalanceInfo",
    "TransactionInfo",
    "RecurringTransactionInfo",
    "TransactionSyncResponse",
    # Factory
    "get_banking_provider",
    "get_provider_for_region",
    "get_supported_regions",
    "is_region_supported",
]
