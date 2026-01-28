/// Subscription data models - matching backend Pydantic schemas
/// NO dynamic, NO Object?, strictly typed

/// Billing cycle options - matching backend BillingCycleType
enum BillingCycle {
  weekly,
  monthly,
  quarterly,
  yearly;

  String toJson() => name;

  static BillingCycle fromJson(String value) {
    return BillingCycle.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BillingCycle.monthly,
    );
  }
}

/// AI flag types - matching backend AIFlagType
enum AIFlag {
  none,
  unused,
  duplicate,
  priceIncrease,
  trialEnding,
  forgotten;

  String toJson() {
    switch (this) {
      case AIFlag.priceIncrease:
        return 'price_increase';
      case AIFlag.trialEnding:
        return 'trial_ending';
      default:
        return name;
    }
  }

  static AIFlag fromJson(String value) {
    switch (value) {
      case 'price_increase':
        return AIFlag.priceIncrease;
      case 'trial_ending':
        return AIFlag.trialEnding;
      default:
        return AIFlag.values.firstWhere(
          (e) => e.name == value,
          orElse: () => AIFlag.none,
        );
    }
  }
}

/// Source types - matching backend SourceType
enum SubscriptionSource {
  manual,
  plaid,
  gmail,
  aiDetected;

  String toJson() {
    if (this == SubscriptionSource.aiDetected) return 'ai_detected';
    return name;
  }

  static SubscriptionSource fromJson(String value) {
    if (value == 'ai_detected') return SubscriptionSource.aiDetected;
    return SubscriptionSource.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SubscriptionSource.manual,
    );
  }
}

