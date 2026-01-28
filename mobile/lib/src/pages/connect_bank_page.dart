import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plaid_flutter/plaid_flutter.dart';

import '../../core/utils/currency_formatter.dart';
import '../../data/models/bank_connection_model.dart';
import '../../presentation/blocs/banking/banking_bloc.dart';
import '../../presentation/blocs/banking/banking_event.dart';
import '../../presentation/blocs/banking/banking_state.dart';
import '../theme/light_color.dart';

/// Page for connecting and managing bank accounts (Pro feature)
class ConnectBankPage extends StatefulWidget {
  const ConnectBankPage({Key? key}) : super(key: key);

  @override
  State<ConnectBankPage> createState() => _ConnectBankPageState();
}

class _ConnectBankPageState extends State<ConnectBankPage> {
  /// Current provider being connected (used for token exchange)
  BankingProvider _currentProvider = BankingProvider.plaid;

  @override
  void initState() {
    super.initState();
    context.read<BankingBloc>().add(const BankingLoadRequested());
    _initPlaidLink();
  }

  /// Initialize Plaid Link event listeners
  void _initPlaidLink() {
    PlaidLink.onSuccess.listen(_onPlaidSuccess);
    PlaidLink.onExit.listen(_onPlaidExit);
    PlaidLink.onEvent.listen(_onPlaidEvent);
  }

  /// Handle successful Plaid Link connection
  void _onPlaidSuccess(LinkSuccess success) {
    // Extract public token and exchange it
    final publicToken = success.publicToken;

    if (publicToken.isNotEmpty) {
      context.read<BankingBloc>().add(BankingExchangeTokenRequested(
            publicToken: publicToken,
            provider: _currentProvider,
          ));
    }
  }

