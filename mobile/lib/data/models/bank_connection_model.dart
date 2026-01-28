/// Bank connection data models - matching backend schemas
/// NO dynamic, NO Object?, strictly typed

/// Banking provider types
enum BankingProvider {
  plaid,
  mono,
  stitch,
  truelayer,
  tink;

  String toJson() => name;

  static BankingProvider fromJson(String value) {
    return BankingProvider.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BankingProvider.plaid,
    );
  }
}

/// Bank connection status
enum BankConnectionStatus {
  pending,
  connected,
  error,
  disconnected,
  requiresReauth;

  String toJson() {
    if (this == BankConnectionStatus.requiresReauth) return 'requires_reauth';
    return name;
  }

  static BankConnectionStatus fromJson(String value) {
    if (value == 'requires_reauth') return BankConnectionStatus.requiresReauth;
    return BankConnectionStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BankConnectionStatus.pending,
    );
  }
}

/// Bank account type
enum BankAccountType {
  checking,
  savings,
  credit,
  loan,
  investment,
  other;

  String toJson() => name;

  static BankAccountType fromJson(String value) {
    return BankAccountType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BankAccountType.other,
    );
  }
}

/// Bank account model
class BankAccountModel {
  final String id;
  final String name;
  final String? officialName;
  final String? mask;
  final BankAccountType accountType;
  final String? accountSubtype;
  final double? currentBalance;
  final double? availableBalance;
  final double? limit;
  final String currency;
  final bool isActive;
  final bool isPrimary;
  final bool includeInPulse;
  final DateTime? balanceUpdatedAt;

  const BankAccountModel({
    required this.id,
    required this.name,
    this.officialName,
    this.mask,
    required this.accountType,
    this.accountSubtype,
    this.currentBalance,
    this.availableBalance,
    this.limit,
    required this.currency,
    required this.isActive,
    required this.isPrimary,
    required this.includeInPulse,
    this.balanceUpdatedAt,
  });

