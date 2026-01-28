/// Email connection data models - matching backend schemas
/// NO dynamic, NO Object?, strictly typed

/// Email provider types
enum EmailProvider {
  gmail,
  outlook,
  yahoo;

  String toJson() => name;

  static EmailProvider fromJson(String value) {
    return EmailProvider.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EmailProvider.gmail,
    );
  }
}

/// Email connection status
enum EmailConnectionStatus {
  pending,
  connected,
  error,
  disconnected,
  requiresReauth;

  String toJson() {
    if (this == EmailConnectionStatus.requiresReauth) return 'requires_reauth';
    return name;
  }

  static EmailConnectionStatus fromJson(String value) {
    if (value == 'requires_reauth') return EmailConnectionStatus.requiresReauth;
    return EmailConnectionStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EmailConnectionStatus.pending,
    );
  }
}

/// Email type for subscription detection
enum EmailType {
  subscriptionConfirmation,
  receipt,
  billingReminder,
  priceChange,
  trialEnding,
  paymentFailed,
  cancellation,
  renewalNotice,
  other;

  String toJson() {
    switch (this) {
      case EmailType.subscriptionConfirmation:
        return 'subscription_confirmation';
      case EmailType.billingReminder:
        return 'billing_reminder';
      case EmailType.priceChange:
        return 'price_change';
      case EmailType.trialEnding:
        return 'trial_ending';
      case EmailType.paymentFailed:
        return 'payment_failed';
      case EmailType.renewalNotice:
        return 'renewal_notice';
      default:
        return name;
    }
  }

  static EmailType fromJson(String value) {
    switch (value) {
      case 'subscription_confirmation':
        return EmailType.subscriptionConfirmation;
      case 'billing_reminder':
        return EmailType.billingReminder;
      case 'price_change':
        return EmailType.priceChange;
      case 'trial_ending':
        return EmailType.trialEnding;
      case 'payment_failed':
        return EmailType.paymentFailed;
      case 'renewal_notice':
        return EmailType.renewalNotice;
      default:
        return EmailType.values.firstWhere(
          (e) => e.name == value,
          orElse: () => EmailType.other,
        );
    }
  }
}

