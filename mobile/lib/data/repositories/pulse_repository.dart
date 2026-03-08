import 'dart:convert';

import 'package:injectable/injectable.dart';

import '../../core/cache/cache_manager.dart';
import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../models/pulse_model.dart';

/// Repository for Daily Pulse operations
/// All data flows through the API - NEVER direct database access
@lazySingleton
class PulseRepository {
  final ApiClient _apiClient;
  final CacheManager _cacheManager;

  static const String _cacheBox = 'pulse_cache';
  static const String _pulseKey = 'pulse';
  static const int _ttlMinutes = 5;

  PulseRepository(this._apiClient, this._cacheManager);

  /// Get the daily pulse for the current user.
  /// Returns cached data on network failure.
  Future<PulseResponse> getPulse() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiConfig.pulse,
      );

      final pulse = PulseResponse.fromJson(response.data!);
      await _cacheManager.put(
        _cacheBox,
        _pulseKey,
        jsonEncode(response.data),
        ttlMinutes: _ttlMinutes,
      );
      return pulse;
    } catch (e) {
      final cached = await _cacheManager.get(_cacheBox, _pulseKey);
      if (cached != null) {
        return PulseResponse.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      }
      rethrow;
    }
  }

  /// Get detailed pulse breakdown
  Future<PulseBreakdown> getPulseBreakdown() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '${ApiConfig.pulse}/breakdown',
    );

    return PulseBreakdown.fromJson(response.data!);
  }

  /// Refresh the pulse calculation
  /// Call this after significant changes (new subscription, balance update)
  Future<PulseResponse> refreshPulse() async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '${ApiConfig.pulse}/refresh',
    );

    final pulse = PulseResponse.fromJson(response.data!);
    await _cacheManager.put(
      _cacheBox,
      _pulseKey,
      jsonEncode(response.data),
      ttlMinutes: _ttlMinutes,
    );
    return pulse;
  }
}
