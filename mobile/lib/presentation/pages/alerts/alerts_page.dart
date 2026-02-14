import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../data/models/alert_model.dart';
import '../../../presentation/blocs/alerts/alert_bloc.dart';
import '../../../presentation/blocs/alerts/alert_event.dart';
import '../../../presentation/blocs/alerts/alert_state.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/analytics_service.dart';
import '../../../src/theme/light_color.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsService>().logScreenView(screenName: 'Alerts');
    context.read<AlertBloc>().add(const AlertLoadRequested());
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
          'Alerts',
          style: GoogleFonts.mulish(
            color: LightColor.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          BlocBuilder<AlertBloc, AlertState>(
            builder: (context, state) {
              if (state is AlertLoaded && state.unreadCount > 0) {
                return TextButton(
                  onPressed: () {
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
                      color: LightColor.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocBuilder<AlertBloc, AlertState>(
        builder: (context, state) {
          if (state is AlertLoading) {
            return const Center(child: CircularProgressIndicator(color: LightColor.primary));
          }

          if (state is AlertError) {
            return _buildErrorState(state.message);
          }

          if (state is AlertLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<AlertBloc>().add(const AlertLoadRequested());
              },
              child: _buildContent(state),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildContent(AlertLoaded state) {
    final filteredAlerts = _filterAlerts(state.alerts);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          
          // Summary Card
          _buildSummaryHeader(state),
          
          const SizedBox(height: 24),
          
          // Filters
          _buildFilters(),
          
          const SizedBox(height: 16),
          
          if (filteredAlerts.isEmpty)
            _buildEmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredAlerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _AlertCard(alert: filteredAlerts[index]);
              },
            ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(AlertLoaded state) {
    final unreadCount = state.unreadCount;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LightColor.textPrimary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: LightColor.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              unreadCount > 0 ? Icons.notifications_active : Icons.notifications_none,
              color: LightColor.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unreadCount > 0 ? '$unreadCount New Protections' : 'Shield is Active',
                  style: GoogleFonts.mulish(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unreadCount > 0 ? 'Action required for $unreadCount alerts' : 'Your money is safe and guarded',
                  style: GoogleFonts.mulish(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        _buildFilterChip('All', 'all'),
        const SizedBox(width: 8),
        _buildFilterChip('Critical', 'critical'),
        const SizedBox(width: 8),
        _buildFilterChip('Unread', 'unread'),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? LightColor.primary : LightColor.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.mulish(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : LightColor.textSecondary,
          ),
        ),
      ),
    );
  }

  List<AlertModel> _filterAlerts(List<AlertModel> alerts) {
    if (_selectedFilter == 'unread') return alerts.where((a) => !a.isRead).toList();
    if (_selectedFilter == 'critical') {
      return alerts.where((a) => a.severity == AlertSeverity.critical).toList();
    }
    return alerts;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.shield_outlined, size: 64, color: LightColor.surface),
            const SizedBox(height: 16),
            Text(
              'All Clear',
              style: GoogleFonts.mulish(
                color: LightColor.textTertiary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No threats detected at the moment.',
              style: GoogleFonts.mulish(color: LightColor.textTertiary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: LightColor.freeze, size: 48),
            const SizedBox(height: 16),
            Text('Failed to load alerts', style: GoogleFonts.mulish(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.mulish(color: LightColor.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.read<AlertBloc>().add(const AlertLoadRequested()),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final AlertModel alert;

  const _AlertCard({required this.alert});

  Color _getSeverityColor() {
    switch (alert.severity) {
      case AlertSeverity.critical: return LightColor.freeze;
      case AlertSeverity.warning: return LightColor.caution;
      case AlertSeverity.info: return LightColor.primary;
    }
  }

  IconData _getAlertIcon() {
    switch (alert.alertType) {
      case AlertType.upcomingCharge: return Icons.schedule;
      case AlertType.overdraftWarning: return Icons.warning_amber_rounded;
      case AlertType.priceIncrease: return Icons.trending_up_rounded;
      case AlertType.trialEnding: return Icons.timer_outlined;
      case AlertType.paymentFailed: return Icons.error_outline;
      default: return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final severityColor = _getSeverityColor();
    
    return Dismissible(
      key: Key(alert.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        context.read<AlertBloc>().add(AlertDismissRequested(alertId: alert.id));
      },
      background: Container(
        decoration: BoxDecoration(
          color: LightColor.freeze,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: InkWell(
        onTap: () {
          if (!alert.isRead) {
            context.read<AlertBloc>().add(AlertMarkReadRequested(alertIds: [alert.id]));
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: !alert.isRead ? severityColor.withOpacity(0.3) : LightColor.surface,
              width: !alert.isRead ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_getAlertIcon(), color: severityColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: GoogleFonts.mulish(
                            color: LightColor.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${alert.severity.name.toUpperCase()} • ${_formatRelativeTime(alert.createdAt)}',
                          style: GoogleFonts.mulish(
                            color: LightColor.textTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!alert.isRead)
                    Container(
                      height: 8,
                      width: 8,
                      decoration: BoxDecoration(color: severityColor, shape: BoxShape.circle),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                alert.message,
                style: GoogleFonts.mulish(
                  color: LightColor.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              if (alert.amount != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '-\$${alert.amount!.toStringAsFixed(2)}',
                    style: GoogleFonts.mulish(
                      color: LightColor.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime).abs();
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) {
      final int mins = diff.inMinutes;
      return '$mins ${mins == 1 ? 'minute' : 'minutes'} ago';
    }
    if (diff.inHours < 24) {
      final int hours = diff.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }
    if (diff.inDays < 7) {
      final int days = diff.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    }
    if (diff.inDays < 30) {
      final int weeks = (diff.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    }
    final int months = (diff.inDays / 30).floor();
    return '$months ${months == 1 ? 'month' : 'months'} ago';
  }
}
