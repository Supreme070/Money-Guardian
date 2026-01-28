import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// OAuth callback data parsed from deep link
class OAuthCallbackData {
  final String code;
  final String? state;
  final String? error;
  final String? errorDescription;

  const OAuthCallbackData({
    required this.code,
    this.state,
    this.error,
    this.errorDescription,
  });

  /// Check if callback contains an error
  bool get hasError => error != null && error!.isNotEmpty;

  /// Check if callback is valid (has code and no error)
  bool get isValid => !hasError && code.isNotEmpty;

  /// Create from URI
  factory OAuthCallbackData.fromUri(Uri uri) {
    final params = uri.queryParameters;
    return OAuthCallbackData(
      code: params['code'] ?? '',
      state: params['state'],
      error: params['error'],
      errorDescription: params['error_description'],
    );
  }
}

/// Pending OAuth session data
class PendingOAuthSession {
  final String provider;
  final String redirectUri;
  final String? state;
  final DateTime createdAt;

  const PendingOAuthSession({
    required this.provider,
    required this.redirectUri,
    this.state,
    required this.createdAt,
  });

  /// Check if session is expired (5 minutes timeout)
  bool get isExpired =>
      DateTime.now().difference(createdAt).inMinutes > 5;
}

/// Service for handling deep links including OAuth callbacks
@lazySingleton
class DeepLinkService {
  static const String _scheme = 'com.moneyguardian.app';
  static const String _oauthPath = '/oauth/callback';

  final AppLinks _appLinks = AppLinks();

  final StreamController<OAuthCallbackData> _oauthCallbackController =
      StreamController<OAuthCallbackData>.broadcast();

  StreamSubscription<Uri>? _linkSubscription;
  PendingOAuthSession? _pendingSession;
  bool _initialized = false;

  /// Stream of OAuth callback events
  Stream<OAuthCallbackData> get oauthCallbacks => _oauthCallbackController.stream;

  /// Check if there's a pending OAuth session
  bool get hasPendingSession =>
      _pendingSession != null && !_pendingSession!.isExpired;

  /// Get current pending session
  PendingOAuthSession? get pendingSession =>
      hasPendingSession ? _pendingSession : null;

  /// Initialize the deep link service
  /// Must be called once at app startup
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Handle initial link that launched the app
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting initial link: $e');
      }
    }

    // Listen for incoming links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (error) {
        if (kDebugMode) {
          debugPrint('Error in deep link stream: $error');
        }
      },
    );
  }

  /// Start OAuth session - called before opening OAuth URL
  void startOAuthSession({
    required String provider,
    required String redirectUri,
    String? state,
  }) {
    _pendingSession = PendingOAuthSession(
      provider: provider,
      redirectUri: redirectUri,
      state: state,
      createdAt: DateTime.now(),
    );

    if (kDebugMode) {
      debugPrint('OAuth session started for provider: $provider');
    }
  }

  /// Clear pending session
  void clearPendingSession() {
    _pendingSession = null;
  }

  /// Handle incoming deep link
  void _handleDeepLink(Uri uri) {
    if (kDebugMode) {
      debugPrint('Deep link received: $uri');
    }

    // Check if this is an OAuth callback
    if (uri.scheme == _scheme && uri.path == _oauthPath) {
      _handleOAuthCallback(uri);
    }
  }

  /// Handle OAuth callback
  void _handleOAuthCallback(Uri uri) {
    final data = OAuthCallbackData.fromUri(uri);

    if (kDebugMode) {
      debugPrint('OAuth callback received: code=${data.code.isNotEmpty}, error=${data.error}');
    }

    // Verify state if we have a pending session with state
    if (_pendingSession?.state != null && data.state != null) {
      if (_pendingSession!.state != data.state) {
        // State mismatch - potential CSRF attack
        _oauthCallbackController.add(const OAuthCallbackData(
          code: '',
          error: 'invalid_state',
          errorDescription: 'OAuth state mismatch. Please try again.',
        ));
        clearPendingSession();
        return;
      }
    }

    _oauthCallbackController.add(data);
  }

  /// Dispose the service
  void dispose() {
    _linkSubscription?.cancel();
    _oauthCallbackController.close();
  }
}
