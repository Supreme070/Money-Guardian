import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../data/models/email_connection_model.dart';
import '../../../presentation/blocs/email_scanning/email_scanning_bloc.dart';
import '../../../presentation/blocs/email_scanning/email_scanning_event.dart';
import '../../../presentation/blocs/email_scanning/email_scanning_state.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/analytics_service.dart';
import '../../../src/theme/light_color.dart';
import '../auth/oauth_webview_page.dart';

class ConnectEmailPage extends StatefulWidget {
  const ConnectEmailPage({super.key});

  @override
  State<ConnectEmailPage> createState() => _ConnectEmailPageState();
}

class _ConnectEmailPageState extends State<ConnectEmailPage> {
  static const String _redirectUri = 'com.moneyguardian.app://oauth/callback';
  static const String _redirectScheme = 'com.moneyguardian.app://';
  EmailProvider? _currentProvider;

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsService>().logScreenView(screenName: 'ConnectEmail');
    context.read<EmailScanningBloc>().add(const EmailLoadRequested());
  }

  void _connectEmail(EmailProvider provider) {
    _currentProvider = provider;
    context.read<EmailScanningBloc>().add(EmailConnectRequested(
          provider: provider,
          redirectUri: _redirectUri,
        ));
  }

  Future<void> _openOAuthWebView({
    required String authorizationUrl,
    required EmailProvider provider,
  }) async {
    final OAuthResult? result = await Navigator.of(context).push<OAuthResult>(
      MaterialPageRoute<OAuthResult>(
        builder: (_) => OAuthWebViewPage(
          authorizationUrl: authorizationUrl,
          redirectScheme: _redirectScheme,
        ),
      ),
    );

    if (result != null && mounted) {
      context.read<EmailScanningBloc>().add(EmailOAuthCompleteRequested(
            provider: provider,
            code: result.code,
            redirectUri: _redirectUri,
            state: result.state,
          ));
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
          'Email Link',
          style: GoogleFonts.mulish(
            color: LightColor.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: BlocConsumer<EmailScanningBloc, EmailScanningState>(
        listener: (context, state) {
          if (state is EmailOAuthReady) {
            final EmailProvider provider =
                _currentProvider ?? state.oauthUrl.provider;
            _openOAuthWebView(
              authorizationUrl: state.oauthUrl.authorizationUrl,
              provider: provider,
            );
          } else if (state is EmailConnectionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Email connected successfully!'), backgroundColor: LightColor.safe),
            );
            Navigator.pop(context, true);
          }
        },
        builder: (context, state) {
          if (state is EmailScanningLoading) {
            return const Center(child: CircularProgressIndicator(color: LightColor.primary));
          }

          if (state is EmailScanningProRequired) {
            return _buildProRequiredView();
          }

          if (state is EmailScanningLoaded) {
            return _buildMainContent(state);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildMainContent(EmailScanningLoaded state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          
          // Header Card
          _buildInfoHero(),
          
          const SizedBox(height: 32),

          if (state.hasConnections) ...[
            Text('Connected Accounts', style: GoogleFonts.mulish(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ...state.connections.map((conn) => _buildConnectionCard(conn)),
            const SizedBox(height: 32),
          ],

          Text('Link New Email', style: GoogleFonts.mulish(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _buildProviderSelection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInfoHero() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: LightColor.textPrimary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: LightColor.primary.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.alternate_email, color: LightColor.primary, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            'The Deep Scan',
            style: GoogleFonts.mulish(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your email to find subscription receipts and confirmations that your bank might miss.',
            style: GoogleFonts.mulish(color: Colors.white.withOpacity(0.6), fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(EmailConnectionModel connection) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: LightColor.surface),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(color: LightColor.surface, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.mail_outline, color: LightColor.textPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(connection.emailAddress, style: GoogleFonts.mulish(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text('Last scanned 2h ago', style: GoogleFonts.mulish(color: LightColor.textTertiary, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: LightColor.safe, size: 20),
        ],
      ),
    );
  }

  Widget _buildProviderSelection() {
    return Column(
      children: [
        _buildProviderTile('Gmail', 'Google Account', Icons.mail, const Color(0xFFEA4335), EmailProvider.gmail),
        const SizedBox(height: 12),
        _buildProviderTile('Outlook', 'Microsoft Account', Icons.email, const Color(0xFF0078D4), EmailProvider.outlook),
        const SizedBox(height: 12),
        _buildProviderTile('iCloud Mail', 'Apple Account', Icons.alternate_email, LightColor.textTertiary, EmailProvider.outlook, isDisabled: true),
      ],
    );
  }

  Widget _buildProviderTile(String title, String subtitle, IconData icon, Color color, EmailProvider provider, {bool isDisabled = false}) {
    return InkWell(
      onTap: isDisabled ? null : () => _connectEmail(provider),
      borderRadius: BorderRadius.circular(20),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: LightColor.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.mulish(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(isDisabled ? 'Coming Soon' : subtitle, style: GoogleFonts.mulish(color: LightColor.textTertiary, fontSize: 12)),
                  ],
                ),
              ),
              if (!isDisabled) const Icon(Icons.add_link, color: LightColor.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProRequiredView() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: LightColor.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.stars_outlined, size: 48, color: LightColor.primary),
          ),
          const SizedBox(height: 32),
          Text(
            'Unlock Deep Scan',
            style: GoogleFonts.mulish(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -1),
          ),
          const SizedBox(height: 12),
          Text(
            'Email scanning is a Pro feature that finds hidden subscriptions in your inbox automatically.',
            textAlign: TextAlign.center,
            style: GoogleFonts.mulish(color: LightColor.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/pro-upgrade'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LightColor.textPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Upgrade to Pro', style: GoogleFonts.mulish(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
