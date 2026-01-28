import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/currency_formatter.dart';
import '../../core/utils/model_mappers.dart';
import '../../data/models/subscription_model.dart';
import '../../presentation/blocs/subscriptions/subscription_bloc.dart';
import '../../presentation/blocs/subscriptions/subscription_event.dart';
import '../../presentation/blocs/subscriptions/subscription_state.dart';
import '../theme/light_color.dart';
import '../widgets/subscription_card.dart';
import '../widgets/bottom_navigation_bar.dart';
import 'subscription_detail_page.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({Key? key}) : super(key: key);

  @override
  _SubscriptionsPageState createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  int _currentNavIndex = 1;
  String _selectedFilter = 'all';
  String _selectedSort = 'name';

  @override
  void initState() {
    super.initState();
    context.read<SubscriptionBloc>().add(const SubscriptionLoadRequested());
  }

  void _onNavTap(int index) {
    if (index == _currentNavIndex) return;
    setState(() {
      _currentNavIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/calendar');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/alerts');
        break;
    }
  }

  List<SubscriptionModel> _filterAndSort(List<SubscriptionModel> subscriptions) {
    var filtered = List<SubscriptionModel>.from(subscriptions);

    // Apply filter
    if (_selectedFilter == 'flagged') {
      filtered = filtered.where((s) => s.aiFlag != AIFlag.none).toList();
    } else if (_selectedFilter == 'active') {
      filtered = filtered.where((s) => s.isActive && !s.isPaused).toList();
    } else if (_selectedFilter == 'paused') {
      filtered = filtered.where((s) => s.isPaused || !s.isActive).toList();
    }

    // Apply sort
    if (_selectedSort == 'name') {
      filtered.sort((a, b) => a.name.compareTo(b.name));
    } else if (_selectedSort == 'amount') {
      filtered.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (_selectedSort == 'date') {
      filtered.sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
    }

    return filtered;
  }

  Widget _buildHeader(SubscriptionLoaded state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LightColor.navyBlue1,
            LightColor.navyBlue2,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Spend',
                    style: GoogleFonts.mulish(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(state.monthlyTotal),
                    style: GoogleFonts.mulish(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '${state.totalCount}',
                      style: GoogleFonts.mulish(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Active',
                      style: GoogleFonts.mulish(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (state.flaggedCount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: LightColor.caution.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_rounded,
                    color: LightColor.yellow,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI found ${state.flaggedCount} subscriptions you might want to review',
                      style: GoogleFonts.mulish(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterSort() {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                _buildFilterChip('Flagged', 'flagged'),
                _buildFilterChip('Active', 'active'),
                _buildFilterChip('Paused', 'paused'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          onSelected: (value) {
            setState(() {
              _selectedSort = value;
            });
          },
          itemBuilder: (context) => [
            _buildSortMenuItem('Name', 'name'),
            _buildSortMenuItem('Amount', 'amount'),
            _buildSortMenuItem('Next billing', 'date'),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: LightColor.lightGrey,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sort_rounded,
                  size: 18,
                  color: LightColor.darkgrey,
                ),
                const SizedBox(width: 4),
                Text(
                  'Sort',
                  style: GoogleFonts.mulish(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: LightColor.darkgrey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? LightColor.accent : LightColor.lightGrey,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.mulish(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : LightColor.darkgrey,
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(String label, String value) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          if (_selectedSort == value)
            const Icon(Icons.check, size: 18, color: LightColor.accent)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.mulish(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsList(List<SubscriptionModel> subscriptions) {
    final filtered = _filterAndSort(subscriptions);

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: LightColor.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'No subscriptions found',
                style: GoogleFonts.mulish(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: LightColor.subTitleTextColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: filtered.map((sub) {
        final colorValue = parseColorFromHex(sub.color);

        return SubscriptionCard(
          name: sub.name,
          amount: sub.amount,
          billingCycle: mapBillingCycleToString(sub.billingCycle),
          nextBillingDate: sub.nextBillingDate,
          flag: mapAIFlagToWidget(sub.aiFlag),
          iconColor: colorValue != null ? Color(colorValue) : null,
          logoUrl: sub.logoUrl,
          isActive: sub.isActive && !sub.isPaused,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => SubscriptionDetailPage(subscription: sub),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: LightColor.accent,
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
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
          TextButton(
            onPressed: () {
              context.read<SubscriptionBloc>().add(const SubscriptionLoadRequested());
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColor.background,
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add-subscription');
        },
        backgroundColor: LightColor.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: BlocBuilder<SubscriptionBloc, SubscriptionState>(
          builder: (context, state) {
            if (state is SubscriptionLoading) {
              return _buildLoadingState();
            }

            if (state is SubscriptionError) {
              return _buildErrorState(state.message);
            }

            if (state is SubscriptionLoaded) {
              return RefreshIndicator(
                onRefresh: () async {
                  context.read<SubscriptionBloc>().add(const SubscriptionLoadRequested());
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        // Page title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Subscriptions',
                              style: GoogleFonts.mulish(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: LightColor.titleTextColor,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                // Search
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: LightColor.lightGrey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.search_rounded,
                                  color: LightColor.darkgrey,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Header with monthly spend
                        _buildHeader(state),
                        const SizedBox(height: 24),

                        // Filter and sort
                        _buildFilterSort(),
                        const SizedBox(height: 20),

                        // Subscriptions list
                        _buildSubscriptionsList(state.subscriptions),
                        const SizedBox(height: 80), // Space for FAB
                      ],
                    ),
                  ),
                ),
              );
            }

            if (state is SubscriptionOperationInProgress) {
              return Stack(
                children: [
                  // Show previous state content
                  RefreshIndicator(
                    onRefresh: () async {},
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Subscriptions',
                                  style: GoogleFonts.mulish(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: LightColor.titleTextColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildHeader(state.previousState),
                            const SizedBox(height: 24),
                            _buildFilterSort(),
                            const SizedBox(height: 20),
                            _buildSubscriptionsList(state.previousState.subscriptions),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Loading overlay
                  Container(
                    color: Colors.black.withOpacity(0.1),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: LightColor.accent,
                      ),
                    ),
                  ),
                ],
              );
            }

            return _buildLoadingState();
          },
        ),
      ),
    );
  }
}
