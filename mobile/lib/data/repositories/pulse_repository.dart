import 'package:injectable/injectable.dart';

import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../models/pulse_model.dart';

/// Repository for Daily Pulse operations
/// All data flows through the API - NEVER direct database access
@lazySingleton
class PulseRepository {
  final ApiClient _apiClient;

  PulseRepository(this._apiClient);

  /// Get the daily pulse for the current user
  /// This is the main home screen data
  Future<PulseResponse> getPulse() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConfig.pulse,
    );

    return PulseResponse.fromJson(response.data!);
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

    return PulseResponse.fromJson(response.data!);
  }
}
