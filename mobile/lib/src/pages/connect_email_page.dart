import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/deep_link_service.dart';
import '../../data/models/email_connection_model.dart';
import '../../presentation/blocs/email_scanning/email_scanning_bloc.dart';
import '../../presentation/blocs/email_scanning/email_scanning_event.dart';
import '../../presentation/blocs/email_scanning/email_scanning_state.dart';
import '../theme/light_color.dart';

/// Page for connecting and managing email accounts for subscription scanning (Pro feature)
class ConnectEmailPage extends StatefulWidget {
  const ConnectEmailPage({Key? key}) : super(key: key);

  @override
  State<ConnectEmailPage> createState() => _ConnectEmailPageState();
}

class _ConnectEmailPageState extends State<ConnectEmailPage> {
  static const String _redirectUri = 'com.moneyguardian.app://oauth/callback';

  late final DeepLinkService _deepLinkService;
  EmailProvider? _currentProvider;

  @override
  void initState() {
    super.initState();
    _deepLinkService = GetIt.I<DeepLinkService>();
    context.read<EmailScanningBloc>().add(const EmailLoadRequested());
  }

  void _connectEmail(EmailProvider provider) {
    _currentProvider = provider;
    context.read<EmailScanningBloc>().add(EmailConnectRequested(
          provider: provider,
          redirectUri: _redirectUri,
        ));
  }

  void _scanEmails(String connectionId) {
    context.read<EmailScanningBloc>().add(EmailScanRequested(
          connectionId: connectionId,
          maxEmails: 100,
        ));
  }