  factory BankAccountModel.fromJson(Map<String, dynamic> json) {
    return BankAccountModel(
      id: json['id'] as String,
      name: json['name'] as String,
      officialName: json['official_name'] as String?,
      mask: json['mask'] as String?,
      accountType: BankAccountType.fromJson(json['account_type'] as String),
      accountSubtype: json['account_subtype'] as String?,
      currentBalance: json['current_balance'] != null
          ? (json['current_balance'] as num).toDouble()
          : null,
      availableBalance: json['available_balance'] != null
          ? (json['available_balance'] as num).toDouble()
          : null,
      limit: json['limit'] != null ? (json['limit'] as num).toDouble() : null,
      currency: json['currency'] as String,
      isActive: json['is_active'] as bool,
      isPrimary: json['is_primary'] as bool,
      includeInPulse: json['include_in_pulse'] as bool,
      balanceUpdatedAt: json['balance_updated_at'] != null
          ? DateTime.parse(json['balance_updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'official_name': officialName,
        'mask': mask,
        'account_type': accountType.toJson(),
        'account_subtype': accountSubtype,
        'current_balance': currentBalance,
        'available_balance': availableBalance,
        'limit': limit,
        'currency': currency,
        'is_active': isActive,
        'is_primary': isPrimary,
        'include_in_pulse': includeInPulse,
        'balance_updated_at': balanceUpdatedAt?.toIso8601String(),
      };
}

/// Bank connection model
class BankConnectionModel {
  final String id;
  final BankingProvider provider;
  final String institutionName;
  final String? institutionLogo;
  final BankConnectionStatus status;
  final String? errorCode;
  final String? errorMessage;
  final DateTime? lastSyncAt;
  final List<BankAccountModel> accounts;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BankConnectionModel({
    required this.id,
    required this.provider,
    required this.institutionName,
    this.institutionLogo,
    required this.status,
    this.errorCode,
    this.errorMessage,
    this.lastSyncAt,
    required this.accounts,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BankConnectionModel.fromJson(Map<String, dynamic> json) {
    return BankConnectionModel(
      id: json['id'] as String,
      provider: BankingProvider.fromJson(json['provider'] as String),
      institutionName: json['institution_name'] as String,
      institutionLogo: json['institution_logo'] as String?,
      status: BankConnectionStatus.fromJson(json['status'] as String),
      errorCode: json['error_code'] as String?,
      errorMessage: json['error_message'] as String?,
      lastSyncAt: json['last_sync_at'] != null
          ? DateTime.parse(json['last_sync_at'] as String)
          : null,
      accounts: (json['accounts'] as List<dynamic>)
          .map((e) => BankAccountModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider.toJson(),
        'institution_name': institutionName,
        'institution_logo': institutionLogo,
        'status': status.toJson(),
        'error_code': errorCode,
        'error_message': errorMessage,
        'last_sync_at': lastSyncAt?.toIso8601String(),
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  /// Get total balance from all accounts included in pulse
  double get totalBalance {
    return accounts
        .where((a) => a.includeInPulse && a.isActive)
        .fold(0.0, (sum, a) => sum + (a.availableBalance ?? a.currentBalance ?? 0.0));
  }
}

/// Bank connection list response
class BankConnectionListResponse {
  final List<BankConnectionModel> connections;
  final double totalBalance;
  final int accountCount;

  const BankConnectionListResponse({
    required this.connections,
    required this.totalBalance,
    required this.accountCount,
  });

  factory BankConnectionListResponse.fromJson(Map<String, dynamic> json) {
    return BankConnectionListResponse(
      connections: (json['connections'] as List<dynamic>)
          .map((e) => BankConnectionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalBalance: (json['total_balance'] as num).toDouble(),
      accountCount: json['account_count'] as int,
    );
  }
}

/// Link token response
class LinkTokenResponse {
  final String linkToken;
  final String expiration;
  final String provider;

  const LinkTokenResponse({
    required this.linkToken,
    required this.expiration,
    required this.provider,
  });

  factory LinkTokenResponse.fromJson(Map<String, dynamic> json) {
    return LinkTokenResponse(
      linkToken: json['link_token'] as String,
      expiration: json['expiration'] as String,
      provider: json['provider'] as String,
    );
  }
}

/// Create link token request
class CreateLinkTokenRequest {
  final BankingProvider provider;

  const CreateLinkTokenRequest({
    this.provider = BankingProvider.plaid,
  });

  Map<String, dynamic> toJson() => {
        'provider': provider.toJson(),
      };
}

/// Exchange token request
class ExchangeTokenRequest {
  final String publicToken;
  final BankingProvider provider;

  const ExchangeTokenRequest({
    required this.publicToken,
    this.provider = BankingProvider.plaid,
  });

  Map<String, dynamic> toJson() => {
        'public_token': publicToken,
        'provider': provider.toJson(),
      };
}

/// Sync transactions response
class SyncTransactionsResponse {
  final int newTransactions;
  final String connectionId;

  const SyncTransactionsResponse({
    required this.newTransactions,
    required this.connectionId,
  });

  factory SyncTransactionsResponse.fromJson(Map<String, dynamic> json) {
    return SyncTransactionsResponse(
      newTransactions: json['new_transactions'] as int,
      connectionId: json['connection_id'] as String,
    );
  }
}

/// Transaction model
class TransactionModel {
  final String id;
  final String accountId;
  final String name;
  final String? merchantName;
  final double amount;
  final String currency;
  final String transactionType;
  final DateTime transactionDate;
  final DateTime? postedDate;
  final String? category;
  final bool isRecurring;
  final bool isSubscription;
  final bool isPending;
  final String? logoUrl;

  const TransactionModel({
    required this.id,
    required this.accountId,
    required this.name,
    this.merchantName,
    required this.amount,
    required this.currency,
    required this.transactionType,
    required this.transactionDate,
    this.postedDate,
    this.category,
    required this.isRecurring,
    required this.isSubscription,
    required this.isPending,
    this.logoUrl,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      name: json['name'] as String,
      merchantName: json['merchant_name'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      transactionType: json['transaction_type'] as String,
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      postedDate: json['posted_date'] != null
          ? DateTime.parse(json['posted_date'] as String)
          : null,
      category: json['category'] as String?,
      isRecurring: json['is_recurring'] as bool,
      isSubscription: json['is_subscription'] as bool,
      isPending: json['is_pending'] as bool,
      logoUrl: json['logo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'account_id': accountId,
        'name': name,
        'merchant_name': merchantName,
        'amount': amount,
        'currency': currency,
        'transaction_type': transactionType,
        'transaction_date': transactionDate.toIso8601String().split('T')[0],
        'posted_date': postedDate?.toIso8601String().split('T')[0],
        'category': category,
        'is_recurring': isRecurring,
        'is_subscription': isSubscription,
        'is_pending': isPending,
        'logo_url': logoUrl,
      };
}

/// Recurring transaction model (detected by bank provider)
class RecurringTransactionModel {
  final String streamId;
  final String accountId;
  final String description;
  final String? merchantName;
  final double averageAmount;
  final String currency;
  final String frequency;
  final String lastDate;
  final String? nextExpectedDate;
  final bool isActive;

  const RecurringTransactionModel({
    required this.streamId,
    required this.accountId,
    required this.description,
    this.merchantName,
    required this.averageAmount,
    required this.currency,
    required this.frequency,
    required this.lastDate,
    this.nextExpectedDate,
    required this.isActive,
  });

  factory RecurringTransactionModel.fromJson(Map<String, dynamic> json) {
    return RecurringTransactionModel(
      streamId: json['stream_id'] as String,
      accountId: json['account_id'] as String,
      description: json['description'] as String,
      merchantName: json['merchant_name'] as String?,
      averageAmount: (json['average_amount'] as num).toDouble(),
      currency: json['currency'] as String,
      frequency: json['frequency'] as String,
      lastDate: json['last_date'] as String,
      nextExpectedDate: json['next_expected_date'] as String?,
      isActive: json['is_active'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'stream_id': streamId,
        'account_id': accountId,
        'description': description,
        'merchant_name': merchantName,
        'average_amount': averageAmount,
        'currency': currency,
        'frequency': frequency,
        'last_date': lastDate,
        'next_expected_date': nextExpectedDate,
        'is_active': isActive,
      };

  /// Display name (merchant name or description)
  String get displayName => merchantName ?? description;

  /// Human readable frequency
  String get frequencyDisplay {
    switch (frequency.toUpperCase()) {
      case 'WEEKLY':
        return 'Weekly';
      case 'BIWEEKLY':
        return 'Every 2 weeks';
      case 'SEMI_MONTHLY':
        return 'Twice a month';
      case 'MONTHLY':
        return 'Monthly';
      case 'ANNUALLY':
        return 'Yearly';
      case 'QUARTERLY':
        return 'Quarterly';
      default:
        return frequency;
    }
  }
}

/// Recurring transactions list response
class RecurringTransactionsResponse {
  final List<RecurringTransactionModel> recurringTransactions;
  final int count;

  const RecurringTransactionsResponse({
    required this.recurringTransactions,
    required this.count,
  });

  factory RecurringTransactionsResponse.fromJson(Map<String, dynamic> json) {
    return RecurringTransactionsResponse(
      recurringTransactions: (json['recurring_transactions'] as List<dynamic>)
          .map((e) =>
              RecurringTransactionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: json['count'] as int,
    );
  }
}

/// Request to convert recurring transaction to subscription
class ConvertRecurringToSubscriptionRequest {
  final String streamId;
  final String? name;
  final double? amount;
  final String? billingCycle;
  final DateTime? nextBillingDate;
  final String? color;
  final String? description;

  const ConvertRecurringToSubscriptionRequest({
    required this.streamId,
    this.name,
    this.amount,
    this.billingCycle,
    this.nextBillingDate,
    this.color,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'stream_id': streamId,
        if (name != null) 'name': name,
        if (amount != null) 'amount': amount,
        if (billingCycle != null) 'billing_cycle': billingCycle,
        if (nextBillingDate != null)
          'next_billing_date': nextBillingDate!.toIso8601String(),
        if (color != null) 'color': color,
        if (description != null) 'description': description,
      };
}