/// Email connection model
class EmailConnectionModel {
  final String id;
  final EmailProvider provider;
  final String emailAddress;
  final EmailConnectionStatus status;
  final String? errorMessage;
  final DateTime? lastScanAt;
  final DateTime? lastSuccessfulScanAt;
  final int scanDepthDays;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmailConnectionModel({
    required this.id,
    required this.provider,
    required this.emailAddress,
    required this.status,
    this.errorMessage,
    this.lastScanAt,
    this.lastSuccessfulScanAt,
    required this.scanDepthDays,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmailConnectionModel.fromJson(Map<String, dynamic> json) {
    return EmailConnectionModel(
      id: json['id'] as String,
      provider: EmailProvider.fromJson(json['provider'] as String),
      emailAddress: json['email_address'] as String,
      status: EmailConnectionStatus.fromJson(json['status'] as String),
      errorMessage: json['error_message'] as String?,
      lastScanAt: json['last_scan_at'] != null
          ? DateTime.parse(json['last_scan_at'] as String)
          : null,
      lastSuccessfulScanAt: json['last_successful_scan_at'] != null
          ? DateTime.parse(json['last_successful_scan_at'] as String)
          : null,
      scanDepthDays: json['scan_depth_days'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider.toJson(),
        'email_address': emailAddress,
        'status': status.toJson(),
        'error_message': errorMessage,
        'last_scan_at': lastScanAt?.toIso8601String(),
        'last_successful_scan_at': lastSuccessfulScanAt?.toIso8601String(),
        'scan_depth_days': scanDepthDays,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// Email connection list response
class EmailConnectionListResponse {
  final List<EmailConnectionModel> connections;
  final int count;

  const EmailConnectionListResponse({
    required this.connections,
    required this.count,
  });

  factory EmailConnectionListResponse.fromJson(Map<String, dynamic> json) {
    return EmailConnectionListResponse(
      connections: (json['connections'] as List<dynamic>)
          .map((e) => EmailConnectionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: json['count'] as int,
    );
  }
}

/// Scanned email model
class ScannedEmailModel {
  final String id;
  final String connectionId;
  final String providerMessageId;
  final String fromAddress;
  final String? fromName;
  final String subject;
  final DateTime receivedAt;
  final EmailType emailType;
  final double confidenceScore;
  final String? merchantName;
  final double? detectedAmount;
  final String? currency;
  final String? billingCycle;
  final DateTime? nextBillingDate;
  final bool isProcessed;
  final bool isSubscriptionCreated;
  final String? subscriptionId;

  const ScannedEmailModel({
    required this.id,
    required this.connectionId,
    required this.providerMessageId,
    required this.fromAddress,
    this.fromName,
    required this.subject,
    required this.receivedAt,
    required this.emailType,
    required this.confidenceScore,
    this.merchantName,
    this.detectedAmount,
    this.currency,
    this.billingCycle,
    this.nextBillingDate,
    required this.isProcessed,
    required this.isSubscriptionCreated,
    this.subscriptionId,
  });

  factory ScannedEmailModel.fromJson(Map<String, dynamic> json) {
    return ScannedEmailModel(
      id: json['id'] as String,
      connectionId: json['connection_id'] as String,
      providerMessageId: json['provider_message_id'] as String,
      fromAddress: json['from_address'] as String,
      fromName: json['from_name'] as String?,
      subject: json['subject'] as String,
      receivedAt: DateTime.parse(json['received_at'] as String),
      emailType: EmailType.fromJson(json['email_type'] as String),
      confidenceScore: (json['confidence_score'] as num).toDouble(),
      merchantName: json['merchant_name'] as String?,
      detectedAmount: json['detected_amount'] != null
          ? (json['detected_amount'] as num).toDouble()
          : null,
      currency: json['currency'] as String?,
      billingCycle: json['billing_cycle'] as String?,
      nextBillingDate: json['next_billing_date'] != null
          ? DateTime.parse(json['next_billing_date'] as String)
          : null,
      isProcessed: json['is_processed'] as bool,
      isSubscriptionCreated: json['is_subscription_created'] as bool,
      subscriptionId: json['subscription_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'connection_id': connectionId,
        'provider_message_id': providerMessageId,
        'from_address': fromAddress,
        'from_name': fromName,
        'subject': subject,
        'received_at': receivedAt.toIso8601String(),
        'email_type': emailType.toJson(),
        'confidence_score': confidenceScore,
        'merchant_name': merchantName,
        'detected_amount': detectedAmount,
        'currency': currency,
        'billing_cycle': billingCycle,
        'next_billing_date': nextBillingDate?.toIso8601String(),
        'is_processed': isProcessed,
        'is_subscription_created': isSubscriptionCreated,
        'subscription_id': subscriptionId,
      };
}

/// Scanned email list response
class ScannedEmailListResponse {
  final List<ScannedEmailModel> emails;
  final int count;
  final bool hasMore;

  const ScannedEmailListResponse({
    required this.emails,
    required this.count,
    required this.hasMore,
  });

  factory ScannedEmailListResponse.fromJson(Map<String, dynamic> json) {
    return ScannedEmailListResponse(
      emails: (json['emails'] as List<dynamic>)
          .map((e) => ScannedEmailModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: json['count'] as int,
      hasMore: json['has_more'] as bool,
    );
  }
}

/// OAuth URL response
class OAuthUrlResponse {
  final String authorizationUrl;
  final String state;
  final EmailProvider provider;

  const OAuthUrlResponse({
    required this.authorizationUrl,
    required this.state,
    required this.provider,
  });

  factory OAuthUrlResponse.fromJson(Map<String, dynamic> json) {
    return OAuthUrlResponse(
      authorizationUrl: json['authorization_url'] as String,
      state: json['state'] as String,
      provider: EmailProvider.fromJson(json['provider'] as String),
    );
  }
}

/// Start OAuth request
class StartOAuthRequest {
  final EmailProvider provider;
  final String redirectUri;

  const StartOAuthRequest({
    required this.provider,
    required this.redirectUri,
  });

  Map<String, dynamic> toJson() => {
        'provider': provider.toJson(),
        'redirect_uri': redirectUri,
      };
}

/// Complete OAuth request
class CompleteOAuthRequest {
  final EmailProvider provider;
  final String code;
  final String redirectUri;
  final String? state;

  const CompleteOAuthRequest({
    required this.provider,
    required this.code,
    required this.redirectUri,
    this.state,
  });

  Map<String, dynamic> toJson() => {
        'provider': provider.toJson(),
        'code': code,
        'redirect_uri': redirectUri,
        if (state != null) 'state': state,
      };
}

/// Scan emails request
class ScanEmailsRequest {
  final int maxEmails;

  const ScanEmailsRequest({
    this.maxEmails = 50,
  });

  Map<String, dynamic> toJson() => {
        'max_emails': maxEmails,
      };
}

/// Scan result response
class ScanResultResponse {
  final String connectionId;
  final int emailsScanned;
  final int subscriptionsDetected;
  final bool hasMore;

  const ScanResultResponse({
    required this.connectionId,
    required this.emailsScanned,
    required this.subscriptionsDetected,
    required this.hasMore,
  });

  factory ScanResultResponse.fromJson(Map<String, dynamic> json) {
    return ScanResultResponse(
      connectionId: json['connection_id'] as String,
      emailsScanned: json['emails_scanned'] as int,
      subscriptionsDetected: json['subscriptions_detected'] as int,
      hasMore: json['has_more'] as bool,
    );
  }
}

/// Known sender model
class KnownSenderModel {
  final String domain;
  final String name;
  final String category;
  final String? logoUrl;

  const KnownSenderModel({
    required this.domain,
    required this.name,
    required this.category,
    this.logoUrl,
  });

  factory KnownSenderModel.fromJson(Map<String, dynamic> json) {
    return KnownSenderModel(
      domain: json['domain'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      logoUrl: json['logo_url'] as String?,
    );
  }
}

/// Request to convert a scanned email to a subscription
class ConvertToSubscriptionRequest {
  final String? name;
  final double? amount;
  final String? billingCycle;
  final DateTime? nextBillingDate;
  final String? color;
  final String? description;

  const ConvertToSubscriptionRequest({
    this.name,
    this.amount,
    this.billingCycle,
    this.nextBillingDate,
    this.color,
    this.description,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (amount != null) data['amount'] = amount;
    if (billingCycle != null) data['billing_cycle'] = billingCycle;
    if (nextBillingDate != null) {
      data['next_billing_date'] = nextBillingDate!.toIso8601String();
    }
    if (color != null) data['color'] = color;
    if (description != null) data['description'] = description;
    return data;
  }
}