  void _disconnectEmail(String connectionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Disconnect Email?',
          style: GoogleFonts.mulish(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will remove the email connection and stop scanning for subscriptions. Previously detected subscriptions will remain.',
          style: GoogleFonts.mulish(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.mulish(color: LightColor.subTitleTextColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<EmailScanningBloc>().add(EmailDisconnectRequested(
                    connectionId: connectionId,
                  ));
            },
            child: Text(
              'Disconnect',
              style: GoogleFonts.mulish(color: LightColor.freeze),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openOAuthFlow(OAuthUrlResponse oauthUrl) async {
    // Start OAuth session for deep link callback handling
    _deepLinkService.startOAuthSession(
      provider: _currentProvider?.name ?? 'unknown',
      redirectUri: _redirectUri,
      state: oauthUrl.state,
    );

    // Parse and launch the OAuth URL
    final uri = Uri.tryParse(oauthUrl.authorizationUrl);
    if (uri == null) {
      _showErrorSnackBar('Invalid authorization URL');
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _showErrorSnackBar('Could not open browser. Please try again.');
        _deepLinkService.clearPendingSession();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to open authorization page: $e');
      _deepLinkService.clearPendingSession();
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.mulish()),
        backgroundColor: LightColor.freeze,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [LightColor.navyBlue1, LightColor.navyBlue2],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.email_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email Scanning',
                      style: GoogleFonts.mulish(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pro Feature',
                      style: GoogleFonts.mulish(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: LightColor.yellow,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Connect your email to automatically find subscription confirmations, receipts, and billing reminders.',
            style: GoogleFonts.mulish(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect Email Provider',
          style: GoogleFonts.mulish(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: LightColor.titleTextColor,
          ),
        ),
        const SizedBox(height: 16),
        _buildProviderCard(
          provider: EmailProvider.gmail,
          title: 'Gmail',
          subtitle: 'Google Account',
          logoAsset: null,
          primaryColor: const Color(0xFFEA4335),
        ),
        const SizedBox(height: 12),
        _buildProviderCard(
          provider: EmailProvider.outlook,
          title: 'Outlook',
          subtitle: 'Microsoft Account',
          logoAsset: null,
          primaryColor: const Color(0xFF0078D4),
        ),
        const SizedBox(height: 12),
        _buildProviderCard(
          provider: EmailProvider.yahoo,
          title: 'Yahoo Mail',
          subtitle: 'Coming Soon',
          logoAsset: null,
          primaryColor: const Color(0xFF6001D2),
          isDisabled: true,
        ),
      ],
    );
  }

  Widget _buildProviderCard({
    required EmailProvider provider,
    required String title,
    required String subtitle,
    required String? logoAsset,
    required Color primaryColor,
    bool isDisabled = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : () => _connectEmail(provider),
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: LightColor.lightGrey,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LightColor.grey.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getProviderIcon(provider),
                    color: primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.mulish(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: LightColor.titleTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.mulish(
                          fontSize: 12,
                          color: isDisabled
                              ? LightColor.grey
                              : LightColor.subTitleTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDisabled)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: LightColor.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Soon',
                      style: GoogleFonts.mulish(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: LightColor.darkgrey,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: LightColor.grey,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectedEmails(EmailScanningLoaded state) {
    if (!state.hasConnections) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Connected Emails',
              style: GoogleFonts.mulish(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: LightColor.titleTextColor,
              ),
            ),
            if (state.unprocessedCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: LightColor.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${state.unprocessedCount} new',
                  style: GoogleFonts.mulish(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: LightColor.accent,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ...state.connections.map((conn) => _buildConnectionCard(conn)),
      ],
    );
  }

  Widget _buildConnectionCard(EmailConnectionModel connection) {
    final statusColor = _getStatusColor(connection.status);
    final statusText = _getStatusText(connection.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LightColor.lightGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getProviderColor(connection.provider).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getProviderIcon(connection.provider),
                  color: _getProviderColor(connection.provider),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.emailAddress,
                      style: GoogleFonts.mulish(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: LightColor.titleTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: GoogleFonts.mulish(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'scan') {
                    _scanEmails(connection.id);
                  } else if (value == 'disconnect') {
                    _disconnectEmail(connection.id);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'scan',
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded,
                            size: 18, color: LightColor.accent),
                        const SizedBox(width: 12),
                        Text('Scan Now',
                            style: GoogleFonts.mulish(fontSize: 14)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'disconnect',
                    child: Row(
                      children: [
                        const Icon(Icons.link_off_rounded,
                            size: 18, color: LightColor.freeze),
                        const SizedBox(width: 12),
                        Text('Disconnect',
                            style: GoogleFonts.mulish(
                                fontSize: 14, color: LightColor.freeze)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: LightColor.lightGrey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.more_horiz_rounded,
                    color: LightColor.darkgrey,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          if (connection.lastScanAt != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: LightColor.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  'Last scanned: ${_formatLastScan(connection.lastScanAt!)}',
                  style: GoogleFonts.mulish(
                    fontSize: 11,
                    color: LightColor.grey,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScannedEmails(EmailScanningLoaded state) {
    if (state.scannedEmails == null || state.scannedEmails!.isEmpty) {
      return const SizedBox.shrink();
    }

    final unprocessed =
        state.scannedEmails!.where((e) => !e.isProcessed).toList();

    if (unprocessed.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detected Subscriptions',
          style: GoogleFonts.mulish(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: LightColor.titleTextColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Review and add these to your subscriptions',
          style: GoogleFonts.mulish(
            fontSize: 13,
            color: LightColor.subTitleTextColor,
          ),
        ),
        const SizedBox(height: 16),
        ...unprocessed.take(5).map((email) => _buildScannedEmailCard(email)),
        if (unprocessed.length > 5)
          TextButton(
            onPressed: () {
              // Show all scanned emails
            },
            child: Text(
              'View ${unprocessed.length - 5} more',
              style: GoogleFonts.mulish(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: LightColor.accent,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScannedEmailCard(ScannedEmailModel email) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LightColor.lightGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: LightColor.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: LightColor.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email.merchantName ?? email.fromName ?? email.fromAddress,
                  style: GoogleFonts.mulish(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: LightColor.titleTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email.subject,
                  style: GoogleFonts.mulish(
                    fontSize: 12,
                    color: LightColor.subTitleTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (email.detectedAmount != null)
                Text(
                  '\$${email.detectedAmount!.toStringAsFixed(2)}',
                  style: GoogleFonts.mulish(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: LightColor.titleTextColor,
                  ),
                ),
              _buildConfidenceBadge(email.confidenceScore),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge(double confidence) {
    Color color;
    String label;

    if (confidence >= 0.8) {
      color = LightColor.safe;
      label = 'High';
    } else if (confidence >= 0.5) {
      color = LightColor.yellow;
      label = 'Medium';
    } else {
      color = LightColor.grey;
      label = 'Low';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.mulish(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildProRequiredCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LightColor.yellow.withOpacity(0.15),
            LightColor.yellow.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LightColor.yellow.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: LightColor.yellow.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: LightColor.yellow2,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Upgrade to Pro',
            style: GoogleFonts.mulish(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: LightColor.titleTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Email scanning requires a Pro subscription. Automatically find subscriptions from your email receipts and confirmations.',
            style: GoogleFonts.mulish(
              fontSize: 14,
              color: LightColor.subTitleTextColor,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/pro-upgrade');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: LightColor.yellow2,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'View Pro Plans',
                style: GoogleFonts.mulish(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: LightColor.accent),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: LightColor.freeze,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: GoogleFonts.mulish(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: LightColor.titleTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.mulish(
                fontSize: 13,
                color: LightColor.subTitleTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                context.read<EmailScanningBloc>().add(const EmailClearError());
              },
              child: Text(
                'Try again',
                style: GoogleFonts.mulish(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: LightColor.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getProviderIcon(EmailProvider provider) {
    switch (provider) {
      case EmailProvider.gmail:
        return Icons.mail_rounded;
      case EmailProvider.outlook:
        return Icons.email_rounded;
      case EmailProvider.yahoo:
        return Icons.alternate_email_rounded;
    }
  }

  Color _getProviderColor(EmailProvider provider) {
    switch (provider) {
      case EmailProvider.gmail:
        return const Color(0xFFEA4335);
      case EmailProvider.outlook:
        return const Color(0xFF0078D4);
      case EmailProvider.yahoo:
        return const Color(0xFF6001D2);
    }
  }

  Color _getStatusColor(EmailConnectionStatus status) {
    switch (status) {
      case EmailConnectionStatus.connected:
        return LightColor.safe;
      case EmailConnectionStatus.pending:
        return LightColor.yellow;
      case EmailConnectionStatus.error:
      case EmailConnectionStatus.disconnected:
        return LightColor.freeze;
      case EmailConnectionStatus.requiresReauth:
        return LightColor.warning;
    }
  }

  String _getStatusText(EmailConnectionStatus status) {
    switch (status) {
      case EmailConnectionStatus.connected:
        return 'Connected';
      case EmailConnectionStatus.pending:
        return 'Pending';
      case EmailConnectionStatus.error:
        return 'Error';
      case EmailConnectionStatus.disconnected:
        return 'Disconnected';
      case EmailConnectionStatus.requiresReauth:
        return 'Re-auth required';
    }
  }

  String _formatLastScan(DateTime lastScan) {
    final now = DateTime.now();
    final diff = now.difference(lastScan);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColor.background,
      appBar: AppBar(
        backgroundColor: LightColor.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: LightColor.titleTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Email Scanning',
          style: GoogleFonts.mulish(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: LightColor.titleTextColor,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocConsumer<EmailScanningBloc, EmailScanningState>(
        listener: (context, state) {
          if (state is EmailOAuthReady) {
            _openOAuthFlow(state.oauthUrl);
          } else if (state is EmailConnectionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Email connected successfully!',
                  style: GoogleFonts.mulish(),
                ),
                backgroundColor: LightColor.safe,
              ),
            );
          } else if (state is EmailScanComplete) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Found ${state.subscriptionsDetected} possible subscriptions in ${state.emailsScanned} emails',
                  style: GoogleFonts.mulish(),
                ),
                backgroundColor: LightColor.accent,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is EmailScanningLoading) {
            return _buildLoadingState();
          }

          if (state is EmailScanningProRequired) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildProRequiredCard(),
                ],
              ),
            );
          }

          if (state is EmailScanningError) {
            return _buildErrorState(state.message);
          }

          if (state is EmailScanningLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context
                    .read<EmailScanningBloc>()
                    .add(const EmailLoadRequested());
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    if (state.hasConnections) ...[
                      _buildConnectedEmails(state),
                      const SizedBox(height: 24),
                      _buildScannedEmails(state),
                      const SizedBox(height: 24),
                      Text(
                        'Add Another Email',
                        style: GoogleFonts.mulish(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: LightColor.titleTextColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildProviderSelection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          }

          if (state is EmailScanningOperationInProgress) {
            return Stack(
              children: [
                if (state.previousState != null)
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildConnectedEmails(state.previousState!),
                        const SizedBox(height: 24),
                        _buildProviderSelection(),
                      ],
                    ),
                  ),
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                              color: LightColor.accent),
                          const SizedBox(height: 16),
                          Text(
                            state.message,
                            style: GoogleFonts.mulish(
                              fontSize: 14,
                              color: LightColor.subTitleTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return _buildLoadingState();
        },
      ),
    );
  }
}
