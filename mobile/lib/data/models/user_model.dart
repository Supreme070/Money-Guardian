/// User data model - matching backend UserResponse schema
/// NO dynamic, NO Object?, strictly typed

/// Subscription tier types
enum SubscriptionTier {
  free,
  pro,
  premium;

  String toJson() => name;

  static SubscriptionTier fromJson(String value) {
    return SubscriptionTier.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SubscriptionTier.free,
    );
  }
}

/// Granular notification type preferences matching backend NotificationPreferences.
class NotificationPreferences {
  final bool overdraftWarnings;
  final bool upcomingCharges;
  final bool trialEndings;
  final bool priceIncreases;
  final bool unusedSubscriptions;

  const NotificationPreferences({
    this.overdraftWarnings = true,
    this.upcomingCharges = true,
    this.trialEndings = true,
    this.priceIncreases = true,
    this.unusedSubscriptions = true,
  });

  factory NotificationPreferences.fromJson(Map<String, bool> json) {
    return NotificationPreferences(
      overdraftWarnings: json['overdraft_warnings'] ?? true,
      upcomingCharges: json['upcoming_charges'] ?? true,
      trialEndings: json['trial_endings'] ?? true,
      priceIncreases: json['price_increases'] ?? true,
      unusedSubscriptions: json['unused_subscriptions'] ?? true,
    );
  }

  Map<String, bool> toJson() => {
        'overdraft_warnings': overdraftWarnings,
        'upcoming_charges': upcomingCharges,
        'trial_endings': trialEndings,
        'price_increases': priceIncreases,
        'unused_subscriptions': unusedSubscriptions,
      };

  NotificationPreferences copyWith({
    bool? overdraftWarnings,
    bool? upcomingCharges,
    bool? trialEndings,
    bool? priceIncreases,
    bool? unusedSubscriptions,
  }) {
    return NotificationPreferences(
      overdraftWarnings: overdraftWarnings ?? this.overdraftWarnings,
      upcomingCharges: upcomingCharges ?? this.upcomingCharges,
      trialEndings: trialEndings ?? this.trialEndings,
      priceIncreases: priceIncreases ?? this.priceIncreases,
      unusedSubscriptions: unusedSubscriptions ?? this.unusedSubscriptions,
    );
  }
}

class UserModel {
  final String id;
  final String tenantId;
  final String email;
  final String? fullName;
  final bool isActive;
  final bool isVerified;
  final DateTime? lastLoginAt;
  final bool pushNotificationsEnabled;
  final bool emailNotificationsEnabled;
  final NotificationPreferences notificationPreferences;
  final SubscriptionTier subscriptionTier;
  final DateTime? subscriptionExpiresAt;
  final bool onboardingCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.tenantId,
    required this.email,
    this.fullName,
    required this.isActive,
    required this.isVerified,
    this.lastLoginAt,
    required this.pushNotificationsEnabled,
    required this.emailNotificationsEnabled,
    this.notificationPreferences = const NotificationPreferences(),
    required this.subscriptionTier,
    this.subscriptionExpiresAt,
    required this.onboardingCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if user is new and needs onboarding
  bool get isNewUser => !onboardingCompleted;

  /// Check if user has Pro features
  bool get isPro =>
      subscriptionTier == SubscriptionTier.pro ||
      subscriptionTier == SubscriptionTier.premium;

  /// Get subscription tier as display string
  String get subscriptionTierDisplay {
    switch (subscriptionTier) {
      case SubscriptionTier.pro:
        return 'pro';
      case SubscriptionTier.premium:
        return 'premium';
      case SubscriptionTier.free:
        return 'free';
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawPrefs = json['notification_preferences'];
    final NotificationPreferences prefs;
    if (rawPrefs is Map<String, dynamic>) {
      prefs = NotificationPreferences.fromJson(
        rawPrefs.map((k, v) => MapEntry(k, v as bool)),
      );
    } else {
      prefs = const NotificationPreferences();
    }

    return UserModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      isActive: json['is_active'] as bool,
      isVerified: json['is_verified'] as bool,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
      pushNotificationsEnabled: json['push_notifications_enabled'] as bool,
      emailNotificationsEnabled: json['email_notifications_enabled'] as bool,
      notificationPreferences: prefs,
      subscriptionTier: SubscriptionTier.fromJson(
        json['subscription_tier'] as String? ?? 'free',
      ),
      subscriptionExpiresAt: json['subscription_expires_at'] != null
          ? DateTime.parse(json['subscription_expires_at'] as String)
          : null,
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'email': email,
        'full_name': fullName,
        'is_active': isActive,
        'is_verified': isVerified,
        'last_login_at': lastLoginAt?.toIso8601String(),
        'push_notifications_enabled': pushNotificationsEnabled,
        'email_notifications_enabled': emailNotificationsEnabled,
        'notification_preferences': notificationPreferences.toJson(),
        'subscription_tier': subscriptionTier.toJson(),
        'subscription_expires_at': subscriptionExpiresAt?.toIso8601String(),
        'onboarding_completed': onboardingCompleted,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  /// Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? tenantId,
    String? email,
    String? fullName,
    bool? isActive,
    bool? isVerified,
    DateTime? lastLoginAt,
    bool? pushNotificationsEnabled,
    bool? emailNotificationsEnabled,
    NotificationPreferences? notificationPreferences,
    SubscriptionTier? subscriptionTier,
    DateTime? subscriptionExpiresAt,
    bool? onboardingCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      emailNotificationsEnabled:
          emailNotificationsEnabled ?? this.emailNotificationsEnabled,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      subscriptionExpiresAt:
          subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class UserUpdateRequest {
  final String? fullName;
  final bool? pushNotificationsEnabled;
  final bool? emailNotificationsEnabled;
  final NotificationPreferences? notificationPreferences;
  final bool? onboardingCompleted;

  const UserUpdateRequest({
    this.fullName,
    this.pushNotificationsEnabled,
    this.emailNotificationsEnabled,
    this.notificationPreferences,
    this.onboardingCompleted,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (fullName != null) data['full_name'] = fullName;
    if (pushNotificationsEnabled != null) {
      data['push_notifications_enabled'] = pushNotificationsEnabled;
    }
    if (emailNotificationsEnabled != null) {
      data['email_notifications_enabled'] = emailNotificationsEnabled;
    }
    if (notificationPreferences != null) {
      data['notification_preferences'] = notificationPreferences!.toJson();
    }
    if (onboardingCompleted != null) {
      data['onboarding_completed'] = onboardingCompleted;
    }
    return data;
  }
}
