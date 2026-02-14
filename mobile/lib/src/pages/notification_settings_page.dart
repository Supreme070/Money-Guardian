import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/injection.dart';
import '../../core/services/analytics_service.dart';
import '../../data/models/user_model.dart';
import '../../presentation/blocs/auth/auth_bloc.dart';
import '../../presentation/blocs/auth/auth_event.dart';
import '../../presentation/blocs/auth/auth_state.dart';
import '../theme/light_color.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  @override
  void initState() {
    super.initState();
    getIt<AnalyticsService>().logScreenView(screenName: 'NotificationSettings');
  }

  void _updateNotificationPreferences(
    NotificationPreferences current, {
    bool? overdraftWarnings,
    bool? upcomingCharges,
    bool? trialEndings,
    bool? priceIncreases,
    bool? unusedSubscriptions,
  }) {
    final updated = current.copyWith(
      overdraftWarnings: overdraftWarnings,
      upcomingCharges: upcomingCharges,
      trialEndings: trialEndings,
      priceIncreases: priceIncreases,
      unusedSubscriptions: unusedSubscriptions,
    );
    context.read<AuthBloc>().add(
          AuthUpdateProfileRequested(notificationPreferences: updated),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F1419) : LightColor.background;
    final textColor =
        isDark ? const Color(0xFFF0F2F5) : LightColor.titleTextColor;
    final subtitleColor =
        isDark ? const Color(0xFFAEB5BD) : LightColor.subTitleTextColor;
    final surfaceColor =
        isDark ? const Color(0xFF1C2530) : LightColor.lightGrey;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.mulish(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! AuthAuthenticated) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = state.user;
          final prefs = user.notificationPreferences;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alert Preferences',
                  style: GoogleFonts.mulish(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Control how Money Guardian notifies you about important events.',
                  style: GoogleFonts.mulish(
                    fontSize: 13,
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 20),
                _buildToggleTile(
                  icon: Icons.notifications_active_rounded,
                  iconColor: LightColor.accent,
                  title: 'Push Notifications',
                  subtitle:
                      'Overdraft warnings, upcoming charges, trial endings',
                  value: user.pushNotificationsEnabled,
                  onChanged: (bool value) {
                    context.read<AuthBloc>().add(
                          AuthUpdateProfileRequested(
                              pushNotificationsEnabled: value),
                        );
                  },
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  surfaceColor: surfaceColor,
                ),
                const SizedBox(height: 12),
                _buildToggleTile(
                  icon: Icons.email_rounded,
                  iconColor: const Color(0xFFEA4335),
                  title: 'Email Notifications',
                  subtitle: 'Weekly summaries, monthly reports, account alerts',
                  value: user.emailNotificationsEnabled,
                  onChanged: (bool value) {
                    context.read<AuthBloc>().add(
                          AuthUpdateProfileRequested(
                              emailNotificationsEnabled: value),
                        );
                  },
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  surfaceColor: surfaceColor,
                ),
                const SizedBox(height: 28),
                Text(
                  'Notification Types',
                  style: GoogleFonts.mulish(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose which types of alerts you want to receive.',
                  style: GoogleFonts.mulish(
                    fontSize: 13,
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 16),
                _buildToggleTile(
                  icon: Icons.warning_rounded,
                  iconColor: LightColor.freeze,
                  title: 'Overdraft Warnings',
                  subtitle:
                      'Alert when an upcoming charge may overdraft your account',
                  value: prefs.overdraftWarnings,
                  onChanged: (bool value) {
                    _updateNotificationPreferences(prefs,
                        overdraftWarnings: value);
                  },
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  surfaceColor: surfaceColor,
                ),
                const SizedBox(height: 12),
                _buildToggleTile(
                  icon: Icons.event_rounded,
                  iconColor: LightColor.warning,
                  title: 'Upcoming Charges',
                  subtitle: 'Reminder 1-3 days before subscription charges',
                  value: prefs.upcomingCharges,
                  onChanged: (bool value) {
                    _updateNotificationPreferences(prefs,
                        upcomingCharges: value);
                  },
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  surfaceColor: surfaceColor,
                ),
                const SizedBox(height: 12),
                _buildToggleTile(
                  icon: Icons.timer_rounded,
                  iconColor: LightColor.caution,
                  title: 'Trial Endings',
                  subtitle: 'Alert before free trials auto-convert to paid',
                  value: prefs.trialEndings,
                  onChanged: (bool value) {
                    _updateNotificationPreferences(prefs,
                        trialEndings: value);
                  },
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  surfaceColor: surfaceColor,
                ),
                const SizedBox(height: 12),
                _buildToggleTile(
                  icon: Icons.trending_up_rounded,
                  iconColor: LightColor.accent,
                  title: 'Price Increases',
                  subtitle: 'Detect when a subscription amount changes',
                  value: prefs.priceIncreases,
                  onChanged: (bool value) {
                    _updateNotificationPreferences(prefs,
                        priceIncreases: value);
                  },
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  surfaceColor: surfaceColor,
                ),
                const SizedBox(height: 12),
                _buildToggleTile(
                  icon: Icons.visibility_off_rounded,
                  iconColor: isDark
                      ? const Color(0xFF7B8FA6)
                      : LightColor.grey,
                  title: 'Unused Subscriptions',
                  subtitle: 'AI flags subscriptions with no detected usage',
                  value: prefs.unusedSubscriptions,
                  onChanged: (bool value) {
                    _updateNotificationPreferences(prefs,
                        unusedSubscriptions: value);
                  },
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  surfaceColor: surfaceColor,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color textColor,
    required Color subtitleColor,
    required Color surfaceColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.mulish(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.mulish(
                    fontSize: 12,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: LightColor.accent,
          ),
        ],
      ),
    );
  }
}
