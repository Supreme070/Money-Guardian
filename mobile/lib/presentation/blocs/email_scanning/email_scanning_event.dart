import '../../../data/models/email_connection_model.dart';

/// Email scanning BLoC events
sealed class EmailScanningEvent {
  const EmailScanningEvent();
}

/// Load all email connections
class EmailLoadRequested extends EmailScanningEvent {
  const EmailLoadRequested();
}

/// Start OAuth flow to connect email
class EmailConnectRequested extends EmailScanningEvent {
  final EmailProvider provider;
  final String redirectUri;

  const EmailConnectRequested({
    required this.provider,
    required this.redirectUri,
  });
}

/// Complete OAuth flow with authorization code
class EmailOAuthCompleteRequested extends EmailScanningEvent {
  final EmailProvider provider;
  final String code;
  final String redirectUri;
  final String? state;

  const EmailOAuthCompleteRequested({
    required this.provider,
    required this.code,
    required this.redirectUri,
    this.state,
  });
}

/// Scan emails for subscriptions
class EmailScanRequested extends EmailScanningEvent {
  final String connectionId;
  final int maxEmails;

  const EmailScanRequested({
    required this.connectionId,
    this.maxEmails = 50,
  });
}

/// Load scanned emails with detections
class EmailScannedLoadRequested extends EmailScanningEvent {
  final String connectionId;
  final bool unprocessedOnly;
  final double minConfidence;

  const EmailScannedLoadRequested({
    required this.connectionId,
    this.unprocessedOnly = false,
    this.minConfidence = 0.5,
  });
}

/// Mark a scanned email as processed
class EmailMarkProcessedRequested extends EmailScanningEvent {
  final String connectionId;
  final String emailId;
  final String? subscriptionId;

  const EmailMarkProcessedRequested({
    required this.connectionId,
    required this.emailId,
    this.subscriptionId,
  });
}

/// Disconnect an email connection
class EmailDisconnectRequested extends EmailScanningEvent {
  final String connectionId;

  const EmailDisconnectRequested({
    required this.connectionId,
  });
}

/// Clear error state
class EmailClearError extends EmailScanningEvent {
  const EmailClearError();
}

/// Convert a scanned email to a subscription
class EmailConvertRequested extends EmailScanningEvent {
  final String connectionId;
  final String emailId;
  final String? name;
  final double? amount;
  final String? billingCycle;
  final DateTime? nextBillingDate;
  final String? color;
  final String? description;

  const EmailConvertRequested({
    required this.connectionId,
    required this.emailId,
    this.name,
    this.amount,
    this.billingCycle,
    this.nextBillingDate,
    this.color,
    this.description,
  });
}
