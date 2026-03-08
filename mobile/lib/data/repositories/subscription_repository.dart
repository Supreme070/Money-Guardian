import 'dart:convert';

import 'package:injectable/injectable.dart';

import '../../core/cache/cache_manager.dart';
import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../models/subscription_model.dart';

/// Repository for subscription operations
/// All data flows through the API - NEVER direct database access
@lazySingleton
class SubscriptionRepository {
  final ApiClient _apiClient;
  final CacheManager _cacheManager;

  static const String _cacheBox = 'subscriptions_cache';
  static const String _listKey = 'subscriptions_list';
  static const int _ttlMinutes = 15;

  SubscriptionRepository(this._apiClient, this._cacheManager);

  /// Get all subscriptions for the current user.
  /// Returns cached data on network failure.
  Future<SubscriptionListResponse> getSubscriptions({
    bool? isActive,
    String? aiFlag,
  }) async {
    final Map<String, dynamic> queryParams = {};
    if (isActive != null) queryParams['is_active'] = isActive;
    if (aiFlag != null) queryParams['ai_flag'] = aiFlag;

    // Only cache the default (unfiltered) list
    final bool useCache = queryParams.isEmpty;

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiConfig.subscriptions,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final result = SubscriptionListResponse.fromJson(response.data!);
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
          return SubscriptionListResponse.fromJson(
            jsonDecode(cached) as Map<String, dynamic>,
          );
        }
      }
      rethrow;
    }
  }

  /// Get a single subscription by ID
  Future<SubscriptionModel> getSubscriptionById(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConfig.subscriptionById(id),
    );

    return SubscriptionModel.fromJson(response.data!);
  }

  /// Create a new subscription
  Future<SubscriptionModel> createSubscription(
    SubscriptionCreateRequest request,
  ) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.subscriptions,
      data: request.toJson(),
    );

    // Invalidate list cache after mutation
    await _cacheManager.clear(_cacheBox);
    return SubscriptionModel.fromJson(response.data!);
  }

  /// Update an existing subscription
  Future<SubscriptionModel> updateSubscription(
    String id,
    SubscriptionUpdateRequest request,
  ) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      ApiConfig.subscriptionById(id),
      data: request.toJson(),
    );

    await _cacheManager.clear(_cacheBox);
    return SubscriptionModel.fromJson(response.data!);
  }

  /// Delete a subscription (soft delete)
  Future<void> deleteSubscription(String id) async {
    await _apiClient.delete<void>(
      ApiConfig.subscriptionById(id),
    );
    await _cacheManager.clear(_cacheBox);
  }

  /// Pause a subscription
  Future<SubscriptionModel> pauseSubscription(String id) async {
    return updateSubscription(
      id,
      const SubscriptionUpdateRequest(isPaused: true),
    );
  }

  /// Resume a subscription
  Future<SubscriptionModel> resumeSubscription(String id) async {
    return updateSubscription(
      id,
      const SubscriptionUpdateRequest(isPaused: false),
    );
  }

  /// Cancel a subscription
  Future<SubscriptionModel> cancelSubscription(String id) async {
    return updateSubscription(
      id,
      const SubscriptionUpdateRequest(isActive: false),
    );
  }

  /// Analyze subscriptions and apply AI flags
  Future<AnalyzeResponse> analyzeSubscriptions() async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.subscriptionsAnalyze,
    );

    return AnalyzeResponse.fromJson(response.data!);
  }

  /// Get subscription history (cancelled/inactive/deleted subscriptions)
  Future<SubscriptionListResponse> getSubscriptionHistory() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConfig.subscriptions,
      queryParameters: {
        'include_inactive': true,
        'include_deleted': true,
      },
    );

    final fullList = SubscriptionListResponse.fromJson(response.data!);
    // Filter to only inactive subs (history = no longer active)
    final historySubs = fullList.subscriptions
        .where((s) => !s.isActive)
        .toList();

    return SubscriptionListResponse(
      subscriptions: historySubs,
      totalCount: historySubs.length,
      monthlyTotal: 0,
      yearlyTotal: 0,
      flaggedCount: 0,
    );
  }

  /// Get AI flag summary for current user
  Future<AIFlagSummaryResponse> getAIFlagSummary() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConfig.subscriptionsFlagsSummary,
    );

    return AIFlagSummaryResponse.fromJson(response.data!);
  }
}
