import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../core/di/injection.dart';
import '../../../core/services/analytics_service.dart';
import '../../../data/repositories/email_repository.dart';
import 'email_scanning_event.dart';
import 'email_scanning_state.dart';

/// BLoC for email scanning state management (Pro feature)
@injectable
class EmailScanningBloc extends Bloc<EmailScanningEvent, EmailScanningState> {
  final EmailRepository _emailRepository;

  EmailScanningBloc(this._emailRepository)
      : super(const EmailScanningInitial()) {
    on<EmailLoadRequested>(_onLoadRequested);
    on<EmailConnectRequested>(_onConnectRequested);
    on<EmailOAuthCompleteRequested>(_onOAuthComplete);
    on<EmailScanRequested>(_onScanRequested);
    on<EmailScannedLoadRequested>(_onScannedLoadRequested);
    on<EmailMarkProcessedRequested>(_onMarkProcessed);
    on<EmailDisconnectRequested>(_onDisconnect);
    on<EmailClearError>(_onClearError);
    on<EmailConvertRequested>(_onConvertRequested);
  }

  Future<void> _onLoadRequested(
    EmailLoadRequested event,
    Emitter<EmailScanningState> emit,
  ) async {
    emit(const EmailScanningLoading());

    try {
      final response = await _emailRepository.getEmailConnections();

      emit(EmailScanningLoaded(
        connections: response.connections,
      ));
    } catch (e) {
      if (_isProRequired(e.toString())) {
        emit(const EmailScanningProRequired(
          feature: 'Email scanning',
          currentTier: 'free',
        ));
      } else {
        emit(EmailScanningError(message: e.toString()));
      }
    }
  }

  Future<void> _onConnectRequested(
    EmailConnectRequested event,
    Emitter<EmailScanningState> emit,
  ) async {
    final previousState =
        state is EmailScanningLoaded ? state as EmailScanningLoaded : null;

    emit(EmailScanningOperationInProgress(
      previousState: previousState,
      message: 'Preparing email connection...',
    ));

    try {
      final oauthUrl = await _emailRepository.startOAuthFlow(
        provider: event.provider,
        redirectUri: event.redirectUri,
      );

      emit(EmailOAuthReady(
        oauthUrl: oauthUrl,
        previousState: previousState,
      ));
    } catch (e) {
      if (_isProRequired(e.toString())) {
        emit(const EmailScanningProRequired(
          feature: 'Email scanning',
          currentTier: 'free',
        ));
      } else {
        emit(EmailScanningError(
          message: e.toString(),
          previousState: previousState,
        ));
      }
    }
  }

  Future<void> _onOAuthComplete(
    EmailOAuthCompleteRequested event,
    Emitter<EmailScanningState> emit,
  ) async {
    final previousState =
        state is EmailScanningLoaded ? state as EmailScanningLoaded : null;

    emit(EmailScanningOperationInProgress(
      previousState: previousState,
      message: 'Connecting email account...',
    ));

    try {
      final connection = await _emailRepository.completeOAuthFlow(
        provider: event.provider,
        code: event.code,
        redirectUri: event.redirectUri,
        state: event.state,
      );

      getIt<AnalyticsService>().logEmailConnected(provider: event.provider.name);
      emit(EmailConnectionSuccess(connection: connection));

      // Reload connections to update list
      add(const EmailLoadRequested());
    } catch (e) {
      emit(EmailScanningError(
        message: e.toString(),
        previousState: previousState,
      ));
    }
  }

