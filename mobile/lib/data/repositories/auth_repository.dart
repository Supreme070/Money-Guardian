import 'package:injectable/injectable.dart';

import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../models/auth_models.dart';
import '../models/user_model.dart';

/// Repository for authentication operations
/// All data flows through the API - NEVER direct database access
@lazySingleton
class AuthRepository {
  final ApiClient _apiClient;
  final SecureStorage _secureStorage;

  AuthRepository(this._apiClient, this._secureStorage);

  /// Register a new user
  Future<TokenResponse> register(RegisterRequest request) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.authRegister,
      data: request.toJson(),
    );

    final tokenResponse = TokenResponse.fromJson(response.data!);
    await _saveTokens(tokenResponse);
    return tokenResponse;
  }

  /// Login with email and password
  Future<TokenResponse> login(LoginRequest request) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.authLogin,
      data: request.toJson(),
    );

    final tokenResponse = TokenResponse.fromJson(response.data!);
    await _saveTokens(tokenResponse);
    return tokenResponse;
  }

  /// Refresh access token
  Future<TokenResponse> refreshToken() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken == null) {
      throw Exception('No refresh token available');
    }

    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.authRefresh,
      data: RefreshRequest(refreshToken: refreshToken).toJson(),
    );

    final tokenResponse = TokenResponse.fromJson(response.data!);
    await _saveTokens(tokenResponse);
    return tokenResponse;
  }

  /// Logout user
  Future<void> logout() async {
    try {
      await _apiClient.post<void>(ApiConfig.authLogout);
    } finally {
      await _secureStorage.clearAuthData();
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await _secureStorage.getAuthToken();
    return token != null;
  }

  /// Get current user profile
  Future<UserModel> getCurrentUser() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConfig.usersMe,
    );
    return UserModel.fromJson(response.data!);
  }

  /// Update user profile
  Future<UserModel> updateUser(UserUpdateRequest request) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      ApiConfig.usersMe,
      data: request.toJson(),
    );
    return UserModel.fromJson(response.data!);
  }

  /// Save tokens to secure storage
  Future<void> _saveTokens(TokenResponse tokens) async {
    await Future.wait([
      _secureStorage.setAuthToken(tokens.accessToken),
      _secureStorage.setRefreshToken(tokens.refreshToken),
    ]);
  }

  /// Clear all auth data
  Future<void> clearAuthData() async {
    await _secureStorage.clearAuthData();
  }

  /// Request password reset
  /// Returns a message regardless of whether email exists (security)
  Future<MessageResponse> requestPasswordReset(
      PasswordResetRequest request) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.authPasswordResetRequest,
      data: request.toJson(),
    );
    return MessageResponse.fromJson(response.data!);
  }

  /// Confirm password reset with token
  Future<MessageResponse> confirmPasswordReset(
      PasswordResetConfirm request) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.authPasswordResetConfirm,
      data: request.toJson(),
    );
    return MessageResponse.fromJson(response.data!);
  }

  /// Register FCM token for push notifications
  Future<void> registerFcmToken(String token, String deviceType) async {
    await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.usersFcmToken,
      data: {
        'token': token,
        'device_type': deviceType,
      },
    );
  }

  /// Unregister FCM token (called on logout)
  Future<void> unregisterFcmToken() async {
    await _apiClient.delete<Map<String, dynamic>>(ApiConfig.usersFcmToken);
  }
}
