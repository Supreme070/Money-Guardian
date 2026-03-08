/// Base exception class
class AppException implements Exception {
  final String message;
  final String? code;

  const AppException({required this.message, this.code});

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Server exception (API errors)
class ServerException extends AppException {
  final int? statusCode;

  const ServerException({
    required super.message,
    super.code,
    this.statusCode,
  });

  @override
  String toString() =>
      'ServerException: $message (status: $statusCode, code: $code)';
}

/// Network exception (connectivity issues)
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'Network error occurred',
    super.code,
  });
}

/// Cache exception (local storage issues)
class CacheException extends AppException {
  const CacheException({
    super.message = 'Cache error occurred',
    super.code,
  });
}

/// Authentication exception
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
  });
}

/// Plaid exception (bank connection issues)
class PlaidException extends AppException {
  const PlaidException({
    required super.message,
    super.code,
  });
}

/// Tier limit exception (402 Payment Required)
class TierLimitException extends AppException {
  final int currentCount;
  final int limit;
  final bool upgradeRequired;

  const TierLimitException({
    required super.message,
    required this.currentCount,
    required this.limit,
    required this.upgradeRequired,
    super.code = 'TIER_LIMIT_EXCEEDED',
  });

  @override
  String toString() =>
      'TierLimitException: $message (current: $currentCount, limit: $limit)';
}

/// Maps exceptions to user-friendly error messages.
/// Prevents leaking internal details (stack traces, server errors) to the UI.
String sanitizeErrorMessage(Object error) {
  if (error is NetworkException) {
    return 'Check your internet connection and try again.';
  }
  if (error is AuthException) {
    return 'Session expired. Please log in again.';
  }
  if (error is TierLimitException) {
    return error.message;
  }
  if (error is ServerException) {
    return 'Something went wrong. Please try again.';
  }
  return 'An unexpected error occurred. Please try again.';
}
