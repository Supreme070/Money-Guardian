import 'dart:convert';

import 'package:injectable/injectable.dart';

import '../../core/cache/cache_manager.dart';
import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../models/alert_model.dart';

/// Repository for alert operations
/// All data flows through the API - NEVER direct database access
@lazySingleton
class AlertRepository {
  final ApiClient _apiClient;
  final CacheManager _cacheManager;

  static const String _cacheBox = 'alerts_cache';
  static const String _listKey = 'alerts_list';
  static const int _ttlMinutes = 5;

  AlertRepository(this._apiClient, this._cacheManager);

  /// Get all alerts for the current user.
  /// Returns cached data on network failure.
  Future<AlertListResponse> getAlerts({
    bool? unreadOnly,
    String? severity,
  }) async {
    final Map<String, dynamic> queryParams = {};
    if (unreadOnly != null && unreadOnly) queryParams['unread_only'] = true;
    if (severity != null) queryParams['severity'] = severity;

    final bool useCache = queryParams.isEmpty;

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiConfig.alerts,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final result = AlertListResponse.fromJson(response.data!);
      if (useCache) {
        await _cacheManager.put(
          _cacheBox,
          _listKey,
          jsonEncode(response.data),
          ttlMinutes: _ttlMinutes,
        );
      }
      return result;
    } catch (e) {
      if (useCache) {
        final cached = await _cacheManager.get(_cacheBox, _listKey);
        if (cached != null) {
          return AlertListResponse.fromJson(
            jsonDecode(cached) as Map<String, dynamic>,
          );
        }
      }
      rethrow;
    }
  }

  /// Get a single alert by ID
  Future<AlertModel> getAlertById(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConfig.alertById(id),
    );

    return AlertModel.fromJson(response.data!);
  }

  /// Mark alerts as read
  Future<void> markAlertsAsRead(List<String> alertIds) async {
    await _apiClient.post<void>(
      ApiConfig.alertsMarkRead,
      data: AlertMarkReadRequest(alertIds: alertIds).toJson(),
    );
    await _cacheManager.clear(_cacheBox);
  }

  /// Dismiss an alert
  Future<void> dismissAlert(String alertId) async {
    await _apiClient.post<void>(
      ApiConfig.alertDismiss(alertId),
    );
    await _cacheManager.clear(_cacheBox);
  }

  /// Dismiss multiple alerts
  Future<void> dismissAlerts(List<String> alertIds) async {
    await Future.wait(
      alertIds.map((id) => dismissAlert(id)),
    );
  }

  /// Get unread alerts count
  Future<int> getUnreadCount() async {
    final response = await getAlerts(unreadOnly: true);
    return response.unreadCount;
  }

  /// Get critical alerts count
  Future<int> getCriticalCount() async {
    final response = await getAlerts(severity: 'critical');
    return response.criticalCount;
  }
}
