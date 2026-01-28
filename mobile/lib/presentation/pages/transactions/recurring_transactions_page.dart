import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../data/models/bank_connection_model.dart';
import '../../../presentation/blocs/banking/banking_bloc.dart';
import '../../../presentation/blocs/banking/banking_event.dart';
import '../../../presentation/blocs/banking/banking_state.dart';

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
  static const Color divider = Color(0xFFE0E0E0);
}

class RecurringTransactionsPage extends StatefulWidget {
  final String connectionId;
  final String bankName;

  const RecurringTransactionsPage({
    super.key,
    required this.connectionId,
    required this.bankName,
  });

  @override
  State<RecurringTransactionsPage> createState() => _RecurringTransactionsPageState();
}

class _RecurringTransactionsPageState extends State<RecurringTransactionsPage> {
  @override
  void initState() {
    super.initState();
    context.read<BankingBloc>().add(BankingRecurringLoadRequested(connectionId: widget.connectionId));
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
          'Detected Payments',
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
          if (state is BankingConversionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Created: ${state.subscriptionName}'), backgroundColor: AppColors.safe),
            );
          }
        },
        builder: (context, state) {
          if (state is BankingOperationInProgress) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (state is BankingRecurringLoaded) {
            return _buildMainContent(state);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildMainContent(BankingRecurringLoaded state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          
          // Header Info
          _buildInfoHero(),
          
          const SizedBox(height: 32),

          Text('New Detections (${state.count})', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          
          if (state.recurringTransactions.isEmpty)
            _buildEmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.recurringTransactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _RecurringCard(transaction: state.recurringTransactions[index], connectionId: widget.connectionId);
              },
            ),
          
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
            child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            'Smart Detection Active',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'We found recurring patterns in ${widget.bankName}. Convert them to subscriptions to enable protection alerts.',
            style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            const Icon(Icons.search_off, size: 64, color: AppColors.surface),
            const SizedBox(height: 16),
            Text('No new patterns', style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _RecurringCard extends StatelessWidget {
  final RecurringTransactionModel transaction;
  final String connectionId;

  const _RecurringCard({required this.transaction, required this.connectionId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                child: const Icon(Icons.repeat, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(transaction.displayName, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(transaction.frequencyDisplay, style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                '\$${transaction.averageAmount.toStringAsFixed(2)}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                context.read<BankingBloc>().add(BankingConvertRecurringRequested(
                  connectionId: connectionId,
                  streamId: transaction.streamId,
                  name: transaction.displayName,
                  amount: transaction.averageAmount,
                  billingCycle: 'monthly',
                  color: '#CEA734',
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Add Subscription', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
