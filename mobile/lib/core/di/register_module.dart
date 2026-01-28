import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../network/api_interceptors.dart';
import '../storage/secure_storage.dart';

/// Module for registering third-party dependencies
@module
abstract class RegisterModule {
  /// Shared Preferences instance
  @preResolve
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();

  /// Flutter Secure Storage instance
  @lazySingleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );

  /// Dio HTTP client configured for Money Guardian API
  @lazySingleton
  Dio dio(SecureStorage storage) {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
        receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors
    dio.interceptors.addAll([
      AuthInterceptor(
        getToken: () => storage.getAuthToken(),
        onTokenExpired: () => storage.clearAuthData(),
      ),
      LoggingInterceptor(),
    ]);

    return dio;
  }
}
