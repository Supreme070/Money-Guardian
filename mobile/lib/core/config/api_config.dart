/// API configuration for Money Guardian.
///
/// Environment selection at build time:
///   flutter run   --dart-define=ENV=dev          (default)
///   flutter run   --dart-define=ENV=staging
///   flutter build --dart-define=ENV=production
///
/// Or override the URL directly:
///   flutter run --dart-define=API_BASE_URL=https://custom.example.com/api/v1
class ApiConfig {
  // ── Environment ───────────────────────────────────────────
  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');

  /// Explicit override takes precedence; otherwise pick by ENV.
  static const String _urlOverride = String.fromEnvironment('API_BASE_URL');

  static const Map<String, String> _envUrls = {
    'dev': 'http://localhost:8000/api/v1',
    'staging': 'https://staging-api.moneyguardian.app/api/v1',
    'production': 'https://api.moneyguardian.app/api/v1',
  };

  /// Base URL for the API — resolved once at compile time.
  static String get baseUrl =>
      _urlOverride.isNotEmpty ? _urlOverride : (_envUrls[_env] ?? _envUrls['dev']!);

  /// True when running against production.
  static bool get isProduction => _env == 'production';

  /// Request timeout in milliseconds
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;

  /// API endpoints
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';
  static const String authPasswordResetRequest = '/auth/password-reset/request';
  static const String authPasswordResetConfirm = '/auth/password-reset/confirm';

  static const String usersMe = '/users/me';
  static const String usersChangePassword = '/users/me/password';
  static const String usersDeleteMe = '/users/me';
  static const String usersFcmToken = '/users/me/fcm-token';

  static const String subscriptions = '/subscriptions';
  static String subscriptionById(String id) => '/subscriptions/$id';
  static const String subscriptionsAnalyze = '/subscriptions/analyze';
  static const String subscriptionsFlagsSummary = '/subscriptions/flags/summary';

  static const String alerts = '/alerts';
  static String alertById(String id) => '/alerts/$id';
  static const String alertsMarkRead = '/alerts/mark-read';
  static String alertDismiss(String id) => '/alerts/$id/dismiss';

  static const String pulse = '/pulse';

  // Banking endpoints (Pro feature)
  static const String banking = '/banking';
  static const String bankingLinkToken = '/banking/link-token';
  static const String bankingExchange = '/banking/exchange';
  static String bankingById(String id) => '/banking/$id';
  static String bankingSync(String id) => '/banking/$id/sync';
  static String bankingSyncBalances(String id) => '/banking/$id/sync-balances';
  static String bankingRecurring(String id) => '/banking/$id/recurring';
  static String bankingRecurringConvert(String connectionId, String streamId) =>
      '/banking/$connectionId/recurring/$streamId/convert';

  // Email endpoints (Pro feature)
  static const String email = '/email';
  static const String emailProviders = '/email/providers';
  static const String emailOAuthStart = '/email/oauth/start';
  static const String emailOAuthComplete = '/email/oauth/complete';
  static String emailById(String id) => '/email/$id';
  static String emailScan(String id) => '/email/$id/scan';
  static String emailScanned(String id) => '/email/$id/scanned';
  static String emailScannedProcess(String connectionId, String emailId) =>
      '/email/$connectionId/scanned/$emailId/process';
  static String emailScannedConvert(String connectionId, String emailId) =>
      '/email/$connectionId/scanned/$emailId/convert';
  static const String emailKnownSenders = '/email/known-senders/all';
}