class SubscriptionModel {
  final String id;
  final String tenantId;
  final String userId;
  final String name;
  final String? description;
  final double amount;
  final String currency;
  final BillingCycle billingCycle;
  final DateTime nextBillingDate;
  final DateTime? startDate;
  final DateTime? trialEndDate;
  final bool isActive;
  final bool isPaused;
  final AIFlag aiFlag;
  final String? aiFlagReason;
  final DateTime? lastUsageDetected;
  final double? previousAmount;
  final SubscriptionSource source;
  final String? color;
  final String? icon;
  final String? logoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SubscriptionModel({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.name,
    this.description,
    required this.amount,
    required this.currency,
    required this.billingCycle,
    required this.nextBillingDate,
    this.startDate,
    this.trialEndDate,
    required this.isActive,
    required this.isPaused,
    required this.aiFlag,
    this.aiFlagReason,
    this.lastUsageDetected,
    this.previousAmount,
    required this.source,
    this.color,
    this.icon,
    this.logoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      billingCycle: BillingCycle.fromJson(json['billing_cycle'] as String),
      nextBillingDate: DateTime.parse(json['next_billing_date'] as String),
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      trialEndDate: json['trial_end_date'] != null
          ? DateTime.parse(json['trial_end_date'] as String)
          : null,
      isActive: json['is_active'] as bool,
      isPaused: json['is_paused'] as bool,
      aiFlag: AIFlag.fromJson(json['ai_flag'] as String),
      aiFlagReason: json['ai_flag_reason'] as String?,
      lastUsageDetected: json['last_usage_detected'] != null
          ? DateTime.parse(json['last_usage_detected'] as String)
          : null,
      previousAmount: json['previous_amount'] != null
          ? (json['previous_amount'] as num).toDouble()
          : null,
      source: SubscriptionSource.fromJson(json['source'] as String),
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      logoUrl: json['logo_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'user_id': userId,
        'name': name,
        'description': description,
        'amount': amount,
        'currency': currency,
        'billing_cycle': billingCycle.toJson(),
        'next_billing_date': nextBillingDate.toIso8601String().split('T')[0],
        'start_date': startDate?.toIso8601String().split('T')[0],
        'trial_end_date': trialEndDate?.toIso8601String().split('T')[0],
        'is_active': isActive,
        'is_paused': isPaused,
        'ai_flag': aiFlag.toJson(),
        'ai_flag_reason': aiFlagReason,
        'last_usage_detected': lastUsageDetected?.toIso8601String(),
        'previous_amount': previousAmount,
        'source': source.toJson(),
        'color': color,
        'icon': icon,
        'logo_url': logoUrl,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class SubscriptionCreateRequest {
  final String name;
  final String? description;
  final double amount;
  final String currency;
  final BillingCycle billingCycle;
  final DateTime nextBillingDate;
  final DateTime? startDate;
  final DateTime? trialEndDate;
  final String? color;
  final String? icon;
  final String? logoUrl;

  const SubscriptionCreateRequest({
    required this.name,
    this.description,
    required this.amount,
    this.currency = 'USD',
    required this.billingCycle,
    required this.nextBillingDate,
    this.startDate,
    this.trialEndDate,
    this.color,
    this.icon,
    this.logoUrl,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        'amount': amount,
        'currency': currency,
        'billing_cycle': billingCycle.toJson(),
        'next_billing_date': nextBillingDate.toIso8601String().split('T')[0],
        if (startDate != null)
          'start_date': startDate!.toIso8601String().split('T')[0],
        if (trialEndDate != null)
          'trial_end_date': trialEndDate!.toIso8601String().split('T')[0],
        if (color != null) 'color': color,
        if (icon != null) 'icon': icon,
        if (logoUrl != null) 'logo_url': logoUrl,
      };
}

class SubscriptionUpdateRequest {
  final String? name;
  final String? description;
  final double? amount;
  final BillingCycle? billingCycle;
  final DateTime? nextBillingDate;
  final bool? isActive;
  final bool? isPaused;
  final String? color;
  final String? icon;
  final String? logoUrl;

  const SubscriptionUpdateRequest({
    this.name,
    this.description,
    this.amount,
    this.billingCycle,
    this.nextBillingDate,
    this.isActive,
    this.isPaused,
    this.color,
    this.icon,
    this.logoUrl,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (amount != null) data['amount'] = amount;
    if (billingCycle != null) data['billing_cycle'] = billingCycle!.toJson();
    if (nextBillingDate != null) {
      data['next_billing_date'] =
          nextBillingDate!.toIso8601String().split('T')[0];
    }
    if (isActive != null) data['is_active'] = isActive;
    if (isPaused != null) data['is_paused'] = isPaused;
    if (color != null) data['color'] = color;
    if (icon != null) data['icon'] = icon;
    if (logoUrl != null) data['logo_url'] = logoUrl;
    return data;
  }
}

class SubscriptionListResponse {
  final List<SubscriptionModel> subscriptions;
  final int totalCount;
  final double monthlyTotal;
  final double yearlyTotal;
  final int flaggedCount;

  const SubscriptionListResponse({
    required this.subscriptions,
    required this.totalCount,
    required this.monthlyTotal,
    required this.yearlyTotal,
    required this.flaggedCount,
  });

  factory SubscriptionListResponse.fromJson(Map<String, dynamic> json) {
    return SubscriptionListResponse(
      subscriptions: (json['subscriptions'] as List<dynamic>)
          .map((e) => SubscriptionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: json['total_count'] as int,
      monthlyTotal: (json['monthly_total'] as num).toDouble(),
      yearlyTotal: (json['yearly_total'] as num).toDouble(),
      flaggedCount: json['flagged_count'] as int,
    );
  }
}

/// AI flag analysis response
class AnalyzeResponse {
  final int flaggedCount;
  final String message;

  const AnalyzeResponse({
    required this.flaggedCount,
    required this.message,
  });

  factory AnalyzeResponse.fromJson(Map<String, dynamic> json) {
    return AnalyzeResponse(
      flaggedCount: json['flagged_count'] as int,
      message: json['message'] as String,
    );
  }
}

/// AI flag summary response
class AIFlagSummaryResponse {
  final int totalSubscriptions;
  final int flaggedCount;
  final int unusedCount;
  final int duplicateCount;
  final int priceIncreaseCount;
  final int trialEndingCount;
  final int forgottenCount;
  final double potentialMonthlySavings;

  const AIFlagSummaryResponse({
    required this.totalSubscriptions,
    required this.flaggedCount,
    required this.unusedCount,
    required this.duplicateCount,
    required this.priceIncreaseCount,
    required this.trialEndingCount,
    required this.forgottenCount,
    required this.potentialMonthlySavings,
  });

  factory AIFlagSummaryResponse.fromJson(Map<String, dynamic> json) {
    return AIFlagSummaryResponse(
      totalSubscriptions: json['total_subscriptions'] as int,
      flaggedCount: json['flagged_count'] as int,
      unusedCount: json['unused_count'] as int,
      duplicateCount: json['duplicate_count'] as int,
      priceIncreaseCount: json['price_increase_count'] as int,
      trialEndingCount: json['trial_ending_count'] as int,
      forgottenCount: json['forgotten_count'] as int,
      potentialMonthlySavings: (json['potential_monthly_savings'] as num).toDouble(),
    );
  }

  /// Check if there are any flags
  bool get hasFlags => flaggedCount > 0;

  /// Get total flagged by waste type (unused, duplicate, forgotten)
  int get wasteCount => unusedCount + duplicateCount + forgottenCount;
}
