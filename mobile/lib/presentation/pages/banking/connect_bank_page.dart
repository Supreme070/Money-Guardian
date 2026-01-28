import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plaid_flutter/plaid_flutter.dart';

import '../../../data/models/bank_connection_model.dart';
import '../../../presentation/blocs/banking/banking_bloc.dart';
import '../../../presentation/blocs/banking/banking_event.dart';
import '../../../presentation/blocs/banking/banking_state.dart';
import '../transactions/recurring_transactions_page.dart';

// --- Color System (Consistent) ---
class AppColors {
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F7);
  static const Color primary = Color(0xFFCEA734); 
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);
  static const Color safe = Color(0xFF00E676);
  static const Color freeze = Color(0xFFCF6679);
  static const Color caution = Color(0xFFFFB74D);
  static const Color divider = Color(0xFFE0E0E0);
}

class ConnectBankPage extends StatefulWidget {
  const ConnectBankPage({super.key});

  @override
  State<ConnectBankPage> createState() => _ConnectBankPageState();
}

class _ConnectBankPageState extends State<ConnectBankPage> {
  BankingProvider _currentProvider = BankingProvider.plaid;

  @override
  void initState() {
    super.initState();
    context.read<BankingBloc>().add(const BankingLoadRequested());
    _initPlaidLink();
  }

  void _initPlaidLink() {
    PlaidLink.onSuccess.listen(_onPlaidSuccess);
    PlaidLink.onExit.listen(_onPlaidExit);
  }

  void _onPlaidSuccess(LinkSuccess success) {
    if (success.publicToken.isNotEmpty) {
      context.read<BankingBloc>().add(BankingExchangeTokenRequested(
            publicToken: success.publicToken,
            provider: _currentProvider,
          ));
    }
  }

  void _onPlaidExit(LinkExit exit) {
    if (exit.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection failed: ${exit.error!.displayMessage ?? exit.error!.message}'),
          backgroundColor: AppColors.freeze,
        ),
      );
    }
    context.read<BankingBloc>().add(const BankingLoadRequested());
  }

  void _connectBank(BankingProvider provider) {
    setState(() => _currentProvider = provider);
    context.read<BankingBloc>().add(BankingCreateLinkTokenRequested(provider: provider));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Bank Link',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: BlocConsumer<BankingBloc, BankingState>(
        listener: (context, state) {
          if (state is BankingLinkTokenReady) {
            final configuration = LinkTokenConfiguration(token: state.linkToken.linkToken);
            PlaidLink.create(configuration: configuration);
            PlaidLink.open();
          } else if (state is BankingConnectionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bank connected successfully!'), backgroundColor: AppColors.safe),
            );
          }
        },
        builder: (context, state) {
          if (state is BankingLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (state is BankingProRequired) {
            return _buildProRequiredView();
          }

          if (state is BankingLoaded) {
            return _buildMainContent(state);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildMainContent(BankingLoaded state) {
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
            Text('Connected Institutions', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ...state.connections.map((conn) => _buildConnectionCard(conn)),
            const SizedBox(height: 32),
          ],

          Text('Link New Account', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
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
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.account_balance, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            'The Foundation of Protection',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your bank to automatically detect subscriptions and track your real-time safe-to-spend balance.',
            style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(BankConnectionModel connection) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surface),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.account_balance_wallet, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(connection.institutionName, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Active Connection', style: GoogleFonts.inter(color: AppColors.safe, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'recurring') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RecurringTransactionsPage(
                          connectionId: connection.id,
                          bankName: connection.institutionName,
                        ),
                      ),
                    );
                  } else if (value == 'disconnect') {
                    // Disconnect logic
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'recurring',
                    child: Row(
                      children: [
                        const Icon(Icons.repeat, size: 20, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Text('Recurring Patterns', style: GoogleFonts.inter(fontSize: 14)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'disconnect',
                    child: Row(
                      children: [
                        const Icon(Icons.link_off, size: 20, color: AppColors.freeze),
                        const SizedBox(width: 12),
                        Text('Disconnect', style: GoogleFonts.inter(fontSize: 14, color: AppColors.freeze)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.more_horiz, color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
          if (connection.accounts.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: AppColors.surface),
            ),
            ...connection.accounts.map((acc) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(acc.name, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
                  Text(
                    '\$${(acc.availableBalance ?? acc.currentBalance ?? 0.0).toStringAsFixed(2)}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildProviderSelection() {
    return Column(
      children: [
        _buildProviderTile('United States & Canada', 'Powered by Plaid', '🇺🇸', BankingProvider.plaid),
        const SizedBox(height: 12),
        _buildProviderTile('Europe & UK', 'Powered by TrueLayer', '🇪🇺', BankingProvider.plaid), // Mocking other providers
        const SizedBox(height: 12),
        _buildProviderTile('Nigeria & Ghana', 'Powered by Mono', '🇳🇬', BankingProvider.plaid),
      ],
    );
  }

  Widget _buildProviderTile(String title, String subtitle, String emoji, BankingProvider provider) {
    return InkWell(
      onTap: () => _connectBank(provider),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.add_link, color: AppColors.primary),
          ],
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
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.lock_outline, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 32),
          Text(
            'Pro Feature Only',
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -1),
          ),
          const SizedBox(height: 12),
          Text(
            'Bank synchronization is available for Pro members. Unlock full automation and real-time monitoring.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/pro-upgrade'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Upgrade to Pro', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
