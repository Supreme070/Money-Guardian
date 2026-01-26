import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys for shared preferences
class PreferencesKeys {
  static const String onboardingComplete = 'onboarding_complete';
  static const String notificationsEnabled = 'notifications_enabled';
  static const String lastSyncTime = 'last_sync_time';
  static const String theme = 'theme';
  static const String pulseRefreshInterval = 'pulse_refresh_interval';
}

/// Wrapper for SharedPreferences (non-sensitive data)
@lazySingleton
class AppPreferences {
  final SharedPreferences _prefs;

  AppPreferences(this._prefs);

  // Onboarding
  bool get isOnboardingComplete =>
      _prefs.getBool(PreferencesKeys.onboardingComplete) ?? false;

  Future<void> setOnboardingComplete(bool value) =>
      _prefs.setBool(PreferencesKeys.onboardingComplete, value);

  // Notifications
  bool get areNotificationsEnabled =>
      _prefs.getBool(PreferencesKeys.notificationsEnabled) ?? true;

  Future<void> setNotificationsEnabled(bool value) =>
      _prefs.setBool(PreferencesKeys.notificationsEnabled, value);

  // Last sync time
  DateTime? get lastSyncTime {
    final timestamp = _prefs.getInt(PreferencesKeys.lastSyncTime);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  Future<void> setLastSyncTime(DateTime time) =>
      _prefs.setInt(PreferencesKeys.lastSyncTime, time.millisecondsSinceEpoch);

  // Theme (light/dark/system)
  String get theme => _prefs.getString(PreferencesKeys.theme) ?? 'system';

  Future<void> setTheme(String theme) =>
      _prefs.setString(PreferencesKeys.theme, theme);

  // Pulse refresh interval (in minutes)
  int get pulseRefreshInterval =>
      _prefs.getInt(PreferencesKeys.pulseRefreshInterval) ?? 30;

  Future<void> setPulseRefreshInterval(int minutes) =>
      _prefs.setInt(PreferencesKeys.pulseRefreshInterval, minutes);

  // Clear all preferences
  Future<void> clear() => _prefs.clear();
}
