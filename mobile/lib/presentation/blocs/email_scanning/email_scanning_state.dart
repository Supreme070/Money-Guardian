import '../../../data/models/email_connection_model.dart';

/// Email scanning BLoC states
sealed class EmailScanningState {
  const EmailScanningState();
}

/// Initial state
class EmailScanningInitial extends EmailScanningState {
  const EmailScanningInitial();
}

/// Loading email connections
class EmailScanningLoading extends EmailScanningState {
  const EmailScanningLoading();
}

/// Email connections loaded successfully
class EmailScanningLoaded extends EmailScanningState {
  final List<EmailConnectionModel> connections;
  final List<ScannedEmailModel>? scannedEmails;

  const EmailScanningLoaded({
    required this.connections,
    this.scannedEmails,
  });

  /// Check if user has any email connections
  bool get hasConnections => connections.isNotEmpty;

  /// Check if any connection has an error
  bool get hasError => connections.any(
        (c) => c.status == EmailConnectionStatus.error,
      );

  /// Check if any connection requires re-authentication
  bool get requiresReauth => connections.any(
        (c) => c.status == EmailConnectionStatus.requiresReauth,
      );

  /// Get count of unprocessed emails with high confidence
  int get unprocessedCount =>
      scannedEmails?.where((e) => !e.isProcessed && e.confidenceScore >= 0.5).length ?? 0;
}

/// OAuth URL ready, redirect user to provider
class EmailOAuthReady extends EmailScanningState {
  final OAuthUrlResponse oauthUrl;
  final EmailScanningLoaded? previousState;

  const EmailOAuthReady({
    required this.oauthUrl,
    this.previousState,
  });
}

/// Operation in progress
class EmailScanningOperationInProgress extends EmailScanningState {
  final EmailScanningLoaded? previousState;
  final String message;

  const EmailScanningOperationInProgress({
    this.previousState,
    this.message = 'Processing...',
  });
}

/// Email connection successful
class EmailConnectionSuccess extends EmailScanningState {
  final EmailConnectionModel connection;

  const EmailConnectionSuccess({
    required this.connection,
  });
}

/// Scan completed
class EmailScanComplete extends EmailScanningState {
  final int emailsScanned;
  final int subscriptionsDetected;
  final bool hasMore;
  final EmailScanningLoaded? previousState;

  const EmailScanComplete({
    required this.emailsScanned,
    required this.subscriptionsDetected,
    required this.hasMore,
    this.previousState,
  });
}

/// Error state
class EmailScanningError extends EmailScanningState {
  final String message;
  final bool upgradeRequired;
  final EmailScanningLoaded? previousState;

  const EmailScanningError({
    required this.message,
    this.upgradeRequired = false,
    this.previousState,
  });
}

/// Pro feature required
class EmailScanningProRequired extends EmailScanningState {
  final String feature;
  final String currentTier;

  const EmailScanningProRequired({
    required this.feature,
    required this.currentTier,
  });
}

/// Scanned emails loaded
class EmailScannedLoaded extends EmailScanningState {
  final List<ScannedEmailModel> emails;
  final int count;
  final bool hasMore;

  const EmailScannedLoaded({
    required this.emails,
    required this.count,
    required this.hasMore,
  });
}

/// Email successfully converted to subscription
class EmailConversionSuccess extends EmailScanningState {
  final String subscriptionId;
  final String subscriptionName;

  const EmailConversionSuccess({
    required this.subscriptionId,
    required this.subscriptionName,
  });
}
