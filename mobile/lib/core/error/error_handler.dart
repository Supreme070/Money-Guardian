import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'exceptions.dart';

/// Global error handler for uncaught exceptions.
///
/// Reports errors to Sentry in release builds and logs locally in debug.
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
    if (kDebugMode) {
      debugPrint('Flutter error: ${details.exceptionAsString()}');
      debugPrint('Stack: ${details.stack}');
    } else {
      Sentry.captureException(
        details.exception,
        stackTrace: details.stack,
      );
    }
  }

  void _handleUncaughtError(Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('Uncaught error: $error');
      debugPrint('Stack: $stack');
    } else {
      Sentry.captureException(error, stackTrace: stack);
    }
  }

  /// Report a caught exception to Sentry (non-fatal).
  static void reportError(Object error, {StackTrace? stackTrace}) {
    if (!kDebugMode) {
      Sentry.captureException(error, stackTrace: stackTrace);
    }
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