  Future<void> _onScanRequested(
    EmailScanRequested event,
    Emitter<EmailScanningState> emit,
  ) async {
    final previousState =
        state is EmailScanningLoaded ? state as EmailScanningLoaded : null;

    emit(EmailScanningOperationInProgress(
      previousState: previousState,
      message: 'Scanning emails for subscriptions...',
    ));

    try {
      final result = await _emailRepository.scanEmails(
        event.connectionId,
        maxEmails: event.maxEmails,
      );

      getIt<AnalyticsService>().logEmailScanCompleted(subscriptionsFound: result.subscriptionsDetected);
      emit(EmailScanComplete(
        emailsScanned: result.emailsScanned,
        subscriptionsDetected: result.subscriptionsDetected,
        hasMore: result.hasMore,
        previousState: previousState,
      ));

      // Load scanned emails
      add(EmailScannedLoadRequested(
        connectionId: event.connectionId,
        unprocessedOnly: true,
      ));
    } catch (e) {
      emit(EmailScanningError(
        message: e.toString(),
        previousState: previousState,
      ));
    }
  }

  Future<void> _onScannedLoadRequested(
    EmailScannedLoadRequested event,
    Emitter<EmailScanningState> emit,
  ) async {
    final currentState = state;
    EmailScanningLoaded? loadedState;

    if (currentState is EmailScanningLoaded) {
      loadedState = currentState;
    } else if (currentState is EmailScanComplete) {
      loadedState = currentState.previousState;
    }

    try {
      final response = await _emailRepository.getScannedEmails(
        event.connectionId,
        unprocessedOnly: event.unprocessedOnly,
        minConfidence: event.minConfidence,
      );

      emit(EmailScanningLoaded(
        connections: loadedState?.connections ?? [],
        scannedEmails: response.emails,
      ));
    } catch (e) {
      emit(EmailScanningError(
        message: e.toString(),
        previousState: loadedState,
      ));
    }
  }

  Future<void> _onMarkProcessed(
    EmailMarkProcessedRequested event,
    Emitter<EmailScanningState> emit,
  ) async {
    final previousState =
        state is EmailScanningLoaded ? state as EmailScanningLoaded : null;

    try {
      await _emailRepository.markEmailProcessed(
        event.connectionId,
        event.emailId,
        subscriptionId: event.subscriptionId,
      );

      // Reload scanned emails
      add(EmailScannedLoadRequested(
        connectionId: event.connectionId,
        unprocessedOnly: true,
      ));
    } catch (e) {
      emit(EmailScanningError(
        message: e.toString(),
        previousState: previousState,
      ));
    }
  }

  Future<void> _onDisconnect(
    EmailDisconnectRequested event,
    Emitter<EmailScanningState> emit,
  ) async {
    final previousState =
        state is EmailScanningLoaded ? state as EmailScanningLoaded : null;

    emit(EmailScanningOperationInProgress(
      previousState: previousState,
      message: 'Disconnecting email...',
    ));

    try {
      await _emailRepository.disconnectEmail(event.connectionId);

      // Reload connections
      add(const EmailLoadRequested());
    } catch (e) {
      emit(EmailScanningError(
        message: e.toString(),
        previousState: previousState,
      ));
    }
  }

  Future<void> _onClearError(
    EmailClearError event,
    Emitter<EmailScanningState> emit,
  ) async {
    final currentState = state;
    if (currentState is EmailScanningError &&
        currentState.previousState != null) {
      emit(currentState.previousState!);
    } else {
      add(const EmailLoadRequested());
    }
  }

  Future<void> _onConvertRequested(
    EmailConvertRequested event,
    Emitter<EmailScanningState> emit,
  ) async {
    final previousState =
        state is EmailScanningLoaded ? state as EmailScanningLoaded : null;

    emit(EmailScanningOperationInProgress(
      previousState: previousState,
      message: 'Creating subscription...',
    ));

    try {
      final subscription = await _emailRepository.convertEmailToSubscription(
        event.connectionId,
        event.emailId,
        name: event.name,
        amount: event.amount,
        billingCycle: event.billingCycle,
        nextBillingDate: event.nextBillingDate,
        color: event.color,
        description: event.description,
      );

      emit(EmailConversionSuccess(
        subscriptionId: subscription.id,
        subscriptionName: subscription.name,
      ));

      // Reload scanned emails to show updated status
      add(EmailScannedLoadRequested(
        connectionId: event.connectionId,
        unprocessedOnly: false,
      ));
    } catch (e) {
      emit(EmailScanningError(
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
