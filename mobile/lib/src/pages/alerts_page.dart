import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/alert_model.dart';
import '../../presentation/blocs/alerts/alert_bloc.dart';
import '../../presentation/blocs/alerts/alert_event.dart';
import '../../presentation/blocs/alerts/alert_state.dart';
import '../theme/light_color.dart';
import '../widgets/bottom_navigation_bar.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({Key? key}) : super(key: key);

  @override
  _AlertsPageState createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  int _currentNavIndex = 3;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    context.read<AlertBloc>().add(const AlertLoadRequested());
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
        Navigator.pushReplacementNamed(context, '/subscriptions');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/calendar');
        break;
      case 3:
        break;
    }
  }

  List<AlertModel> _filterAlerts(List<AlertModel> alerts) {
    if (_selectedFilter == 'all') return alerts;
    if (_selectedFilter == 'unread') return alerts.where((a) => !a.isRead).toList();
    if (_selectedFilter == 'critical') {
      return alerts.where((a) => a.severity == AlertSeverity.critical).toList();
    }
    return alerts;
  }

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
      case AlertType.largeCharge:
        return Icons.attach_money_rounded;
    }
  }

  Widget _buildHeader(AlertLoaded state) {
    final unreadCount = state.unreadCount;

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
                  unreadCount > 0 ? '$unreadCount New Alerts' : 'All Caught Up',
                  style: GoogleFonts.mulish(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unreadCount > 0
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
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: LightColor.freeze,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$unreadCount',
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

  Widget _buildAlertCard(AlertModel alert) {
    final color = _getSeverityColor(alert.severity);

    return Dismissible(
      key: Key(alert.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        context.read<AlertBloc>().add(AlertDismissRequested(alertId: alert.id));
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: LightColor.freeze,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete_rounded,
          color: Colors.white,
        ),
      ),
      child: Container(
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
              if (!alert.isRead) {
                context.read<AlertBloc>().add(
                      AlertMarkReadRequested(alertIds: [alert.id]),
                    );
              }
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
                            _getAlertIcon(alert.alertType),
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
                              DateFormatter.formatRelative(alert.createdAt),
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
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
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
      ),
    );
  }

  Widget _buildAlertsList(List<AlertModel> alerts) {
    final filtered = _filterAlerts(alerts);

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
              context.read<AlertBloc>().add(const AlertLoadRequested());
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
      body: SafeArea(
        child: BlocBuilder<AlertBloc, AlertState>(
          builder: (context, state) {
            if (state is AlertLoading) {
              return _buildLoadingState();
            }

            if (state is AlertError) {
              return _buildErrorState(state.message);
            }

            if (state is AlertLoaded) {
              return RefreshIndicator(
                onRefresh: () async {
                  context.read<AlertBloc>().add(const AlertLoadRequested());
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
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
                            if (state.unreadCount > 0)
                              GestureDetector(
                                onTap: () {
                                  final unreadIds = state.alerts
                                      .where((a) => !a.isRead)
                                      .map((a) => a.id)
                                      .toList();
                                  context.read<AlertBloc>().add(
                                        AlertMarkReadRequested(alertIds: unreadIds),
                                      );
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
                        _buildHeader(state),
                        const SizedBox(height: 24),

                        // Filter tabs
                        _buildFilterTabs(),
                        const SizedBox(height: 20),

                        // Alerts list
                        _buildAlertsList(state.alerts),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            }

            return _buildLoadingState();
          },
        ),
      ),
    );
  }
}
