import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../src/theme/light_color.dart';

/// Result returned from the OAuth WebView after a successful authorization.
class OAuthResult {
  final String code;
  final String? state;

  const OAuthResult({required this.code, this.state});
}

/// A reusable in-app WebView page for OAuth authorization flows.
///
/// Loads the [authorizationUrl] and intercepts navigation to detect the
/// redirect back to [redirectScheme]. When the redirect is detected, the
/// `code` and `state` query parameters are parsed and returned as an
/// [OAuthResult] via [Navigator.pop].
class OAuthWebViewPage extends StatefulWidget {
  final String authorizationUrl;
  final String redirectScheme;

  const OAuthWebViewPage({
    super.key,
    required this.authorizationUrl,
    required this.redirectScheme,
  });

  @override
  State<OAuthWebViewPage> createState() => _OAuthWebViewPageState();
}

class _OAuthWebViewPageState extends State<OAuthWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onPageStarted: _onPageStarted,
          onPageFinished: _onPageFinished,
          onWebResourceError: _onWebResourceError,
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final String url = request.url;

    // Check if the URL starts with the redirect scheme (e.g. com.moneyguardian.app://)
    if (url.startsWith(widget.redirectScheme)) {
      _handleRedirect(url);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  void _handleRedirect(String url) {
    final Uri uri = Uri.parse(url);
    final String? code = uri.queryParameters['code'];
    final String? state = uri.queryParameters['state'];

    if (code != null && code.isNotEmpty) {
      Navigator.of(context).pop(OAuthResult(code: code, state: state));
    } else {
      // No authorization code in redirect - treat as cancellation / error
      final String? error = uri.queryParameters['error'];
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = error ?? 'Authorization was cancelled or failed.';
        });
      }
    }
  }

  void _onPageStarted(String url) {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
  }

  void _onPageFinished(String url) {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onWebResourceError(WebResourceError error) {
    // Only show error if it is a main frame error (not subresource)
    if (error.isForMainFrame ?? false) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = error.description;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColor.background,
      appBar: AppBar(
        backgroundColor: LightColor.background,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Sign In',
          style: GoogleFonts.mulish(
            color: LightColor.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: LightColor.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _hasError ? _buildErrorView() : _buildWebView(),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: LightColor.accent),
          ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: LightColor.freeze.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: LightColor.freeze,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to Load',
              style: GoogleFonts.mulish(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: LightColor.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.mulish(
                fontSize: 14,
                color: LightColor.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _isLoading = true;
                  });
                  _controller.loadRequest(
                    Uri.parse(widget.authorizationUrl),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: LightColor.textPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Try Again',
                  style: GoogleFonts.mulish(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
