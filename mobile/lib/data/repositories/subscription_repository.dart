import 'package:injectable/injectable.dart';

import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../models/subscription_model.dart';

/// Repository for subscription operations
/// All data flows through the API - NEVER direct database access
@lazySingleton
class SubscriptionRepository {
  final ApiClient _apiClient;

  SubscriptionRepository(this._apiClient);

  /// Get all subscriptions for the current user
  Future<SubscriptionListResponse> getSubscriptions({
    bool? isActive,
    String? aiFlag,
  }) async {
    final Map<String, dynamic> queryParams = {};
    if (isActive != null) queryParams['is_active'] = isActive;
    if (aiFlag != null) queryParams['ai_flag'] = aiFlag;

    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConfig.subscriptions,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    return SubscriptionListResponse.fromJson(response.data!);
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

    return SubscriptionModel.fromJson(response.data!);
  }

  /// Delete a subscription (soft delete)
  Future<void> deleteSubscription(String id) async {
    await _apiClient.delete<void>(
      ApiConfig.subscriptionById(id),
    );
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

  /// Get AI flag summary for current user
  Future<AIFlagSummaryResponse> getAIFlagSummary() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConfig.subscriptionsFlagsSummary,
    );

    return AIFlagSummaryResponse.fromJson(response.data!);
  }
}
