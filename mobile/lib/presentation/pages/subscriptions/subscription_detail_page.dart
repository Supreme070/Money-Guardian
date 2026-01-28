import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../data/models/subscription_model.dart';
import '../../../presentation/blocs/subscriptions/subscription_bloc.dart';
import '../../../presentation/blocs/subscriptions/subscription_event.dart';
import '../../../presentation/blocs/subscriptions/subscription_state.dart';

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
}

class SubscriptionDetailPage extends StatefulWidget {
  final SubscriptionModel subscription;

  const SubscriptionDetailPage({
    super.key,
    required this.subscription,
  });

  @override
  State<SubscriptionDetailPage> createState() => _SubscriptionDetailPageState();
}

class _SubscriptionDetailPageState extends State<SubscriptionDetailPage> {
  late SubscriptionModel _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.subscription;
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
          'Detail',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: BlocListener<SubscriptionBloc, SubscriptionState>(
        listener: (context, state) {
          if (state is SubscriptionLoaded) {
            final updated = state.subscriptions.where((s) => s.id == _sub.id).firstOrNull;
            if (updated != null) {
              setState(() => _sub = updated);
            } else {
              Navigator.pop(context);
            }
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              
              // Hero Card
              _buildHeroCard(),
              
              const SizedBox(height: 32),

              _buildSectionHeader('Billing Details'),
              const SizedBox(height: 16),
              _buildDetailGrid(),

              const SizedBox(height: 32),

              _buildSectionHeader('Protection Status'),
              const SizedBox(height: 16),
              _buildProtectionCard(),

              const SizedBox(height: 40),

              // Danger Zone
              Center(
                child: TextButton(
                  onPressed: () {
                    context.read<SubscriptionBloc>().add(SubscriptionDeleteRequested(subscriptionId: _sub.id));
                  },
                  child: Text('Delete Subscription', style: GoogleFonts.inter(color: AppColors.freeze, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                _sub.name.substring(0, 1).toUpperCase(),
                style: GoogleFonts.inter(color: AppColors.primary, fontSize: 28, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _sub.name,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${_sub.amount.toStringAsFixed(2)} / ${_sub.billingCycle.name}',
            style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildDetailGrid() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildDetailRow('Next Charge', DateFormat('MMM d, yyyy').format(_sub.nextBillingDate)),
          const Divider(height: 32),
          _buildDetailRow('Frequency', _sub.billingCycle.name.toUpperCase()),
          const Divider(height: 32),
          _buildDetailRow('Source', _sub.source.name.toUpperCase()),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14)),
        Text(value, style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }

  Widget _buildProtectionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.safe.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(24),
        color: AppColors.safe.withOpacity(0.05),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.safe),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Guarded', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.safe)),
                const SizedBox(height: 2),
                Text('We will alert you 3 days before this charge.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
