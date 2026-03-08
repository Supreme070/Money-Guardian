import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// Registers external dependencies that injectable cannot auto-discover.
///
/// These are third-party classes (Dio, SharedPreferences, Connectivity)
/// that don't have @injectable annotations.
@module
abstract class RegisterModule {
  /// SharedPreferences requires async initialization.
  /// @preResolve ensures it's awaited before DI completes.
  @preResolve
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();

  /// Dio HTTP client with base configuration.
  /// Interceptors are added post-init in [configureDependencies].
  @lazySingleton
  Dio get dio => Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
        receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));

  /// Connectivity checker for network status.
  @lazySingleton
  Connectivity get connectivity => Connectivity();
}
