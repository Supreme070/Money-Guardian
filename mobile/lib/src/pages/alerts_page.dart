import 'package:flutter/material.dart';
import 'package:money_guardian/src/theme/light_color.dart';
import 'package:money_guardian/src/widgets/bottom_navigation_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:money_guardian/core/utils/currency_formatter.dart';
import 'package:money_guardian/core/utils/date_formatter.dart';

enum AlertType {
  upcomingCharge,
  overdraftWarning,
  priceIncrease,
  trialEnding,
  unusedSubscription,
  paymentFailed,
}

enum AlertSeverity {
  info,
  warning,
  critical,
}

class AlertItem {
  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String message;
  final DateTime date;
  final double? amount;
  final String? subscriptionName;
  final bool isRead;

  AlertItem({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.date,
    this.amount,
    this.subscriptionName,
    this.isRead = false,
  });
}

class AlertsPage extends StatefulWidget {
  const AlertsPage({Key? key}) : super(key: key);

  @override
  _AlertsPageState createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  int _currentNavIndex = 3;
  String _selectedFilter = 'all';

  // Mock alerts data
  final List<AlertItem> _alerts = [
    AlertItem(
      id: '1',
      type: AlertType.overdraftWarning,
      severity: AlertSeverity.critical,
      title: 'Overdraft Risk',
      message: 'Adobe CC charge of \$54.99 on Jan 22 may overdraft your account',
      date: DateTime.now(),
      amount: 54.99,
      subscriptionName: 'Adobe Creative Cloud',
    ),
    AlertItem(
      id: '2',
      type: AlertType.trialEnding,
      severity: AlertSeverity.warning,
      title: 'Trial Ending Soon',
      message: 'Your Disney+ trial ends in 3 days. You will be charged \$7.99',
      date: DateTime.now().add(const Duration(days: 3)),
      amount: 7.99,
      subscriptionName: 'Disney+',
    ),
    AlertItem(
      id: '3',
      type: AlertType.upcomingCharge,
      severity: AlertSeverity.info,
      title: 'Upcoming Charge',
      message: 'Netflix subscription renews tomorrow',
      date: DateTime.now().add(const Duration(days: 1)),
      amount: 15.99,
      subscriptionName: 'Netflix',
    ),
    AlertItem(
      id: '4',
      type: AlertType.priceIncrease,
      severity: AlertSeverity.warning,
      title: 'Price Increase',
      message: 'Spotify increased from \$9.99 to \$10.99 starting next month',
      date: DateTime.now().add(const Duration(days: 30)),
      amount: 10.99,
      subscriptionName: 'Spotify',
      isRead: true,
    ),
    AlertItem(
      id: '5',
      type: AlertType.unusedSubscription,
      severity: AlertSeverity.info,
      title: 'Unused Subscription',
      message: "You haven't used Gym Membership in 45 days. Consider canceling?",
      date: DateTime.now().subtract(const Duration(days: 45)),
      amount: 29.99,
      subscriptionName: 'Gym Membership',
      isRead: true,
    ),
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
        Navigator.pushReplacementNamed(context, '/subscriptions');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/calendar');
        break;
      case 3:
        // Already on alerts
        break;
    }
  }

  List<AlertItem> get _filteredAlerts {
    if (_selectedFilter == 'all') return _alerts;
    if (_selectedFilter == 'unread') return _alerts.where((a) => !a.isRead).toList();
    if (_selectedFilter == 'critical') {
      return _alerts.where((a) => a.severity == AlertSeverity.critical).toList();
    }
    return _alerts;
  }

  int get _unreadCount => _alerts.where((a) => !a.isRead).length;

  Color _getSeverityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return LightColor.freeze;
      case AlertSeverity.warning:
        return LightColor.caution;
      case AlertSeverity.info:
        return LightColor.accent;
    }
  }

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.upcomingCharge:
        return Icons.schedule_rounded;
      case AlertType.overdraftWarning:
        return Icons.warning_rounded;
      case AlertType.priceIncrease:
        return Icons.trending_up_rounded;
      case AlertType.trialEnding:
        return Icons.timer_rounded;
      case AlertType.unusedSubscription:
        return Icons.visibility_off_rounded;
      case AlertType.paymentFailed:
        return Icons.error_outline_rounded;
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LightColor.navyBlue1,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(
                Icons.notifications_active_rounded,
                color: LightColor.yellow,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _unreadCount > 0 ? '$_unreadCount New Alerts' : 'All Caught Up',
                  style: GoogleFonts.mulish(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _unreadCount > 0
                      ? 'Tap to review and take action'
                      : 'No new notifications',
                  style: GoogleFonts.mulish(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          if (_unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: LightColor.freeze,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_unreadCount',
                style: GoogleFonts.mulish(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('All', 'all'),
          _buildFilterChip('Unread', 'unread'),
          _buildFilterChip('Critical', 'critical'),
        ],
      ),
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

  Widget _buildAlertCard(AlertItem alert) {
    final color = _getSeverityColor(alert.severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: !alert.isRead
            ? Border.all(color: color.withOpacity(0.3), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Handle alert tap
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          _getAlertIcon(alert.type),
                          color: color,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  alert.title,
                                  style: GoogleFonts.mulish(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: LightColor.titleTextColor,
                                  ),
                                ),
                              ),
                              if (!alert.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormatter.formatRelative(alert.date),
                            style: GoogleFonts.mulish(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: LightColor.subTitleTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  alert.message,
                  style: GoogleFonts.mulish(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: LightColor.darkgrey,
                    height: 1.4,
                  ),
                ),
                if (alert.amount != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (alert.subscriptionName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: LightColor.lightGrey,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            alert.subscriptionName!,
                            style: GoogleFonts.mulish(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: LightColor.darkgrey,
                            ),
                          ),
                        ),
                      Text(
                        CurrencyFormatter.format(alert.amount!),
                        style: GoogleFonts.mulish(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertsList() {
    final filtered = _filteredAlerts;

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const Icon(
                Icons.notifications_off_rounded,
                size: 48,
                color: LightColor.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'No alerts',
                style: GoogleFonts.mulish(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: LightColor.subTitleTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "You're all caught up!",
                style: GoogleFonts.mulish(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: LightColor.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: filtered.map((alert) => _buildAlertCard(alert)).toList(),
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
                // Page title with mark all read
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Alerts',
                      style: GoogleFonts.mulish(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: LightColor.titleTextColor,
                      ),
                    ),
                    if (_unreadCount > 0)
                      GestureDetector(
                        onTap: () {
                          // Mark all as read
                        },
                        child: Text(
                          'Mark all read',
                          style: GoogleFonts.mulish(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: LightColor.accent,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Header
                _buildHeader(),
                const SizedBox(height: 24),

                // Filter tabs
                _buildFilterTabs(),
                const SizedBox(height: 20),

                // Alerts list
                _buildAlertsList(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
