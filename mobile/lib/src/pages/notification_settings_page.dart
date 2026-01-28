import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../presentation/blocs/auth/auth_bloc.dart';
import '../../presentation/blocs/auth/auth_event.dart';
import '../../presentation/blocs/auth/auth_state.dart';
import '../theme/light_color.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColor.background,
      appBar: AppBar(
        backgroundColor: LightColor.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: LightColor.titleTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.mulish(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: LightColor.titleTextColor,
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
                    color: LightColor.titleTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Control how Money Guardian notifies you about important events.',
                  style: GoogleFonts.mulish(
                    fontSize: 13,
                    color: LightColor.subTitleTextColor,
                  ),
                ),
                const SizedBox(height: 20),
                _buildToggleTile(
                  context: context,
                  icon: Icons.notifications_active_rounded,
                  iconColor: LightColor.accent,
                  title: 'Push Notifications',
                  subtitle: 'Overdraft warnings, upcoming charges, trial endings',
                  value: user.pushNotificationsEnabled,
                  onChanged: (bool value) {
                    context.read<AuthBloc>().add(
                          AuthUpdateProfileRequested(pushNotificationsEnabled: value),
                        );
                  },
                ),
                const SizedBox(height: 12),
                _buildToggleTile(
                  context: context,
                  icon: Icons.email_rounded,
                  iconColor: const Color(0xFFEA4335),
                  title: 'Email Notifications',
                  subtitle: 'Weekly summaries, monthly reports, account alerts',
                  value: user.emailNotificationsEnabled,
                  onChanged: (bool value) {
                    context.read<AuthBloc>().add(
                          AuthUpdateProfileRequested(emailNotificationsEnabled: value),
                        );
                  },
                ),
                const SizedBox(height: 28),
                Text(
                  'Notification Types',
                  style: GoogleFonts.mulish(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: LightColor.titleTextColor,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoTile(
                  icon: Icons.warning_rounded,
                  iconColor: LightColor.freeze,
                  title: 'Overdraft Warnings',
                  subtitle: 'Alert when an upcoming charge may overdraft your account',
                ),
                const SizedBox(height: 12),
                _buildInfoTile(
                  icon: Icons.event_rounded,
                  iconColor: LightColor.warning,
                  title: 'Upcoming Charges',
                  subtitle: 'Reminder 1-3 days before subscription charges',
                ),
                const SizedBox(height: 12),
                _buildInfoTile(
                  icon: Icons.timer_rounded,
                  iconColor: LightColor.caution,
                  title: 'Trial Endings',
                  subtitle: 'Alert before free trials auto-convert to paid',
                ),
                const SizedBox(height: 12),
                _buildInfoTile(
                  icon: Icons.trending_up_rounded,
                  iconColor: LightColor.accent,
                  title: 'Price Increases',
                  subtitle: 'Detect when a subscription amount changes',
                ),
                const SizedBox(height: 12),
                _buildInfoTile(
                  icon: Icons.visibility_off_rounded,
                  iconColor: LightColor.grey,
                  title: 'Unused Subscriptions',
                  subtitle: 'AI flags subscriptions with no detected usage',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildToggleTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LightColor.lightGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
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
                    color: LightColor.titleTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.mulish(
                    fontSize: 12,
                    color: LightColor.subTitleTextColor,
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

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LightColor.lightGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.mulish(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: LightColor.titleTextColor,
                  ),
                ),
                Text(
                  subtitle,
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
}
