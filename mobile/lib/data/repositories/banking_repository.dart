import 'package:injectable/injectable.dart';

import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../models/bank_connection_model.dart';

/// Repository for banking operations (Pro feature)
/// All data flows through the API - NEVER direct database access
@lazySingleton
class BankingRepository {
  final ApiClient _apiClient;

  BankingRepository(this._apiClient);

  /// Create a link token for initiating Plaid/Mono/Stitch Link
  Future<LinkTokenResponse> createLinkToken({
    BankingProvider provider = BankingProvider.plaid,
  }) async {
    final request = CreateLinkTokenRequest(provider: provider);

    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.bankingLinkToken,
      data: request.toJson(),
    );

    return LinkTokenResponse.fromJson(response.data!);
  }

  /// Exchange public token for access token after Link completion
  Future<BankConnectionModel> exchangePublicToken({
    required String publicToken,
    BankingProvider provider = BankingProvider.plaid,
  }) async {
    final request = ExchangeTokenRequest(
      publicToken: publicToken,
      provider: provider,
    );

    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.bankingExchange,
      data: request.toJson(),
    );

    return BankConnectionModel.fromJson(response.data!);
  }

  /// Get all bank connections for the current user
  Future<BankConnectionListResponse> getBankConnections() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConfig.banking,
    );

    return BankConnectionListResponse.fromJson(response.data!);
  }

  /// Get a single bank connection by ID
  Future<BankConnectionModel> getBankConnectionById(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConfig.bankingById(id),
    );

    return BankConnectionModel.fromJson(response.data!);
  }

  /// Sync transactions for a bank connection
  Future<SyncTransactionsResponse> syncTransactions(String connectionId) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.bankingSync(connectionId),
    );

    return SyncTransactionsResponse.fromJson(response.data!);
  }

  /// Sync balances for a bank connection
  Future<BankConnectionModel> syncBalances(String connectionId) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.bankingSyncBalances(connectionId),
    );

    return BankConnectionModel.fromJson(response.data!);
  }

  /// Disconnect a bank connection
  Future<void> disconnectBank(String connectionId) async {
    await _apiClient.delete<void>(
      ApiConfig.bankingById(connectionId),
    );
  }

  /// Get total balance across all connected accounts
  Future<double> getTotalBalance() async {
    final connections = await getBankConnections();
    return connections.totalBalance;
  }

  /// Get recurring transactions detected by the bank provider
  Future<RecurringTransactionsResponse> getRecurringTransactions(
      String connectionId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConfig.bankingRecurring(connectionId),
    );

    return RecurringTransactionsResponse.fromJson(response.data!);
  }

  /// Convert a recurring transaction to a subscription
  Future<void> convertRecurringToSubscription({
    required String connectionId,
    required ConvertRecurringToSubscriptionRequest request,
  }) async {
    await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.bankingRecurringConvert(connectionId, request.streamId),
      data: request.toJson(),
    );
  }
}
