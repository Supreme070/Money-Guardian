import 'package:injectable/injectable.dart';

import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../models/email_connection_model.dart';
import '../models/subscription_model.dart';

/// Repository for email scanning operations (Pro feature)
/// All data flows through the API - NEVER direct database access
@lazySingleton
class EmailRepository {
  final ApiClient _apiClient;

  EmailRepository(this._apiClient);

  /// Get supported email providers
  Future<List<EmailProvider>> getSupportedProviders() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConfig.emailProviders,
    );

    final providers = response.data!['providers'] as List<dynamic>;
    return providers
        .map((p) => EmailProvider.fromJson(p as String))
        .toList();
  }

  /// Start OAuth flow for connecting an email account
  Future<OAuthUrlResponse> startOAuthFlow({
    required EmailProvider provider,
    required String redirectUri,
  }) async {
    final request = StartOAuthRequest(
      provider: provider,
      redirectUri: redirectUri,
    );

    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.emailOAuthStart,
      data: request.toJson(),
    );

    return OAuthUrlResponse.fromJson(response.data!);
  }

  /// Complete OAuth flow by exchanging authorization code
  Future<EmailConnectionModel> completeOAuthFlow({
    required EmailProvider provider,
    required String code,
    required String redirectUri,
    String? state,
  }) async {
    final request = CompleteOAuthRequest(
      provider: provider,
      code: code,
      redirectUri: redirectUri,
      state: state,
    );

    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.emailOAuthComplete,
      data: request.toJson(),
    );

    return EmailConnectionModel.fromJson(response.data!);
  }

  /// Get all email connections for the current user
  Future<EmailConnectionListResponse> getEmailConnections() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConfig.email,
    );

    return EmailConnectionListResponse.fromJson(response.data!);
  }

  /// Get a single email connection by ID
  Future<EmailConnectionModel> getEmailConnectionById(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConfig.emailById(id),
    );

    return EmailConnectionModel.fromJson(response.data!);
  }

  /// Scan emails for subscriptions
  Future<ScanResultResponse> scanEmails(
    String connectionId, {
    int maxEmails = 50,
  }) async {
    final request = ScanEmailsRequest(maxEmails: maxEmails);

    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.emailScan(connectionId),
      data: request.toJson(),
    );

    return ScanResultResponse.fromJson(response.data!);
  }

  /// Get scanned emails with subscription detections
  Future<ScannedEmailListResponse> getScannedEmails(
    String connectionId, {
    bool unprocessedOnly = false,
    double minConfidence = 0.5,
    int limit = 100,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConfig.emailScanned(connectionId),
      queryParameters: {
        'unprocessed_only': unprocessedOnly,
        'min_confidence': minConfidence,
        'limit': limit,
      },
    );

    return ScannedEmailListResponse.fromJson(response.data!);
  }

  /// Mark a scanned email as processed
  Future<ScannedEmailModel> markEmailProcessed(
    String connectionId,
    String emailId, {
    String? subscriptionId,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.emailScannedProcess(connectionId, emailId),
      data: {
        if (subscriptionId != null) 'subscription_id': subscriptionId,
      },
    );

    return ScannedEmailModel.fromJson(response.data!);
  }

  /// Disconnect an email account
  Future<void> disconnectEmail(String connectionId) async {
    await _apiClient.delete<void>(
      ApiConfig.emailById(connectionId),
    );
  }

  /// Get known subscription senders
  Future<List<KnownSenderModel>> getKnownSenders() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConfig.emailKnownSenders,
    );

    final senders = response.data!['senders'] as List<dynamic>;
    return senders
        .map((s) => KnownSenderModel.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Convert a scanned email to a subscription
  Future<SubscriptionModel> convertEmailToSubscription(
    String connectionId,
    String emailId, {
    String? name,
    double? amount,
    String? billingCycle,
    DateTime? nextBillingDate,
    String? color,
    String? description,
  }) async {
    final request = ConvertToSubscriptionRequest(
      name: name,
      amount: amount,
      billingCycle: billingCycle,
      nextBillingDate: nextBillingDate,
      color: color,
      description: description,
    );

    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.emailScannedConvert(connectionId, emailId),
      data: request.toJson(),
    );

    return SubscriptionModel.fromJson(response.data!);
  }
}
