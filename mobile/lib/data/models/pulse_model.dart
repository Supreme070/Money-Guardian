/// Daily Pulse data models - matching backend Pydantic schemas
/// NO dynamic, NO Object?, strictly typed

/// Pulse status - matching backend PulseStatus
enum PulseStatus {
  safe,
  caution,
  freeze;

  String toJson() => name;

  static PulseStatus fromJson(String value) {
    return PulseStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PulseStatus.safe,
    );
  }
}

class UpcomingCharge {
  final String subscriptionId;
  final String name;
  final double amount;
  final DateTime date;
  final String? logoUrl;
  final String? color;
  final bool isWarning;

  const UpcomingCharge({
    required this.subscriptionId,
    required this.name,
    required this.amount,
    required this.date,
    this.logoUrl,
    this.color,
    required this.isWarning,
  });

  factory UpcomingCharge.fromJson(Map<String, dynamic> json) {
    return UpcomingCharge(
      subscriptionId: json['subscription_id'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      logoUrl: json['logo_url'] as String?,
      color: json['color'] as String?,
      isWarning: json['is_warning'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'subscription_id': subscriptionId,
        'name': name,
        'amount': amount,
        'date': date.toIso8601String().split('T')[0],
        'logo_url': logoUrl,
        'color': color,
        'is_warning': isWarning,
      };
}

class PulseResponse {
  final PulseStatus status;
  final String statusMessage;
  final double safeToSpend;
  final double currentBalance;
  final List<UpcomingCharge> upcomingCharges;
  final double upcomingTotal;
  final int activeSubscriptionsCount;
  final double monthlySubscriptionTotal;
  final int unreadAlertsCount;
  final DateTime calculatedAt;
  final DateTime nextRefreshAt;

  const PulseResponse({
    required this.status,
    required this.statusMessage,
    required this.safeToSpend,
    required this.currentBalance,
    required this.upcomingCharges,
    required this.upcomingTotal,
    required this.activeSubscriptionsCount,
    required this.monthlySubscriptionTotal,
    required this.unreadAlertsCount,
    required this.calculatedAt,
    required this.nextRefreshAt,
  });

  factory PulseResponse.fromJson(Map<String, dynamic> json) {
    return PulseResponse(
      status: PulseStatus.fromJson(json['status'] as String),
      statusMessage: json['status_message'] as String,
      safeToSpend: (json['safe_to_spend'] as num).toDouble(),
      currentBalance: (json['current_balance'] as num).toDouble(),
      upcomingCharges: (json['upcoming_charges'] as List<dynamic>)
          .map((e) => UpcomingCharge.fromJson(e as Map<String, dynamic>))
          .toList(),
      upcomingTotal: (json['upcoming_total'] as num).toDouble(),
      activeSubscriptionsCount: json['active_subscriptions_count'] as int,
      monthlySubscriptionTotal:
          (json['monthly_subscription_total'] as num).toDouble(),
      unreadAlertsCount: json['unread_alerts_count'] as int,
      calculatedAt: DateTime.parse(json['calculated_at'] as String),
      nextRefreshAt: DateTime.parse(json['next_refresh_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status.toJson(),
        'status_message': statusMessage,
        'safe_to_spend': safeToSpend,
        'current_balance': currentBalance,
        'upcoming_charges': upcomingCharges.map((e) => e.toJson()).toList(),
        'upcoming_total': upcomingTotal,
        'active_subscriptions_count': activeSubscriptionsCount,
        'monthly_subscription_total': monthlySubscriptionTotal,
        'unread_alerts_count': unreadAlertsCount,
        'calculated_at': calculatedAt.toIso8601String(),
        'next_refresh_at': nextRefreshAt.toIso8601String(),
      };
}

class PulseBreakdown {
  final double currentBalance;
  final double upcomingCharges7Days;
  final double upcomingCharges30Days;
  final double averageDailySpend;
  final double predictedBalance7Days;
  final double predictedBalance30Days;
  final DateTime? overdraftRiskDate;
  final PulseStatus status;
  final String statusReason;

  const PulseBreakdown({
    required this.currentBalance,
    required this.upcomingCharges7Days,
    required this.upcomingCharges30Days,
    required this.averageDailySpend,
    required this.predictedBalance7Days,
    required this.predictedBalance30Days,
    this.overdraftRiskDate,
    required this.status,
    required this.statusReason,
  });

  factory PulseBreakdown.fromJson(Map<String, dynamic> json) {
    return PulseBreakdown(
      currentBalance: (json['current_balance'] as num).toDouble(),
      upcomingCharges7Days: (json['upcoming_charges_7_days'] as num).toDouble(),
      upcomingCharges30Days:
          (json['upcoming_charges_30_days'] as num).toDouble(),
      averageDailySpend: (json['average_daily_spend'] as num).toDouble(),
      predictedBalance7Days:
          (json['predicted_balance_7_days'] as num).toDouble(),
      predictedBalance30Days:
          (json['predicted_balance_30_days'] as num).toDouble(),
      overdraftRiskDate: json['overdraft_risk_date'] != null
          ? DateTime.parse(json['overdraft_risk_date'] as String)
          : null,
      status: PulseStatus.fromJson(json['status'] as String),
      statusReason: json['status_reason'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'current_balance': currentBalance,
        'upcoming_charges_7_days': upcomingCharges7Days,
        'upcoming_charges_30_days': upcomingCharges30Days,
        'average_daily_spend': averageDailySpend,
        'predicted_balance_7_days': predictedBalance7Days,
        'predicted_balance_30_days': predictedBalance30Days,
        'overdraft_risk_date': overdraftRiskDate?.toIso8601String().split('T')[0],
        'status': status.toJson(),
        'status_reason': statusReason,
      };
}
