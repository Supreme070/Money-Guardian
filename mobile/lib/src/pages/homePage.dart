import 'package:flutter/material.dart';
import 'package:money_guardian/src/theme/light_color.dart';
import 'package:money_guardian/src/widgets/pulse_status_card.dart';
import 'package:money_guardian/src/widgets/bottom_navigation_bar.dart';
import 'package:money_guardian/src/widgets/upcoming_subscription_item.dart';
import 'package:google_fonts/google_fonts.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentNavIndex = 0;

  // Mock data - will be replaced with actual state management
  final PulseStatus _currentStatus = PulseStatus.safe;
  final double _safeToSpend = 142.0;

  // Mock upcoming subscriptions
  final List<Map<String, dynamic>> _upcomingSubscriptions = [
    {
      'name': 'Netflix',
      'amount': 15.99,
      'dueDate': DateTime.now().add(const Duration(days: 2)),
      'isWarning': false,
    },
    {
      'name': 'Spotify',
      'amount': 9.99,
      'dueDate': DateTime.now().add(const Duration(days: 4)),
      'isWarning': false,
    },
    {
      'name': 'iCloud Storage',
      'amount': 2.99,
      'dueDate': DateTime.now().add(const Duration(days: 6)),
      'isWarning': true,
    },
  ];

  void _onNavTap(int index) {
    setState(() {
      _currentNavIndex = index;
    });
    // Navigate to different pages
    switch (index) {
      case 0:
        // Already on home
        break;
      case 1:
        Navigator.pushNamed(context, '/subscriptions');
        break;
      case 2:
        Navigator.pushNamed(context, '/calendar');
        break;
      case 3:
        Navigator.pushNamed(context, '/alerts');
        break;
    }
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: LightColor.navyBlue1,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    Icons.shield_rounded,
                    color: LightColor.yellow,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Money Guardian',
                style: GoogleFonts.mulish(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: LightColor.navyBlue1,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/settings'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: LightColor.lightGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.settings_rounded,
                color: LightColor.darkgrey,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? actionText, VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.mulish(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: LightColor.titleTextColor,
          ),
        ),
        if (actionText != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionText,
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

  Widget _buildUpcomingSubscriptions() {
    if (_upcomingSubscriptions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: LightColor.lightGrey.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: LightColor.safe,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'No upcoming charges',
              style: GoogleFonts.mulish(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: LightColor.subTitleTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "You're all clear for the next 7 days",
              style: GoogleFonts.mulish(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: LightColor.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _upcomingSubscriptions.map((sub) {
        return UpcomingSubscriptionItem(
          name: sub['name'],
          amount: sub['amount'],
          dueDate: sub['dueDate'],
          isWarning: sub['isWarning'],
          onTap: () {
            // Navigate to subscription detail
          },
        );
      }).toList(),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.subscriptions_rounded,
              label: 'Active Subs',
              value: '8',
              color: LightColor.accent,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: LightColor.lightGrey,
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.calendar_month_rounded,
              label: 'This Month',
              value: '\$87',
              color: LightColor.navyBlue1,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: LightColor.lightGrey,
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.warning_rounded,
              label: 'Alerts',
              value: '2',
              color: LightColor.caution,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.mulish(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: LightColor.titleTextColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.mulish(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: LightColor.subTitleTextColor,
          ),
        ),
      ],
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildAppBar(),
                const SizedBox(height: 24),

                // Daily Pulse Status Card
                PulseStatusCard(
                  status: _currentStatus,
                  safeToSpend: _safeToSpend,
                  onTap: () {
                    // Show detailed breakdown
                  },
                ),
                const SizedBox(height: 24),

                // Quick Stats
                _buildQuickStats(),
                const SizedBox(height: 28),

                // Next 7 Days
                _buildSectionHeader(
                  'Next 7 Days',
                  actionText: 'See all',
                  onAction: () => Navigator.pushNamed(context, '/calendar'),
                ),
                const SizedBox(height: 16),
                _buildUpcomingSubscriptions(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
