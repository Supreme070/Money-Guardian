import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';

/// Simple TTL-based cache using Hive for offline-first data access.
///
/// Stores JSON strings with expiry timestamps. No TypeAdapters needed —
/// models are serialized via their existing toJson/fromJson methods.
///
/// Usage in repositories (stale-while-revalidate pattern):
/// ```dart
/// try {
///   final data = await apiClient.get(...);
///   await cacheManager.put('box', 'key', jsonEncode(data));
///   return Model.fromJson(data);
/// } catch (e) {
///   final cached = await cacheManager.get('box', 'key');
///   if (cached != null) return Model.fromJson(jsonDecode(cached));
///   rethrow;
/// }
/// ```
@lazySingleton
class CacheManager {
  static const String _expiryKeySuffix = '__expiry';

  /// Get a cached value by box name and key.
  /// Returns null if not found or expired.
  Future<String?> get(String boxName, String key) async {
    try {
      final box = await Hive.openBox<String>(boxName);
      final expiryStr = box.get('$key$_expiryKeySuffix');

      if (expiryStr != null) {
        final expiry = DateTime.tryParse(expiryStr);
        if (expiry != null && DateTime.now().isAfter(expiry)) {
          // Entry expired — clean up
          await box.delete(key);
          await box.delete('$key$_expiryKeySuffix');
          return null;
        }
      }

      return box.get(key);
    } catch (_) {
      return null;
    }
  }

  /// Store a value with a TTL.
  Future<void> put(
    String boxName,
    String key,
    String jsonString, {
    int ttlMinutes = 5,
  }) async {
    try {
      final box = await Hive.openBox<String>(boxName);
      final expiry = DateTime.now().add(Duration(minutes: ttlMinutes));
      await box.put(key, jsonString);
      await box.put('$key$_expiryKeySuffix', expiry.toIso8601String());
    } catch (_) {
      // Cache write failure is non-fatal
    }
  }

  /// Clear all entries in a specific cache box.
  Future<void> clear(String boxName) async {
    try {
      final box = await Hive.openBox<String>(boxName);
      await box.clear();
    } catch (_) {
      // Cache clear failure is non-fatal
    }
  }

  /// Clear all cache boxes. Call on logout to prevent data leakage.
  Future<void> clearAll() async {
    await clear('pulse_cache');
    await clear('subscriptions_cache');
    await clear('alerts_cache');
  }
}
