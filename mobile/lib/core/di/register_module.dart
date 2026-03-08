import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
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

  /// Dio HTTP client with base configuration and optional certificate pinning.
  /// Interceptors are added post-init in [configureDependencies].
  ///
  /// Certificate pinning is enabled when API_CERT_PIN is set via --dart-define.
  /// The pin is the SHA-256 hash of the server's leaf certificate in base64.
  ///
  /// To get the pin for your server:
  /// ```
  /// openssl s_client -connect api.moneyguardian.app:443 < /dev/null 2>/dev/null \
  ///   | openssl x509 -outform DER \
  ///   | openssl dgst -sha256 -binary \
  ///   | base64
  /// ```
  @lazySingleton
  Dio get dio {
    final dioInstance = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Certificate pinning — only on native platforms and when pin is provided
    const certPin = String.fromEnvironment('API_CERT_PIN');
    if (certPin.isNotEmpty && !kIsWeb) {
      final adapter = IOHttpClientAdapter();
      adapter.onHttpClientCreate = (HttpClient client) {
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          final certHash = base64Encode(sha256.convert(cert.der).bytes);
          final matches = certHash == certPin;
          if (!matches) {
            debugPrint('[CertPin] Pin mismatch for $host. '
                'Expected: $certPin, Got: $certHash');
          }
          return matches;
        };
        return client;
      };
      dioInstance.httpClientAdapter = adapter;
      debugPrint('[CertPin] Certificate pinning enabled');
    }

    return dioInstance;
  }

  /// Connectivity checker for network status.
  @lazySingleton
  Connectivity get connectivity => Connectivity();
}
