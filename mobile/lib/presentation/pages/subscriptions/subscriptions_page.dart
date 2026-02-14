import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../data/models/subscription_model.dart';
import '../../../presentation/blocs/subscriptions/subscription_bloc.dart';
import '../../../presentation/blocs/subscriptions/subscription_event.dart';
import '../../../presentation/blocs/subscriptions/subscription_state.dart';
import 'subscription_detail_page.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/analytics_service.dart';
import '../../../src/theme/light_color.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsService>().logScreenView(screenName: 'Subscriptions');
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    context.read<SubscriptionBloc>().add(const SubscriptionLoadRequested());
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && !_tabController.indexIsChanging) {
      context.read<SubscriptionBloc>().add(const SubscriptionHistoryLoadRequested());
    }
  }

  Widget _buildSkeletonSubscriptionList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skeleton monthly spend card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: LightColor.textPrimary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Monthly Commitment', style: GoogleFonts.mulish(color: Colors.white.withOpacity(0.7), fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('\$99.99', style: GoogleFonts.mulish(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.analytics_outlined, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text('Your Subscriptions (5)', style: GoogleFonts.mulish(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ...List.generate(5, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: LightColor.surface),
              ),
              child: Row(
                children: [
                  Container(
                    height: 50, width: 50,
                    decoration: BoxDecoration(color: LightColor.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.receipt_long, color: LightColor.primary, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Subscription Name', style: GoogleFonts.mulish(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('MONTHLY', style: GoogleFonts.mulish(color: LightColor.textTertiary, fontSize: 11)),
                      ],
                    ),
                  ),
                  Text('\$14.99', style: GoogleFonts.mulish(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          )),
        ],
      ),
    );
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
          'Subscriptions',
          style: GoogleFonts.mulish(
            color: LightColor.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: LightColor.primary,
          unselectedLabelColor: LightColor.textSecondary,
          indicatorColor: LightColor.primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.mulish(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: BlocBuilder<SubscriptionBloc, SubscriptionState>(
        builder: (context, state) {
          if (state is SubscriptionLoading) {
            return Skeletonizer(
              enabled: true,
              child: _buildSkeletonSubscriptionList(),
            );
          }

          if (state is SubscriptionLoaded) {
            return TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    context.read<SubscriptionBloc>().add(const SubscriptionLoadRequested());
                  },
                  color: LightColor.primary,
                  child: ActiveSubscriptionsTab(subscriptions: state.subscriptions),
                ),
                RefreshIndicator(
                  onRefresh: () async {
                    context.read<SubscriptionBloc>().add(const SubscriptionHistoryLoadRequested());
                  },
                  color: LightColor.primary,
                  child: _HistorySubscriptionsTab(subscriptions: state.historySubscriptions),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/add-subscription'),
        backgroundColor: LightColor.textPrimary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add New',
          style: GoogleFonts.mulish(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }
}

class ActiveSubscriptionsTab extends StatelessWidget {
  final List<SubscriptionModel> subscriptions;

  const ActiveSubscriptionsTab({super.key, required this.subscriptions});

  @override
  Widget build(BuildContext context) {
    final activeSubs = subscriptions.where((s) => s.isActive && !s.isPaused).toList();
    
    final totalMonthly = activeSubs
        .where((s) => s.billingCycle == BillingCycle.monthly)
        .fold(0.0, (sum, item) => sum + item.amount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Monthly Spend Summary Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: LightColor.textPrimary,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Commitment',
                      style: GoogleFonts.mulish(color: Colors.white.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${totalMonthly.toStringAsFixed(2)}',
                      style: GoogleFonts.mulish(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.analytics_outlined, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'Your Subscriptions (${activeSubs.length})',
            style: GoogleFonts.mulish(color: LightColor.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          if (activeSubs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text('No active subscriptions found', style: GoogleFonts.mulish(color: LightColor.textTertiary)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeSubs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = activeSubs[index];
                return _SubscriptionCard(item: item);
              },
            ),
        ],
      ),
    );
  }
}

class _HistorySubscriptionsTab extends StatelessWidget {
  final List<SubscriptionModel> subscriptions;

  const _HistorySubscriptionsTab({required this.subscriptions});

  @override
  Widget build(BuildContext context) {
    if (subscriptions.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 80),
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history, color: LightColor.textTertiary, size: 48),
              const SizedBox(height: 16),
              Text(
                'No subscription history',
                style: GoogleFonts.mulish(
                  color: LightColor.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cancelled subscriptions will appear here',
                style: GoogleFonts.mulish(
                  color: LightColor.textTertiary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: subscriptions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = subscriptions[index];
        return Opacity(
          opacity: 0.6,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: LightColor.surface),
            ),
            child: Row(
              children: [
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: LightColor.textTertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.receipt_long, color: LightColor.textTertiary, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.mulish(
                          color: LightColor.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cancelled ${DateFormat('MMM d, yyyy').format(item.updatedAt)}',
                        style: GoogleFonts.mulish(color: LightColor.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${item.amount.toStringAsFixed(2)}',
                  style: GoogleFonts.mulish(
                    color: LightColor.textTertiary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final SubscriptionModel item;

  const _SubscriptionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SubscriptionDetailPage(subscription: item)),
      ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: LightColor.surface),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: LightColor.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.receipt_long, color: LightColor.primary, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.mulish(color: LightColor.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        item.billingCycle.name.toUpperCase(),
                        style: GoogleFonts.mulish(color: LightColor.textTertiary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(color: LightColor.divider, shape: BoxShape.circle),
                      ),
                      Text(
                        'Next: ${DateFormat('MMM d').format(item.nextBillingDate)}',
                        style: GoogleFonts.mulish(color: LightColor.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '\$${item.amount.toStringAsFixed(2)}',
              style: GoogleFonts.mulish(color: LightColor.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}