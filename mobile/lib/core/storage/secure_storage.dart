import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys for secure storage
class SecureStorageKeys {
  static const String authToken = 'auth_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String firebaseToken = 'firebase_token';
}

/// Wrapper for storage - uses SharedPreferences on web, SecureStorage on mobile
@lazySingleton
class SecureStorage {
  FlutterSecureStorage? _secureStorage;
  SharedPreferences? _webStorage;

  SecureStorage() {
    if (!kIsWeb) {
      _secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
        ),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock,
        ),
      );
    }
  }

  Future<SharedPreferences> _getWebStorage() async {
    _webStorage ??= await SharedPreferences.getInstance();
    return _webStorage!;
  }

  /// Read a value
  Future<String?> read(String key) async {
    if (kIsWeb) {
      final prefs = await _getWebStorage();
      return prefs.getString(key);
    }
    return _secureStorage!.read(key: key);
  }

  /// Write a value
  Future<void> write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await _getWebStorage();
      await prefs.setString(key, value);
      return;
    }
    await _secureStorage!.write(key: key, value: value);
  }

  /// Delete a value
  Future<void> delete(String key) async {
    if (kIsWeb) {
      final prefs = await _getWebStorage();
      await prefs.remove(key);
      return;
    }
    await _secureStorage!.delete(key: key);
  }

  /// Delete all values
  Future<void> deleteAll() async {
    if (kIsWeb) {
      final prefs = await _getWebStorage();
      await prefs.clear();
      return;
    }
    await _secureStorage!.deleteAll();
  }

  /// Check if a key exists
  Future<bool> containsKey(String key) async {
    if (kIsWeb) {
      final prefs = await _getWebStorage();
      return prefs.containsKey(key);
    }
    return _secureStorage!.containsKey(key: key);
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
