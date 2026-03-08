import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../config/api_config.dart';
import '../network/api_interceptors.dart';
import '../network/connectivity_service.dart';
import '../storage/secure_storage.dart';
import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
)
Future<void> configureDependencies() async {
  // init() is now async because SharedPreferences uses @preResolve
  await getIt.init();

  // Wire interceptors to the shared Dio instance after DI resolves
  _configureInterceptors();
}

/// Adds auth, connectivity, retry, and logging interceptors to Dio.
/// Must be called after DI initialization so all singletons are available.
void _configureInterceptors() {
  final dio = getIt<Dio>();
  final secureStorage = getIt<SecureStorage>();
  final connectivityService = getIt<ConnectivityService>();

  // Auth interceptor — injects JWT, handles 401 refresh
  dio.interceptors.add(AuthInterceptor(
    dio: dio,
    getToken: () => secureStorage.getAuthToken(),
    getRefreshToken: () => secureStorage.getRefreshToken(),
    saveTokens: (accessToken, refreshToken) async {
      await secureStorage.setAuthToken(accessToken);
      await secureStorage.setRefreshToken(refreshToken);
    },
    onTokenExpired: () => secureStorage.clearAuthData(),
    refreshEndpoint: ApiConfig.authRefresh,
  ));

  // Connectivity interceptor — rejects requests when offline
  dio.interceptors.add(ConnectivityInterceptor(
    checkConnectivity: () async => connectivityService.isConnected,
  ));

  // Retry interceptor — retries on transient failures using the shared Dio
  dio.interceptors.add(RetryInterceptor(dio: dio));

  // Logging interceptor — only in debug mode
  if (kDebugMode) {
    dio.interceptors.add(LoggingInterceptor());
  }
}
