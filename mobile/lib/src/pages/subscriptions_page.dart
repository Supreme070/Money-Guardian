import 'package:flutter/material.dart';
import 'package:money_guardian/src/theme/light_color.dart';
import 'package:money_guardian/src/widgets/subscription_card.dart';
import 'package:money_guardian/src/widgets/bottom_navigation_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:money_guardian/core/utils/currency_formatter.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({Key? key}) : super(key: key);

  @override
  _SubscriptionsPageState createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  int _currentNavIndex = 1;
  String _selectedFilter = 'all';
  String _selectedSort = 'name';

  // Mock data - will be replaced with actual state management
  final double _monthlyTotal = 87.94;
  final int _totalSubscriptions = 8;
  final int _flaggedCount = 2;

  final List<Map<String, dynamic>> _subscriptions = [
    {
      'name': 'Netflix',
      'amount': 15.99,
      'billingCycle': 'monthly',
      'nextBillingDate': DateTime.now().add(const Duration(days: 2)),
      'flag': SubscriptionFlag.none,
      'iconColor': const Color(0xffE50914),
      'isActive': true,
    },
    {
      'name': 'Spotify',
      'amount': 9.99,
      'billingCycle': 'monthly',
      'nextBillingDate': DateTime.now().add(const Duration(days: 4)),
      'flag': SubscriptionFlag.none,
      'iconColor': const Color(0xff1DB954),
      'isActive': true,
    },
    {
      'name': 'Adobe Creative Cloud',
      'amount': 54.99,
      'billingCycle': 'monthly',
      'nextBillingDate': DateTime.now().add(const Duration(days: 12)),
      'flag': SubscriptionFlag.unused,
      'iconColor': const Color(0xffFF0000),
      'isActive': true,
    },
    {
      'name': 'iCloud Storage',
      'amount': 2.99,
      'billingCycle': 'monthly',
      'nextBillingDate': DateTime.now().add(const Duration(days: 6)),
      'flag': SubscriptionFlag.none,
      'iconColor': const Color(0xff007AFF),
      'isActive': true,
    },
    {
      'name': 'Amazon Prime',
      'amount': 14.99,
      'billingCycle': 'monthly',
      'nextBillingDate': DateTime.now().add(const Duration(days: 18)),
      'flag': SubscriptionFlag.duplicate,
      'iconColor': const Color(0xffFF9900),
      'isActive': true,
    },
    {
      'name': 'Gym Membership',
      'amount': 29.99,
      'billingCycle': 'monthly',
      'nextBillingDate': DateTime.now().add(const Duration(days: 25)),
      'flag': SubscriptionFlag.forgotten,
      'iconColor': const Color(0xff6366F1),
      'isActive': false,
    },
  ];

  void _onNavTap(int index) {
    if (index == _currentNavIndex) return;
    setState(() {
      _currentNavIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/');
        break;
      case 1:
        // Already on subscriptions
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/calendar');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/alerts');
        break;
    }
  }

  List<Map<String, dynamic>> get _filteredSubscriptions {
    var filtered = _subscriptions;

    // Apply filter
    if (_selectedFilter == 'flagged') {
      filtered = filtered.where((s) => s['flag'] != SubscriptionFlag.none).toList();
    } else if (_selectedFilter == 'active') {
      filtered = filtered.where((s) => s['isActive'] == true).toList();
    } else if (_selectedFilter == 'paused') {
      filtered = filtered.where((s) => s['isActive'] == false).toList();
    }

    // Apply sort
    if (_selectedSort == 'name') {
      filtered.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    } else if (_selectedSort == 'amount') {
      filtered.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
    } else if (_selectedSort == 'date') {
      filtered.sort((a, b) => (a['nextBillingDate'] as DateTime).compareTo(b['nextBillingDate'] as DateTime));
    }

    return filtered;
  }

  Widget _buildHeader() {
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
                    CurrencyFormatter.format(_monthlyTotal),
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
                      '$_totalSubscriptions',
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
          if (_flaggedCount > 0) ...[
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
                      'AI found $_flaggedCount subscriptions you might want to review',
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

  Widget _buildSubscriptionsList() {
    final filtered = _filteredSubscriptions;

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
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
        return SubscriptionCard(
          name: sub['name'],
          amount: sub['amount'],
          billingCycle: sub['billingCycle'],
          nextBillingDate: sub['nextBillingDate'],
          flag: sub['flag'],
          iconColor: sub['iconColor'],
          isActive: sub['isActive'],
          onTap: () {
            // Navigate to subscription detail
          },
        );
      }).toList(),
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
          // Add new subscription
        },
        backgroundColor: LightColor.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                _buildHeader(),
                const SizedBox(height: 24),

                // Filter and sort
                _buildFilterSort(),
                const SizedBox(height: 20),

                // Subscriptions list
                _buildSubscriptionsList(),
                const SizedBox(height: 80), // Space for FAB
              ],
            ),
          ),
        ),
      ),
    );
  }
}
