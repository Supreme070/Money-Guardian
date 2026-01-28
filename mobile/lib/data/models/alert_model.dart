/// Alert data models - matching backend Pydantic schemas
/// NO dynamic, NO Object?, strictly typed

/// Alert types - matching backend AlertTypeEnum
enum AlertType {
  upcomingCharge,
  overdraftWarning,
  priceIncrease,
  trialEnding,
  unusedSubscription,
  paymentFailed,
  largeCharge;

  String toJson() {
    switch (this) {
      case AlertType.upcomingCharge:
        return 'upcoming_charge';
      case AlertType.overdraftWarning:
        return 'overdraft_warning';
      case AlertType.priceIncrease:
        return 'price_increase';
      case AlertType.trialEnding:
        return 'trial_ending';
      case AlertType.unusedSubscription:
        return 'unused_subscription';
      case AlertType.paymentFailed:
        return 'payment_failed';
      case AlertType.largeCharge:
        return 'large_charge';
    }
  }

  static AlertType fromJson(String value) {
    switch (value) {
      case 'upcoming_charge':
        return AlertType.upcomingCharge;
      case 'overdraft_warning':
        return AlertType.overdraftWarning;
      case 'price_increase':
        return AlertType.priceIncrease;
      case 'trial_ending':
        return AlertType.trialEnding;
      case 'unused_subscription':
        return AlertType.unusedSubscription;
      case 'payment_failed':
        return AlertType.paymentFailed;
      case 'large_charge':
        return AlertType.largeCharge;
      default:
        return AlertType.upcomingCharge;
    }
  }
}

/// Alert severity - matching backend AlertSeverityEnum
enum AlertSeverity {
  info,
  warning,
  critical;

  String toJson() => name;

  static AlertSeverity fromJson(String value) {
    return AlertSeverity.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AlertSeverity.info,
    );
  }
}

class AlertModel {
  final String id;
  final String tenantId;
  final String userId;
  final String? subscriptionId;
  final AlertType alertType;
  final AlertSeverity severity;
  final String title;
  final String message;
  final double? amount;
  final DateTime? alertDate;
  final bool isRead;
  final bool isDismissed;
  final bool isActioned;
  final DateTime? readAt;
  final DateTime? dismissedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AlertModel({
    required this.id,
    required this.tenantId,
    required this.userId,
    this.subscriptionId,
    required this.alertType,
    required this.severity,
    required this.title,
    required this.message,
    this.amount,
    this.alertDate,
    required this.isRead,
    required this.isDismissed,
    required this.isActioned,
    this.readAt,
    this.dismissedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      userId: json['user_id'] as String,
      subscriptionId: json['subscription_id'] as String?,
      alertType: AlertType.fromJson(json['alert_type'] as String),
      severity: AlertSeverity.fromJson(json['severity'] as String),
      title: json['title'] as String,
      message: json['message'] as String,
      amount: json['amount'] != null ? (json['amount'] as num).toDouble() : null,
      alertDate: json['alert_date'] != null
          ? DateTime.parse(json['alert_date'] as String)
          : null,
      isRead: json['is_read'] as bool,
      isDismissed: json['is_dismissed'] as bool,
      isActioned: json['is_actioned'] as bool,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      dismissedAt: json['dismissed_at'] != null
          ? DateTime.parse(json['dismissed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'user_id': userId,
        'subscription_id': subscriptionId,
        'alert_type': alertType.toJson(),
        'severity': severity.toJson(),
        'title': title,
        'message': message,
        'amount': amount,
        'alert_date': alertDate?.toIso8601String(),
        'is_read': isRead,
        'is_dismissed': isDismissed,
        'is_actioned': isActioned,
        'read_at': readAt?.toIso8601String(),
        'dismissed_at': dismissedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class AlertListResponse {
  final List<AlertModel> alerts;
  final int totalCount;
  final int unreadCount;
  final int criticalCount;

  const AlertListResponse({
    required this.alerts,
    required this.totalCount,
    required this.unreadCount,
    required this.criticalCount,
  });

  factory AlertListResponse.fromJson(Map<String, dynamic> json) {
    return AlertListResponse(
      alerts: (json['alerts'] as List<dynamic>)
          .map((e) => AlertModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: json['total_count'] as int,
      unreadCount: json['unread_count'] as int,
      criticalCount: json['critical_count'] as int,
    );
  }
}

class AlertMarkReadRequest {
  final List<String> alertIds;

  const AlertMarkReadRequest({required this.alertIds});

  Map<String, dynamic> toJson() => {
        'alert_ids': alertIds,
      };
}

class AlertDismissRequest {
  final List<String> alertIds;

  const AlertDismissRequest({required this.alertIds});

  Map<String, dynamic> toJson() => {
        'alert_ids': alertIds,
      };
}
