/// API configuration for Money Guardian
class ApiConfig {
  /// Base URL for the API
  /// Development: http://localhost:8000/api/v1
  /// Production: https://api.moneyguardian.app/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

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