  /// Handle Plaid Link exit (user closed or error)
  void _onPlaidExit(LinkExit exit) {
    if (exit.error != null) {
      final error = exit.error!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connection failed: ${error.displayMessage ?? error.message}',
            style: GoogleFonts.mulish(),
          ),
          backgroundColor: LightColor.freeze,
        ),
      );
    }
    // Reload state if user exited without completing
    context.read<BankingBloc>().add(const BankingLoadRequested());
  }

  /// Handle Plaid Link events (for analytics/logging)
  void _onPlaidEvent(LinkEvent event) {
    // Can be used for analytics tracking
    debugPrint('Plaid Link Event: ${event.name}');
  }

  @override
  void dispose() {
    // Clean up Plaid Link if needed
    super.dispose();
  }

  void _connectBank(BankingProvider provider) {
    // Track current provider for token exchange
    setState(() {
      _currentProvider = provider;
    });

    context.read<BankingBloc>().add(BankingCreateLinkTokenRequested(
          provider: provider,
        ));
  }

  void _syncTransactions(String connectionId) {
    context.read<BankingBloc>().add(BankingSyncTransactionsRequested(
          connectionId: connectionId,
        ));
  }

  void _disconnectBank(String connectionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Disconnect Bank?',
          style: GoogleFonts.mulish(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will remove the bank connection and stop syncing transactions. You can reconnect anytime.',
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
              context.read<BankingBloc>().add(BankingDisconnectRequested(
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

  void _openPlaidLink(LinkTokenResponse linkToken) {
    // Configure and open Plaid Link with the token
    final configuration = LinkTokenConfiguration(
      token: linkToken.linkToken,
    );

    PlaidLink.open(configuration: configuration);
  }

  /// Show fallback for non-Plaid providers (Mono/Stitch use WebView)
  void _openWebViewLink(LinkTokenResponse linkToken, String providerName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Connect via $providerName',
          style: GoogleFonts.mulish(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_rounded,
              size: 48,
              color: LightColor.accent,
            ),
            const SizedBox(height: 16),
            Text(
              '$providerName integration uses web authentication.\n\nYou will be redirected to securely connect your bank.',
              style: GoogleFonts.mulish(),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: GoogleFonts.mulish(color: LightColor.subTitleTextColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // Open external WebView for Mono/Stitch
              // Note: These providers use web-based flows
              _launchProviderWebAuth(linkToken);
            },
            child: Text(
              'Continue',
              style: GoogleFonts.mulish(
                color: LightColor.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Launch provider web authentication (for Mono/Stitch)
  Future<void> _launchProviderWebAuth(LinkTokenResponse linkToken) async {
    // Mono and Stitch use web-based OAuth flows
    // The link_token from backend contains the redirect URL
    // For now, we'll use url_launcher to open the auth page
    // In production, use a WebView or app_links for deep linking
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Opening ${linkToken.provider} authentication...',
          style: GoogleFonts.mulish(),
        ),
        backgroundColor: LightColor.accent,
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
                  Icons.account_balance_rounded,
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
                      'Bank Connection',
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
            'Connect your bank to automatically detect subscriptions and track your safe-to-spend amount.',
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
          'Select Your Region',
          style: GoogleFonts.mulish(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: LightColor.titleTextColor,
          ),
        ),
        const SizedBox(height: 16),
        _buildProviderCard(
          provider: BankingProvider.plaid,
          title: 'United States & Canada',
          subtitle: 'Powered by Plaid',
          icon: Icons.flag_rounded,
          flagEmoji: '🇺🇸',
        ),
        const SizedBox(height: 12),
        _buildProviderCard(
          provider: BankingProvider.mono,
          title: 'Nigeria, Ghana & Kenya',
          subtitle: 'Powered by Mono',
          icon: Icons.public_rounded,
          flagEmoji: '🌍',
        ),
        const SizedBox(height: 12),
        _buildProviderCard(
          provider: BankingProvider.stitch,
          title: 'South Africa',
          subtitle: 'Powered by Stitch',
          icon: Icons.south_rounded,
          flagEmoji: '🇿🇦',
        ),
        const SizedBox(height: 12),
        _buildProviderCard(
          provider: BankingProvider.truelayer,
          title: 'United Kingdom & Ireland',
          subtitle: 'Powered by TrueLayer',
          icon: Icons.account_balance_rounded,
          flagEmoji: '🇬🇧',
        ),
        const SizedBox(height: 12),
        _buildProviderCard(
          provider: BankingProvider.tink,
          title: 'Europe',
          subtitle: 'Powered by Tink (Visa)',
          icon: Icons.euro_rounded,
          flagEmoji: '🇪🇺',
        ),
      ],
    );
  }

  Widget _buildProviderCard({
    required BankingProvider provider,
    required String title,
    required String subtitle,
    required IconData icon,
    required String flagEmoji,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _connectBank(provider),
        borderRadius: BorderRadius.circular(16),
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
                  color: LightColor.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    flagEmoji,
                    style: const TextStyle(fontSize: 24),
                  ),
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
                        color: LightColor.subTitleTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: LightColor.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectedBanks(BankingLoaded state) {
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
              'Connected Banks',
              style: GoogleFonts.mulish(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: LightColor.titleTextColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: LightColor.safe.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${state.accountCount} accounts',
                style: GoogleFonts.mulish(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: LightColor.safe,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Total Balance: ${CurrencyFormatter.format(state.totalBalance)}',
          style: GoogleFonts.mulish(
            fontSize: 13,
            color: LightColor.subTitleTextColor,
          ),
        ),
        const SizedBox(height: 16),
        ...state.connections.map((conn) => _buildConnectionCard(conn)),
      ],
    );
  }

  Widget _buildConnectionCard(BankConnectionModel connection) {
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
                  color: LightColor.navyBlue1.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: connection.institutionLogo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          connection.institutionLogo!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.account_balance_rounded,
                            color: LightColor.navyBlue1,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.account_balance_rounded,
                        color: LightColor.navyBlue1,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.institutionName,
                      style: GoogleFonts.mulish(
                        fontSize: 16,
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
                  if (value == 'sync') {
                    _syncTransactions(connection.id);
                  } else if (value == 'recurring') {
                    Navigator.pushNamed(
                      context,
                      '/recurring-transactions',
                      arguments: {
                        'connectionId': connection.id,
                        'bankName': connection.institutionName,
                      },
                    );
                  } else if (value == 'disconnect') {
                    _disconnectBank(connection.id);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'recurring',
                    child: Row(
                      children: [
                        const Icon(Icons.repeat_rounded,
                            size: 18, color: LightColor.accent),
                        const SizedBox(width: 12),
                        Text('View Recurring',
                            style: GoogleFonts.mulish(fontSize: 14)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'sync',
                    child: Row(
                      children: [
                        const Icon(Icons.sync_rounded,
                            size: 18, color: LightColor.accent),
                        const SizedBox(width: 12),
                        Text('Sync Now',
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
          if (connection.accounts.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...connection.accounts.map((account) => _buildAccountRow(account)),
          ],
          if (connection.lastSyncAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Last synced: ${_formatLastSync(connection.lastSyncAt!)}',
              style: GoogleFonts.mulish(
                fontSize: 11,
                color: LightColor.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountRow(BankAccountModel account) {
    final balance = account.availableBalance ?? account.currentBalance ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: LightColor.lightGrey,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getAccountIcon(account.accountType),
              color: LightColor.navyBlue1,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: GoogleFonts.mulish(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: LightColor.titleTextColor,
                  ),
                ),
                if (account.mask != null)
                  Text(
                    '••••${account.mask}',
                    style: GoogleFonts.mulish(
                      fontSize: 11,
                      color: LightColor.grey,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.format(balance),
            style: GoogleFonts.mulish(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: balance >= 0 ? LightColor.safe : LightColor.freeze,
            ),
          ),
        ],
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
            'Bank connection requires a Pro subscription. Unlock automatic subscription detection and real-time balance tracking.',
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

  Widget _buildErrorState(String message, BankingLoaded? previousState) {
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
                context.read<BankingBloc>().add(const BankingClearError());
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

  Color _getStatusColor(BankConnectionStatus status) {
    switch (status) {
      case BankConnectionStatus.connected:
        return LightColor.safe;
      case BankConnectionStatus.pending:
        return LightColor.yellow;
      case BankConnectionStatus.error:
      case BankConnectionStatus.disconnected:
        return LightColor.freeze;
      case BankConnectionStatus.requiresReauth:
        return LightColor.warning;
    }
  }

  String _getStatusText(BankConnectionStatus status) {
    switch (status) {
      case BankConnectionStatus.connected:
        return 'Connected';
      case BankConnectionStatus.pending:
        return 'Pending';
      case BankConnectionStatus.error:
        return 'Error';
      case BankConnectionStatus.disconnected:
        return 'Disconnected';
      case BankConnectionStatus.requiresReauth:
        return 'Re-auth required';
    }
  }

  IconData _getAccountIcon(BankAccountType type) {
    switch (type) {
      case BankAccountType.checking:
        return Icons.account_balance_wallet_rounded;
      case BankAccountType.savings:
        return Icons.savings_rounded;
      case BankAccountType.credit:
        return Icons.credit_card_rounded;
      case BankAccountType.loan:
        return Icons.money_off_rounded;
      case BankAccountType.investment:
        return Icons.trending_up_rounded;
      case BankAccountType.other:
        return Icons.account_balance_rounded;
    }
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final diff = now.difference(lastSync);

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
          'Connect Bank',
          style: GoogleFonts.mulish(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: LightColor.titleTextColor,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocConsumer<BankingBloc, BankingState>(
        listener: (context, state) {
          if (state is BankingLinkTokenReady) {
            // Route to appropriate link handler based on provider
            final provider = state.linkToken.provider.toLowerCase();
            if (provider == 'plaid') {
              _openPlaidLink(state.linkToken);
            } else if (provider == 'mono') {
              _openWebViewLink(state.linkToken, 'Mono');
            } else if (provider == 'stitch') {
              _openWebViewLink(state.linkToken, 'Stitch');
            } else {
              _openPlaidLink(state.linkToken);
            }
          } else if (state is BankingConnectionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Bank connected successfully!',
                  style: GoogleFonts.mulish(),
                ),
                backgroundColor: LightColor.safe,
              ),
            );
          } else if (state is BankingSyncComplete) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Synced ${state.newTransactions} new transactions',
                  style: GoogleFonts.mulish(),
                ),
                backgroundColor: LightColor.accent,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is BankingLoading) {
            return _buildLoadingState();
          }

          if (state is BankingProRequired) {
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

          if (state is BankingError) {
            return _buildErrorState(state.message, state.previousState);
          }

          if (state is BankingLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<BankingBloc>().add(const BankingLoadRequested());
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
                      _buildConnectedBanks(state),
                      const SizedBox(height: 24),
                      Text(
                        'Add Another Bank',
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

          if (state is BankingOperationInProgress) {
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
                        _buildConnectedBanks(state.previousState!),
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
