import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../error/exceptions.dart';

/// API client wrapper around Dio
@lazySingleton
class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  /// GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// PATCH request
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Handle Dio errors and convert to app exceptions
  AppException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException(
          message: 'Connection timed out. Please try again.',
        );

      case DioExceptionType.connectionError:
        return const NetworkException(
          message: 'No internet connection. Please check your network.',
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final message = _extractErrorMessage(error.response);

        if (statusCode == 401) {
          return AuthException(message: message, code: 'UNAUTHORIZED');
        }

        if (statusCode == 402) {
          return _handleTierLimitError(error.response);
        }

        return ServerException(
          message: message,
          statusCode: statusCode,
        );

      case DioExceptionType.cancel:
        return const ServerException(message: 'Request cancelled');

      default:
        return ServerException(
          message: error.message ?? 'An unexpected error occurred',
        );
    }
  }

  /// Extract error message from response
  String _extractErrorMessage(Response? response) {
    if (response?.data is Map) {
      final data = response!.data as Map;
      // Handle FastAPI detail structure
      final detail = data['detail'];
      if (detail is Map) {
        return detail['message'] as String? ?? 'Server error occurred';
      }
      if (detail is String) {
        return detail;
      }
      return data['message'] as String? ??
          data['error'] as String? ??
          'Server error occurred';
    }
    return 'Server error occurred';
  }

  /// Handle 402 Payment Required (tier limit exceeded)
  TierLimitException _handleTierLimitError(Response? response) {
    if (response?.data is Map) {
      final data = response!.data as Map;
      final detail = data['detail'];
      if (detail is Map) {
        return TierLimitException(
          message: detail['message'] as String? ??
              'Subscription limit reached. Upgrade to Pro.',
          currentCount: detail['current_count'] as int? ?? 5,
          limit: detail['limit'] as int? ?? 5,
          upgradeRequired: detail['upgrade_required'] as bool? ?? true,
        );
      }
    }
    return const TierLimitException(
      message: 'Subscription limit reached. Upgrade to Pro.',
      currentCount: 5,
      limit: 5,
      upgradeRequired: true,
    );
  }
}
