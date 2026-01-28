import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Auth interceptor - adds JWT token to requests and handles token refresh
class AuthInterceptor extends Interceptor {
  final Future<String?> Function() getToken;
  final Future<String?> Function() getRefreshToken;
  final Future<void> Function(String accessToken, String refreshToken) saveTokens;
  final Future<void> Function() onTokenExpired;
  final String refreshEndpoint;
  final Dio _dio;

  // Lock to prevent multiple concurrent refresh attempts
  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  AuthInterceptor({
    required this.getToken,
    required this.getRefreshToken,
    required this.saveTokens,
    required this.onTokenExpired,
    required this.refreshEndpoint,
    required Dio dio,
  }) : _dio = dio;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip adding token for refresh endpoint to avoid circular dependency
    if (!options.path.contains('/auth/refresh')) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Only handle 401 errors
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // Don't try to refresh if this was already a refresh request
    if (err.requestOptions.path.contains('/auth/refresh')) {
      await onTokenExpired();
      handler.next(err);
      return;
    }

    // Try to refresh the token
    final refreshSuccess = await _refreshToken();

    if (refreshSuccess) {
      // Retry the original request with the new token
      try {
        final newToken = await getToken();
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newToken';

        final response = await _dio.fetch(opts);
        handler.resolve(response);
      } catch (e) {
        handler.next(err);
      }
    } else {
      // Refresh failed, let the error propagate
      handler.next(err);
    }
  }

  /// Attempts to refresh the access token
  /// Returns true if refresh was successful, false otherwise
  Future<bool> _refreshToken() async {
    // If already refreshing, wait for the result
    if (_isRefreshing) {
      return _refreshCompleter?.future ?? Future.value(false);
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        await onTokenExpired();
        _refreshCompleter?.complete(false);
        return false;
      }

      final response = await _dio.post<Map<String, dynamic>>(
        refreshEndpoint,
        data: {'refresh_token': refreshToken},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          // Don't add Authorization header for refresh
          extra: {'skipAuth': true},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final newAccessToken = response.data!['access_token'] as String;
        final newRefreshToken = response.data!['refresh_token'] as String;

        await saveTokens(newAccessToken, newRefreshToken);

        if (kDebugMode) {
          debugPrint('│ Token refreshed successfully');
        }

        _refreshCompleter?.complete(true);
        return true;
      } else {
        await onTokenExpired();
        _refreshCompleter?.complete(false);
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('│ Token refresh failed: $e');
      }
      await onTokenExpired();
      _refreshCompleter?.complete(false);
      return false;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }
}

/// Logging interceptor - logs requests and responses in debug mode
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('┌─────────────────────────────────────────────');
      debugPrint('│ REQUEST: ${options.method} ${options.uri}');
      debugPrint('│ Headers: ${options.headers}');
      if (options.data != null) {
        debugPrint('│ Body: ${options.data}');
      }
      debugPrint('└─────────────────────────────────────────────');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('┌─────────────────────────────────────────────');
      debugPrint('│ RESPONSE: ${response.statusCode}');
      debugPrint('│ URI: ${response.requestOptions.uri}');
      debugPrint('│ Data: ${response.data}');
      debugPrint('└─────────────────────────────────────────────');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('┌─────────────────────────────────────────────');
      debugPrint('│ ERROR: ${err.type}');
      debugPrint('│ URI: ${err.requestOptions.uri}');
      debugPrint('│ Message: ${err.message}');
      debugPrint('│ Response: ${err.response?.data}');
      debugPrint('└─────────────────────────────────────────────');
    }
    handler.next(err);
  }
}

/// Retry interceptor - retries failed requests
class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Duration retryDelay;
  final List<int> retryStatusCodes;

  RetryInterceptor({
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.retryStatusCodes = const [408, 429, 500, 502, 503, 504],
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;

    // Check if we should retry
    if (statusCode != null && retryStatusCodes.contains(statusCode)) {
      final retryCount = err.requestOptions.extra['retryCount'] ?? 0;

      if (retryCount < maxRetries) {
        await Future.delayed(retryDelay * (retryCount + 1));

        err.requestOptions.extra['retryCount'] = retryCount + 1;

        if (kDebugMode) {
          debugPrint('│ Retrying request (${retryCount + 1}/$maxRetries)');
        }

        try {
          final response = await Dio().fetch(err.requestOptions);
          handler.resolve(response);
          return;
        } catch (e) {
          // Continue to next handler on failure
        }
      }
    }

    handler.next(err);
  }
}

/// Network connectivity interceptor - checks connectivity before requests
class ConnectivityInterceptor extends Interceptor {
  final Future<bool> Function() checkConnectivity;

  ConnectivityInterceptor({required this.checkConnectivity});

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final isConnected = await checkConnectivity();

    if (!isConnected) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'No internet connection',
        ),
      );
      return;
    }

    handler.next(options);
  }
}
