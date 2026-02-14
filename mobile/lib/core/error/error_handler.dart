import 'dart:async';

import 'package:flutter/foundation.dart';

import 'exceptions.dart';

/// Global error handler for uncaught exceptions.
///
/// Logs errors and provides user-friendly messages.
/// In production, this would also report to Sentry/Crashlytics.
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._();
  factory ErrorHandler() => _instance;
  ErrorHandler._();

  /// Initialize global error handling.
  /// Call this in main() before runApp().
  void initialize() {
    FlutterError.onError = _handleFlutterError;
  }

  /// Wrap runApp in a zone to catch async errors.
  void runGuarded(void Function() appRunner) {
    runZonedGuarded(
      appRunner,
      _handleUncaughtError,
    );
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    debugPrint('Flutter error: ${details.exceptionAsString()}');
    debugPrint('Stack: ${details.stack}');
    // In production: report to crash reporting service
  }

  void _handleUncaughtError(Object error, StackTrace stack) {
    debugPrint('Uncaught error: $error');
    debugPrint('Stack: $stack');
    // In production: report to crash reporting service
  }

  /// Convert any exception to a user-friendly message.
  static String userMessage(Object error) {
    if (error is NetworkException) {
      return 'No internet connection. Please check your network.';
    }
    if (error is AuthException) {
      return error.message;
    }
    if (error is ServerException) {
      if (error.statusCode == 401) {
        return 'Session expired. Please sign in again.';
      }
      if (error.statusCode == 403) {
        return 'You don\'t have permission to do that.';
      }
      if (error.statusCode == 404) {
        return 'The requested resource was not found.';
      }
      if (error.statusCode != null && error.statusCode! >= 500) {
        return 'Something went wrong on our end. Please try again.';
      }
      return error.message;
    }
    if (error is TierLimitException) {
      return error.message;
    }
    if (error is AppException) {
      return error.message;
    }
    return 'Something went wrong. Please try again.';
  }
}
