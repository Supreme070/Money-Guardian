import '../../../data/models/bank_connection_model.dart';

/// Banking BLoC events
sealed class BankingEvent {
  const BankingEvent();
}

/// Load all bank connections
class BankingLoadRequested extends BankingEvent {
  const BankingLoadRequested();
}

/// Create link token for initiating bank connection
class BankingCreateLinkTokenRequested extends BankingEvent {
  final BankingProvider provider;

  const BankingCreateLinkTokenRequested({
    this.provider = BankingProvider.plaid,
  });
}

/// Exchange public token after successful Link completion
class BankingExchangeTokenRequested extends BankingEvent {
  final String publicToken;
  final BankingProvider provider;

  const BankingExchangeTokenRequested({
    required this.publicToken,
    this.provider = BankingProvider.plaid,
  });
}

/// Sync transactions for a connection
class BankingSyncTransactionsRequested extends BankingEvent {
  final String connectionId;

  const BankingSyncTransactionsRequested({
    required this.connectionId,
  });
}

/// Sync balances for a connection
class BankingSyncBalancesRequested extends BankingEvent {
  final String connectionId;

  const BankingSyncBalancesRequested({
    required this.connectionId,
  });
}

/// Disconnect a bank connection
class BankingDisconnectRequested extends BankingEvent {
  final String connectionId;

  const BankingDisconnectRequested({
    required this.connectionId,
  });
}

/// Clear error state
class BankingClearError extends BankingEvent {
  const BankingClearError();
}

/// Load recurring transactions for a connection
class BankingRecurringLoadRequested extends BankingEvent {
  final String connectionId;

  const BankingRecurringLoadRequested({
    required this.connectionId,
  });
}

/// Convert a recurring transaction to subscription
class BankingConvertRecurringRequested extends BankingEvent {
  final String connectionId;
  final String streamId;
  final String? name;
  final double? amount;
  final String? billingCycle;
  final DateTime? nextBillingDate;
  final String? color;
  final String? description;

  const BankingConvertRecurringRequested({
    required this.connectionId,
    required this.streamId,
    this.name,
    this.amount,
    this.billingCycle,
    this.nextBillingDate,
    this.color,
    this.description,
  });
}
