import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../core/di/injection.dart';
import '../../../core/services/analytics_service.dart';
import '../../../data/models/bank_connection_model.dart';
import '../../../data/repositories/banking_repository.dart';
import 'banking_event.dart';
import 'banking_state.dart';

/// BLoC for banking state management (Pro feature)
@injectable
class BankingBloc extends Bloc<BankingEvent, BankingState> {
  final BankingRepository _bankingRepository;

  BankingBloc(this._bankingRepository) : super(const BankingInitial()) {
    on<BankingLoadRequested>(_onLoadRequested);
    on<BankingCreateLinkTokenRequested>(_onCreateLinkToken);
    on<BankingExchangeTokenRequested>(_onExchangeToken);
    on<BankingSyncTransactionsRequested>(_onSyncTransactions);
    on<BankingSyncBalancesRequested>(_onSyncBalances);
    on<BankingDisconnectRequested>(_onDisconnect);
    on<BankingClearError>(_onClearError);
    on<BankingRecurringLoadRequested>(_onRecurringLoadRequested);
    on<BankingConvertRecurringRequested>(_onConvertRecurring);
  }

  Future<void> _onLoadRequested(
    BankingLoadRequested event,
    Emitter<BankingState> emit,
  ) async {
    emit(const BankingLoading());

    try {
      final response = await _bankingRepository.getBankConnections();

      emit(BankingLoaded(
        connections: response.connections,
        totalBalance: response.totalBalance,
        accountCount: response.accountCount,
      ));
    } catch (e) {
      if (_isProRequired(e.toString())) {
        emit(const BankingProRequired(
          feature: 'Bank connection',
          currentTier: 'free',
        ));
      } else {
        emit(BankingError(message: e.toString()));
      }
    }
  }

  Future<void> _onCreateLinkToken(
    BankingCreateLinkTokenRequested event,
    Emitter<BankingState> emit,
  ) async {
    final previousState = state is BankingLoaded ? state as BankingLoaded : null;

    emit(BankingOperationInProgress(
      previousState: previousState,
      message: 'Preparing bank connection...',
    ));

    try {
      final linkToken = await _bankingRepository.createLinkToken(
        provider: event.provider,
      );

      emit(BankingLinkTokenReady(
        linkToken: linkToken,
        previousState: previousState,
      ));
    } catch (e) {
      if (_isProRequired(e.toString())) {
        emit(const BankingProRequired(
          feature: 'Bank connection',
          currentTier: 'free',
        ));
      } else {
        emit(BankingError(
          message: e.toString(),
          previousState: previousState,
        ));
      }
    }
  }

  Future<void> _onExchangeToken(
    BankingExchangeTokenRequested event,
    Emitter<BankingState> emit,
  ) async {
    final previousState = state is BankingLoaded ? state as BankingLoaded : null;

    emit(BankingOperationInProgress(
      previousState: previousState,
      message: 'Connecting bank account...',
    ));

    try {
      final connection = await _bankingRepository.exchangePublicToken(
        publicToken: event.publicToken,
        provider: event.provider,
      );

      getIt<AnalyticsService>().logBankConnected(provider: event.provider.name);
      emit(BankingConnectionSuccess(connection: connection));

      // Reload connections to update list
      add(const BankingLoadRequested());
    } catch (e) {
      emit(BankingError(
        message: e.toString(),
        previousState: previousState,
      ));
    }
  }

  Future<void> _onSyncTransactions(
    BankingSyncTransactionsRequested event,
    Emitter<BankingState> emit,
  ) async {
    final previousState = state is BankingLoaded ? state as BankingLoaded : null;

    emit(BankingOperationInProgress(
      previousState: previousState,
      message: 'Syncing transactions...',
    ));

    try {
      final result = await _bankingRepository.syncTransactions(
        event.connectionId,
      );

      emit(BankingSyncComplete(
        newTransactions: result.newTransactions,
        previousState: previousState,
      ));

      // Reload to get updated data
      add(const BankingLoadRequested());
    } catch (e) {
      emit(BankingError(
        message: e.toString(),
        previousState: previousState,
      ));
    }
  }

  Future<void> _onSyncBalances(
    BankingSyncBalancesRequested event,
    Emitter<BankingState> emit,
  ) async {
    final previousState = state is BankingLoaded ? state as BankingLoaded : null;

    emit(BankingOperationInProgress(
      previousState: previousState,
      message: 'Refreshing balances...',
    ));

    try {
      await _bankingRepository.syncBalances(event.connectionId);

      // Reload to get updated balances
      add(const BankingLoadRequested());
    } catch (e) {
      emit(BankingError(
        message: e.toString(),
        previousState: previousState,
      ));
    }
  }

  Future<void> _onDisconnect(
    BankingDisconnectRequested event,
    Emitter<BankingState> emit,
  ) async {
    final previousState = state is BankingLoaded ? state as BankingLoaded : null;

    emit(BankingOperationInProgress(
      previousState: previousState,
      message: 'Disconnecting bank...',
    ));

    try {
      await _bankingRepository.disconnectBank(event.connectionId);
      getIt<AnalyticsService>().logBankDisconnected();

      // Reload connections
      add(const BankingLoadRequested());
    } catch (e) {
      emit(BankingError(
        message: e.toString(),
        previousState: previousState,
      ));
    }
  }

  Future<void> _onClearError(
    BankingClearError event,
    Emitter<BankingState> emit,
  ) async {
    final currentState = state;
    if (currentState is BankingError && currentState.previousState != null) {
      emit(currentState.previousState!);
    } else {
      add(const BankingLoadRequested());
    }
  }

  Future<void> _onRecurringLoadRequested(
    BankingRecurringLoadRequested event,
    Emitter<BankingState> emit,
  ) async {
    final previousState =
        state is BankingLoaded ? state as BankingLoaded : null;

    emit(BankingOperationInProgress(
      previousState: previousState,
      message: 'Loading recurring transactions...',
    ));

    try {
      final response = await _bankingRepository.getRecurringTransactions(
        event.connectionId,
      );

      emit(BankingRecurringLoaded(
        connectionId: event.connectionId,
        recurringTransactions: response.recurringTransactions,
        count: response.count,
        previousState: previousState,
      ));
    } catch (e) {
      emit(BankingError(
        message: e.toString(),
        previousState: previousState,
      ));
    }
  }

  Future<void> _onConvertRecurring(
    BankingConvertRecurringRequested event,
    Emitter<BankingState> emit,
  ) async {
    final previousState =
        state is BankingLoaded ? state as BankingLoaded : null;

    emit(BankingOperationInProgress(
      previousState: previousState,
      message: 'Creating subscription...',
    ));

    try {
      final request = ConvertRecurringToSubscriptionRequest(
        streamId: event.streamId,
        name: event.name,
        amount: event.amount,
        billingCycle: event.billingCycle,
        nextBillingDate: event.nextBillingDate,
        color: event.color,
        description: event.description,
      );

      await _bankingRepository.convertRecurringToSubscription(
        connectionId: event.connectionId,
        request: request,
      );

      emit(BankingConversionSuccess(
        streamId: event.streamId,
        subscriptionName: event.name ?? 'Subscription',
      ));

      // Reload recurring transactions
      add(BankingRecurringLoadRequested(connectionId: event.connectionId));
    } catch (e) {
      emit(BankingError(
        message: e.toString(),
        previousState: previousState,
      ));
    }
  }

  bool _isProRequired(String error) {
    return error.contains('Pro subscription') ||
        error.contains('upgrade_required') ||
        error.contains('402');
  }
}
