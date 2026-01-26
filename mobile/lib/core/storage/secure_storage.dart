import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// Keys for secure storage
class SecureStorageKeys {
  static const String authToken = 'auth_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String firebaseToken = 'firebase_token';
}

/// Wrapper for FlutterSecureStorage
@lazySingleton
class SecureStorage {
  final FlutterSecureStorage _storage;

  SecureStorage()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        );

  /// Read a value
  Future<String?> read(String key) async {
    return _storage.read(key: key);
  }

  /// Write a value
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Delete a value
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// Delete all values
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  /// Check if a key exists
  Future<bool> containsKey(String key) async {
    return _storage.containsKey(key: key);
  }

  // Convenience methods for auth tokens

  Future<String?> getAuthToken() => read(SecureStorageKeys.authToken);

  Future<void> setAuthToken(String token) =>
      write(SecureStorageKeys.authToken, token);

  Future<void> deleteAuthToken() => delete(SecureStorageKeys.authToken);

  Future<String?> getRefreshToken() => read(SecureStorageKeys.refreshToken);

  Future<void> setRefreshToken(String token) =>
      write(SecureStorageKeys.refreshToken, token);

  Future<void> deleteRefreshToken() => delete(SecureStorageKeys.refreshToken);

  /// Clear all auth-related data
  Future<void> clearAuthData() async {
    await Future.wait([
      delete(SecureStorageKeys.authToken),
      delete(SecureStorageKeys.refreshToken),
      delete(SecureStorageKeys.userId),
      delete(SecureStorageKeys.firebaseToken),
    ]);
  }
}
