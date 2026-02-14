import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Centralized analytics service wrapping Firebase Analytics.
///
/// All event names follow Firebase snake_case convention.
/// Custom parameters are kept ≤25 per event (Firebase limit).
@lazySingleton
class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Firebase Analytics observer for MaterialApp's navigatorObservers
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ──────────────────────────────────────────────────────────────────────
  // Screen Views
  // ──────────────────────────────────────────────────────────────────────

  /// Log a screen view. Called from each page's initState.
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (e) {
      _logError('logScreenView', e);
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Authentication Events
  // ──────────────────────────────────────────────────────────────────────

  Future<void> logLogin({required String method}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e) {
      _logError('logLogin', e);
    }
  }

  Future<void> logSignUp({required String method}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
    } catch (e) {
      _logError('logSignUp', e);
    }
  }

  Future<void> logLogout() async {
    try {
      await _analytics.logEvent(name: 'logout');
    } catch (e) {
      _logError('logLogout', e);
    }
  }

  Future<void> logAccountDeleted() async {
    try {
      await _analytics.logEvent(name: 'account_deleted');
    } catch (e) {
      _logError('logAccountDeleted', e);
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Onboarding Events
  // ──────────────────────────────────────────────────────────────────────

  Future<void> logOnboardingStep({required int step, required String stepName}) async {
    try {
      await _analytics.logEvent(
        name: 'onboarding_step',
        parameters: {
          'step': step,
          'step_name': stepName,
        },
      );
    } catch (e) {
      _logError('logOnboardingStep', e);
    }
  }

  Future<void> logOnboardingCompleted() async {
    try {
      await _analytics.logEvent(name: 'onboarding_completed');
    } catch (e) {
      _logError('logOnboardingCompleted', e);
    }
  }

  Future<void> logOnboardingSkipped({required int atStep}) async {
    try {
      await _analytics.logEvent(
        name: 'onboarding_skipped',
        parameters: {'at_step': atStep},
      );
    } catch (e) {
      _logError('logOnboardingSkipped', e);
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Daily Pulse Events
  // ──────────────────────────────────────────────────────────────────────

  Future<void> logPulseViewed({required String status}) async {
    try {
      await _analytics.logEvent(
        name: 'pulse_viewed',
        parameters: {'status': status},
      );
    } catch (e) {
      _logError('logPulseViewed', e);
    }
  }

  Future<void> logPulseRefreshed() async {
    try {
      await _analytics.logEvent(name: 'pulse_refreshed');
    } catch (e) {
      _logError('logPulseRefreshed', e);
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Subscription Events
  // ──────────────────────────────────────────────────────────────────────

  Future<void> logSubscriptionAdded({
    required String merchantName,
    required double amount,
    required String billingCycle,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'subscription_added',
        parameters: {
          'merchant_name': merchantName,
          'amount': amount,
          'billing_cycle': billingCycle,
        },
      );
    } catch (e) {
      _logError('logSubscriptionAdded', e);
    }
  }

  Future<void> logSubscriptionDeleted({required String subscriptionId}) async {
    try {
      await _analytics.logEvent(
        name: 'subscription_deleted',
        parameters: {'subscription_id': subscriptionId},
      );
    } catch (e) {
      _logError('logSubscriptionDeleted', e);
    }
  }

  Future<void> logSubscriptionPaused({required String subscriptionId}) async {
    try {
      await _analytics.logEvent(
        name: 'subscription_paused',
        parameters: {'subscription_id': subscriptionId},
      );
    } catch (e) {
      _logError('logSubscriptionPaused', e);
    }
  }

  Future<void> logSubscriptionResumed({required String subscriptionId}) async {
    try {
      await _analytics.logEvent(
        name: 'subscription_resumed',
        parameters: {'subscription_id': subscriptionId},
      );
    } catch (e) {
      _logError('logSubscriptionResumed', e);
    }
  }

  Future<void> logSubscriptionCancelled({required String subscriptionId}) async {
    try {
      await _analytics.logEvent(
        name: 'subscription_cancelled',
        parameters: {'subscription_id': subscriptionId},
      );
    } catch (e) {
      _logError('logSubscriptionCancelled', e);
    }
  }

  Future<void> logSubscriptionAnalyzed({required int flaggedCount}) async {
    try {
      await _analytics.logEvent(
        name: 'subscription_analyzed',
        parameters: {'flagged_count': flaggedCount},
      );
    } catch (e) {
      _logError('logSubscriptionAnalyzed', e);
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Alert Events
  // ──────────────────────────────────────────────────────────────────────

  Future<void> logAlertViewed({required String alertType}) async {
    try {
      await _analytics.logEvent(
        name: 'alert_viewed',
        parameters: {'alert_type': alertType},
      );
    } catch (e) {
      _logError('logAlertViewed', e);
    }
  }

  Future<void> logAlertDismissed({required String alertId}) async {
    try {
      await _analytics.logEvent(
        name: 'alert_dismissed',
        parameters: {'alert_id': alertId},
      );
    } catch (e) {
      _logError('logAlertDismissed', e);
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Bank Connection Events
  // ──────────────────────────────────────────────────────────────────────

  Future<void> logBankConnectionStarted({required String provider}) async {
    try {
      await _analytics.logEvent(
        name: 'bank_connection_started',
        parameters: {'provider': provider},
      );
    } catch (e) {
      _logError('logBankConnectionStarted', e);
    }
  }

  Future<void> logBankConnected({required String provider}) async {
    try {
      await _analytics.logEvent(
        name: 'bank_connected',
        parameters: {'provider': provider},
      );
    } catch (e) {
      _logError('logBankConnected', e);
    }
  }

  Future<void> logBankDisconnected() async {
    try {
      await _analytics.logEvent(name: 'bank_disconnected');
    } catch (e) {
      _logError('logBankDisconnected', e);
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Email Scanning Events
  // ──────────────────────────────────────────────────────────────────────

  Future<void> logEmailConnectionStarted({required String provider}) async {
    try {
      await _analytics.logEvent(
        name: 'email_connection_started',
        parameters: {'provider': provider},
      );
    } catch (e) {
      _logError('logEmailConnectionStarted', e);
    }
  }

  Future<void> logEmailConnected({required String provider}) async {
    try {
      await _analytics.logEvent(
        name: 'email_connected',
        parameters: {'provider': provider},
      );
    } catch (e) {
      _logError('logEmailConnected', e);
    }
  }

  Future<void> logEmailScanCompleted({required int subscriptionsFound}) async {
    try {
      await _analytics.logEvent(
        name: 'email_scan_completed',
        parameters: {'subscriptions_found': subscriptionsFound},
      );
    } catch (e) {
      _logError('logEmailScanCompleted', e);
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Pro Upgrade / Purchase Events
  // ──────────────────────────────────────────────────────────────────────

  Future<void> logProUpgradeStarted({required String source}) async {
    try {
      await _analytics.logEvent(
        name: 'pro_upgrade_started',
        parameters: {'source': source},
      );
    } catch (e) {
      _logError('logProUpgradeStarted', e);
    }
  }

  Future<void> logProUpgradeCompleted({required String packageId}) async {
    try {
      await _analytics.logEvent(
        name: 'pro_upgrade_completed',
        parameters: {'package_id': packageId},
      );
    } catch (e) {
      _logError('logProUpgradeCompleted', e);
    }
  }

  Future<void> logProUpgradeCancelled() async {
    try {
      await _analytics.logEvent(name: 'pro_upgrade_cancelled');
    } catch (e) {
      _logError('logProUpgradeCancelled', e);
    }
  }

  Future<void> logPurchaseRestored({required int restoredCount}) async {
    try {
      await _analytics.logEvent(
        name: 'purchase_restored',
        parameters: {'restored_count': restoredCount},
      );
    } catch (e) {
      _logError('logPurchaseRestored', e);
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // User Properties
  // ──────────────────────────────────────────────────────────────────────

  /// Set the user ID for all future events
  Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      _logError('setUserId', e);
    }
  }

  /// Set a user property (e.g., tier, subscription_count)
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      _logError('setUserProperty', e);
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────

  void _logError(String method, Object error) {
    if (kDebugMode) {
      debugPrint('[AnalyticsService] $method failed: $error');
    }
  }
}
