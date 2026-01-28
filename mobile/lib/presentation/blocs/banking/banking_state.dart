import '../../../data/models/bank_connection_model.dart';

/// Banking BLoC states
sealed class BankingState {
  const BankingState();
}

/// Initial state
class BankingInitial extends BankingState {
  const BankingInitial();
}

/// Loading bank connections
class BankingLoading extends BankingState {
  const BankingLoading();
}

/// Bank connections loaded successfully
class BankingLoaded extends BankingState {
  final List<BankConnectionModel> connections;
  final double totalBalance;
  final int accountCount;

  const BankingLoaded({
    required this.connections,
    required this.totalBalance,
    required this.accountCount,
  });

  /// Check if user has any bank connections
  bool get hasConnections => connections.isNotEmpty;

  /// Check if any connection has an error
  bool get hasError => connections.any(
        (c) => c.status == BankConnectionStatus.error,
      );

  /// Check if any connection requires re-authentication
  bool get requiresReauth => connections.any(
        (c) => c.status == BankConnectionStatus.requiresReauth,
      );
}

/// Link token created, ready to open Plaid Link
class BankingLinkTokenReady extends BankingState {
  final LinkTokenResponse linkToken;
  final BankingLoaded? previousState;

  const BankingLinkTokenReady({
    required this.linkToken,
    this.previousState,
  });
}

/// Operation in progress (syncing, connecting, etc.)
class BankingOperationInProgress extends BankingState {
  final BankingLoaded? previousState;
  final String message;

  const BankingOperationInProgress({
    this.previousState,
    this.message = 'Processing...',
  });
}

/// Bank connection successful
class BankingConnectionSuccess extends BankingState {
  final BankConnectionModel connection;

  const BankingConnectionSuccess({
    required this.connection,
  });
}

/// Sync completed
class BankingSyncComplete extends BankingState {
  final int newTransactions;
  final BankingLoaded? previousState;

  const BankingSyncComplete({
    required this.newTransactions,
    this.previousState,
  });
}

/// Error state
class BankingError extends BankingState {
  final String message;
  final bool upgradeRequired;
  final BankingLoaded? previousState;

  const BankingError({
    required this.message,
    this.upgradeRequired = false,
    this.previousState,
  });
}

/// Pro feature required
class BankingProRequired extends BankingState {
  final String feature;
  final String currentTier;

  const BankingProRequired({
    required this.feature,
    required this.currentTier,
  });
}

/// Recurring transactions loaded
class BankingRecurringLoaded extends BankingState {
  final String connectionId;
  final List<RecurringTransactionModel> recurringTransactions;
  final int count;
  final BankingLoaded? previousState;

  const BankingRecurringLoaded({
    required this.connectionId,
    required this.recurringTransactions,
    required this.count,
    this.previousState,
  });

  /// Check if there are any active recurring transactions
  bool get hasActiveRecurring =>
      recurringTransactions.any((r) => r.isActive);
}

/// Recurring transaction successfully converted to subscription
class BankingConversionSuccess extends BankingState {
  final String streamId;
  final String subscriptionName;

  const BankingConversionSuccess({
    required this.streamId,
    required this.subscriptionName,
  });
}
