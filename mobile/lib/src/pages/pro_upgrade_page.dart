import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/purchase_model.dart';
import '../../presentation/blocs/purchase/purchase_bloc.dart';
import '../../presentation/blocs/purchase/purchase_event.dart';
import '../../presentation/blocs/purchase/purchase_state.dart';
import '../../core/di/injection.dart';
import '../../core/services/analytics_service.dart';
import '../theme/light_color.dart';

/// Pro subscription upgrade page with pricing tiers
/// Integrates with RevenueCat for in-app purchases
class ProUpgradePage extends StatelessWidget {
  const ProUpgradePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.I<PurchaseBloc>()
        ..add(const PurchaseOfferingsRequested()),
      child: const _ProUpgradeView(),
    );
  }
}

class _ProUpgradeView extends StatefulWidget {
  const _ProUpgradeView();

  @override
  State<_ProUpgradeView> createState() => _ProUpgradeViewState();
}

class _ProUpgradeViewState extends State<_ProUpgradeView> {
  int _selectedPlanIndex = 1; // Default to yearly (best value)

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsService>().logScreenView(screenName: 'ProUpgrade');
    getIt<AnalyticsService>().logProUpgradeStarted(source: 'navigation');
  }

  // Fallback plans when RevenueCat offerings not available
  static const List<_PlanOption> _fallbackPlans = [
    _PlanOption(
      identifier: '\$rc_monthly',
      name: 'Monthly',
      price: 4.99,
      priceString: '\$4.99',
      period: 'month',
      savings: null,
      isPopular: false,
    ),
    _PlanOption(
      identifier: '\$rc_annual',
      name: 'Yearly',
      price: 29.99,
      priceString: '\$29.99',
      period: 'year',
      savings: 'Save 50%',
      isPopular: true,
    ),
    _PlanOption(
      identifier: '\$rc_lifetime',
      name: 'Lifetime',
      price: 79.99,
      priceString: '\$79.99',
      period: 'once',
      savings: 'Best Value',
      isPopular: false,
    ),
  ];

  static const List<_FeatureItem> _features = [
    _FeatureItem(
      icon: Icons.account_balance_rounded,
      title: 'Bank Connection',
      description: 'Auto-detect subscriptions from transactions',
      isFree: false,
    ),
    _FeatureItem(
      icon: Icons.email_rounded,
      title: 'Email Scanning',
      description: 'Find subscriptions in receipts & confirmations',
      isFree: false,
    ),
    _FeatureItem(
      icon: Icons.sync_rounded,
      title: 'Real-time Sync',
      description: 'Automatic balance & transaction updates',
      isFree: false,
    ),
    _FeatureItem(
      icon: Icons.lightbulb_rounded,
      title: 'AI Insights',
      description: 'Smart waste detection & recommendations',
      isFree: false,
    ),
    _FeatureItem(
      icon: Icons.calendar_month_rounded,
      title: 'Unlimited Subscriptions',
      description: 'Track as many as you need',
      isFree: false,
    ),
    _FeatureItem(
      icon: Icons.notifications_active_rounded,
      title: 'Priority Alerts',
      description: 'Get notified before charges happen',
      isFree: true,
    ),
    _FeatureItem(
      icon: Icons.dashboard_rounded,
      title: 'Daily Pulse',
      description: 'SAFE/CAUTION/FREEZE status',
      isFree: true,
    ),
    _FeatureItem(
      icon: Icons.support_agent_rounded,
      title: 'Priority Support',
      description: 'Fast response from our team',
      isFree: false,
    ),
  ];

  List<_PlanOption> _getPlansFromOfferings(OfferingsModel offerings) {
    if (offerings.availablePackages.isEmpty) {
      return _fallbackPlans;
    }

    final plans = <_PlanOption>[];

    for (final package in offerings.availablePackages) {
      String period;
      String? savings;
      bool isPopular = false;

      switch (package.packageType) {
        case 'monthly':
        case '\$rc_monthly':
          period = 'month';
          break;
        case 'annual':
        case '\$rc_annual':
          period = 'year';
          savings = 'Save 50%';
          isPopular = true;
          break;
        case 'lifetime':
        case '\$rc_lifetime':
          period = 'once';
          savings = 'Best Value';
          break;
        default:
          period = 'month';
      }

      plans.add(_PlanOption(
        identifier: package.identifier,
        name: _getPlanName(package.packageType ?? package.identifier),
        price: package.product.price,
        priceString: package.product.priceString,
        period: period,
        savings: savings,
        isPopular: isPopular,
        trialDays: package.product.trialDays,
      ));
    }

    // Sort: monthly, yearly, lifetime
    plans.sort((a, b) {
      const order = {'month': 0, 'year': 1, 'once': 2};
      return (order[a.period] ?? 3).compareTo(order[b.period] ?? 3);
    });

    return plans.isEmpty ? _fallbackPlans : plans;
  }

  String _getPlanName(String packageType) {
    switch (packageType) {
      case 'monthly':
      case '\$rc_monthly':
        return 'Monthly';
      case 'annual':
      case '\$rc_annual':
        return 'Yearly';
      case 'lifetime':
      case '\$rc_lifetime':
        return 'Lifetime';
      default:
        return 'Pro';
    }
  }

  void _subscribe(List<_PlanOption> plans) {
    if (_selectedPlanIndex >= plans.length) return;

    final selectedPlan = plans[_selectedPlanIndex];
    context.read<PurchaseBloc>().add(
          PurchasePackageRequested(packageId: selectedPlan.identifier),
        );
  }

  void _restorePurchases() {
    context.read<PurchaseBloc>().add(const PurchaseRestoreRequested());
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [LightColor.yellow, LightColor.yellow2],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: LightColor.yellow.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Upgrade to Pro',
          style: GoogleFonts.mulish(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: LightColor.titleTextColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Unlock the full power of Money Guardian',
          style: GoogleFonts.mulish(
            fontSize: 15,
            color: LightColor.subTitleTextColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildValueProposition() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LightColor.safe.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LightColor.safe.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: LightColor.safe.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.savings_rounded,
              color: LightColor.safe,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'One avoided overdraft = paid for the year',
                  style: GoogleFonts.mulish(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: LightColor.titleTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Average overdraft fee: \$35. Pro pays for itself.',
                  style: GoogleFonts.mulish(
                    fontSize: 12,
                    color: LightColor.subTitleTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelector(List<_PlanOption> plans) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Your Plan',
          style: GoogleFonts.mulish(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: LightColor.titleTextColor,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: List.generate(plans.length, (index) {
            final plan = plans[index];
            final isSelected = _selectedPlanIndex == index;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPlanIndex = index;
                  });
                },
                child: Container(
                  margin: EdgeInsets.only(
                    right: index < plans.length - 1 ? 12 : 0,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? LightColor.navyBlue1 : LightColor.lightGrey,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? LightColor.navyBlue1
                          : LightColor.grey.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (plan.isPopular)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: LightColor.yellow,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'POPULAR',
                            style: GoogleFonts.mulish(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: LightColor.navyBlue1,
                            ),
                          ),
                        )
                      else if (plan.savings != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.2)
                                : LightColor.safe.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            plan.savings!,
                            style: GoogleFonts.mulish(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : LightColor.safe,
                            ),
                          ),
                        )
                      else if (plan.trialDays != null && plan.trialDays! > 0)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.2)
                                : LightColor.accent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${plan.trialDays} DAY TRIAL',
                            style: GoogleFonts.mulish(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : LightColor.accent,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 19),
                      Text(
                        plan.name,
                        style: GoogleFonts.mulish(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white.withOpacity(0.8)
                              : LightColor.subTitleTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        plan.priceString,
                        style: GoogleFonts.mulish(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? Colors.white
                              : LightColor.titleTextColor,
                        ),
                      ),
                      Text(
                        plan.period == 'once' ? 'one time' : '/${plan.period}',
                        style: GoogleFonts.mulish(
                          fontSize: 11,
                          color: isSelected
                              ? Colors.white.withOpacity(0.7)
                              : LightColor.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFeaturesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What You Get',
          style: GoogleFonts.mulish(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: LightColor.titleTextColor,
          ),
        ),
        const SizedBox(height: 16),
        ..._features.map((feature) => _buildFeatureRow(feature)),
      ],
    );
  }

  Widget _buildFeatureRow(_FeatureItem feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: feature.isFree
                  ? LightColor.grey.withOpacity(0.2)
                  : LightColor.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              feature.icon,
              size: 20,
              color: feature.isFree ? LightColor.grey : LightColor.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      feature.title,
                      style: GoogleFonts.mulish(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: LightColor.titleTextColor,
                      ),
                    ),
                    if (feature.isFree) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: LightColor.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'FREE',
                          style: GoogleFonts.mulish(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: LightColor.darkgrey,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: LightColor.yellow.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PRO',
                          style: GoogleFonts.mulish(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: LightColor.yellow2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  feature.description,
                  style: GoogleFonts.mulish(
                    fontSize: 12,
                    color: LightColor.subTitleTextColor,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle_rounded,
            color: feature.isFree ? LightColor.grey : LightColor.safe,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribeButton(List<_PlanOption> plans, bool isLoading) {
    if (_selectedPlanIndex >= plans.length) return const SizedBox();

    final selectedPlan = plans[_selectedPlanIndex];

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : () => _subscribe(plans),
            style: ElevatedButton.styleFrom(
              backgroundColor: LightColor.yellow2,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
              disabledBackgroundColor: LightColor.yellow2.withOpacity(0.5),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    selectedPlan.trialDays != null && selectedPlan.trialDays! > 0
                        ? 'Start ${selectedPlan.trialDays}-Day Free Trial'
                        : 'Subscribe Now - ${selectedPlan.priceString}/${selectedPlan.period}',
                    style: GoogleFonts.mulish(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: isLoading ? null : _restorePurchases,
          child: Text(
            'Restore Purchases',
            style: GoogleFonts.mulish(
              fontSize: 14,
              color: LightColor.subTitleTextColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuarantee() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LightColor.lightGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_rounded,
            color: LightColor.safe,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '7-Day Money-Back Guarantee',
                  style: GoogleFonts.mulish(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: LightColor.titleTextColor,
                  ),
                ),
                Text(
                  'Try Pro risk-free. Full refund if not satisfied.',
                  style: GoogleFonts.mulish(
                    fontSize: 11,
                    color: LightColor.subTitleTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: LightColor.safe),
            const SizedBox(width: 12),
            Text(
              'Welcome to Pro!',
              style: GoogleFonts.mulish(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.mulish(),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close upgrade page
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: LightColor.safe,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Get Started',
              style: GoogleFonts.mulish(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.mulish()),
        backgroundColor: LightColor.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showRestoreResultSnackBar(String message, bool isPro) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.mulish()),
        backgroundColor: isPro ? LightColor.safe : LightColor.navyBlue1,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: isPro
            ? SnackBarAction(
                label: 'Done',
                textColor: Colors.white,
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PurchaseBloc, PurchaseState>(
      listener: (context, state) {
        if (state is PurchaseSuccess) {
          _showSuccessDialog(state.message);
        } else if (state is PurchaseRestoreSuccess) {
          _showRestoreResultSnackBar(state.message, state.isPro);
          if (state.isPro) {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) Navigator.pop(context);
            });
          }
        } else if (state is PurchaseError) {
          _showErrorSnackBar(state.message);
        }
      },
      builder: (context, state) {
        List<_PlanOption> plans = _fallbackPlans;
        bool isLoading = false;
        bool isPro = false;

        if (state is PurchaseLoaded) {
          plans = _getPlansFromOfferings(state.offerings);
          isPro = state.isPro;
        } else if (state is PurchaseInProgress) {
          plans = _getPlansFromOfferings(state.previousState.offerings);
          isLoading = true;
        } else if (state is PurchaseRestoreInProgress) {
          plans = _getPlansFromOfferings(state.previousState.offerings);
          isLoading = true;
        } else if (state is PurchaseLoading || state is PurchaseInitializing) {
          isLoading = true;
        }

        // If user already has Pro, show different UI
        if (isPro) {
          return Scaffold(
            backgroundColor: LightColor.background,
            appBar: AppBar(
              backgroundColor: LightColor.background,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: LightColor.titleTextColor),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: LightColor.safe.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: LightColor.safe,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'You\'re already Pro!',
                      style: GoogleFonts.mulish(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: LightColor.titleTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enjoy all premium features of Money Guardian.',
                      style: GoogleFonts.mulish(
                        fontSize: 15,
                        color: LightColor.subTitleTextColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LightColor.safe,
                        side: const BorderSide(color: LightColor.safe),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Continue',
                        style: GoogleFonts.mulish(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: LightColor.background,
          appBar: AppBar(
            backgroundColor: LightColor.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: LightColor.titleTextColor),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildValueProposition(),
                const SizedBox(height: 32),
                _buildPlanSelector(plans),
                const SizedBox(height: 32),
                _buildFeaturesList(),
                const SizedBox(height: 32),
                _buildSubscribeButton(plans, isLoading),
                const SizedBox(height: 20),
                _buildGuarantee(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlanOption {
  final String identifier;
  final String name;
  final double price;
  final String priceString;
  final String period;
  final String? savings;
  final bool isPopular;
  final int? trialDays;

  const _PlanOption({
    required this.identifier,
    required this.name,
    required this.price,
    required this.priceString,
    required this.period,
    this.savings,
    required this.isPopular,
    this.trialDays,
  });
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String description;
  final bool isFree;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.isFree,
  });
}
