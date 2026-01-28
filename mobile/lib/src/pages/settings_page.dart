import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/bank_connection_model.dart';
import '../../data/models/email_connection_model.dart';
import '../../presentation/blocs/auth/auth_bloc.dart';
import '../../presentation/blocs/auth/auth_event.dart';
import '../../presentation/blocs/auth/auth_state.dart';
import '../../presentation/blocs/banking/banking_bloc.dart';
import '../../presentation/blocs/banking/banking_event.dart';
import '../../presentation/blocs/banking/banking_state.dart';
import '../../presentation/blocs/email_scanning/email_scanning_bloc.dart';
import '../../presentation/blocs/email_scanning/email_scanning_event.dart';
import '../../presentation/blocs/email_scanning/email_scanning_state.dart';
import '../theme/light_color.dart';

/// Settings page with account management and app preferences
class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    context.read<BankingBloc>().add(const BankingLoadRequested());
    context.read<EmailScanningBloc>().add(const EmailLoadRequested());
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Log Out?',
          style: GoogleFonts.mulish(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.mulish(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: GoogleFonts.mulish(color: LightColor.subTitleTextColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AuthBloc>().add(const AuthLogoutRequested());
              // Navigate to login and clear all routes
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
            child: Text(
              'Log Out',
              style: GoogleFonts.mulish(color: LightColor.freeze),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSection(AuthAuthenticated state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [LightColor.navyBlue1, LightColor.navyBlue2],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getInitials(state.user.fullName ?? state.user.email),
                style: GoogleFonts.mulish(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.user.fullName ?? 'Money Guardian User',
                  style: GoogleFonts.mulish(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.user.email,
                  style: GoogleFonts.mulish(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTierColor(state.user.subscriptionTierDisplay)
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getTierLabel(state.user.subscriptionTierDisplay),
                    style: GoogleFonts.mulish(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/edit-profile');
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.edit_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connections',
          style: GoogleFonts.mulish(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: LightColor.titleTextColor,
          ),
        ),
        const SizedBox(height: 16),
        _buildBankConnectionsSummary(),
        const SizedBox(height: 12),
        _buildEmailConnectionsSummary(),
      ],
    );
  }

  Widget _buildBankConnectionsSummary() {
    return BlocBuilder<BankingBloc, BankingState>(
      builder: (context, state) {
        int connectionCount = 0;
        bool hasError = false;
        bool isProRequired = false;

        if (state is BankingLoaded) {
          connectionCount = state.connections.length;
          hasError = state.hasError;
        } else if (state is BankingProRequired) {
          isProRequired = true;
        }

        return _buildConnectionTile(
          icon: Icons.account_balance_rounded,
          iconColor: LightColor.accent,
          title: 'Bank Accounts',
          subtitle: isProRequired
              ? 'Pro feature'
              : connectionCount > 0
                  ? '$connectionCount connected'
                  : 'Not connected',
          hasError: hasError,
          isProRequired: isProRequired,
          onTap: () {
            Navigator.pushNamed(context, '/connect-bank');
          },
        );
      },
    );
  }

  Widget _buildEmailConnectionsSummary() {
    return BlocBuilder<EmailScanningBloc, EmailScanningState>(
      builder: (context, state) {
        int connectionCount = 0;
        bool hasError = false;
        bool isProRequired = false;

        if (state is EmailScanningLoaded) {
          connectionCount = state.connections.length;
          hasError = state.hasError;
        } else if (state is EmailScanningProRequired) {
          isProRequired = true;
        }

        return _buildConnectionTile(
          icon: Icons.email_rounded,
          iconColor: const Color(0xFFEA4335),
          title: 'Email Scanning',
          subtitle: isProRequired
              ? 'Pro feature'
              : connectionCount > 0
                  ? '$connectionCount connected'
                  : 'Not connected',
          hasError: hasError,
          isProRequired: isProRequired,
          onTap: () {
            Navigator.pushNamed(context, '/connect-email');
          },
        );
      },
    );
  }

  Widget _buildConnectionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool hasError,
    required bool isProRequired,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
                    Row(
                      children: [
                        if (hasError) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: LightColor.freeze,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          subtitle,
                          style: GoogleFonts.mulish(
                            fontSize: 12,
                            color: isProRequired
                                ? LightColor.yellow2
                                : hasError
                                    ? LightColor.freeze
                                    : LightColor.subTitleTextColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isProRequired)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: LightColor.yellow.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'PRO',
                    style: GoogleFonts.mulish(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: LightColor.yellow2,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: LightColor.grey,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preferences',
          style: GoogleFonts.mulish(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: LightColor.titleTextColor,
          ),
        ),
        const SizedBox(height: 16),
        _buildPreferenceTile(
          icon: Icons.notifications_rounded,
          title: 'Notifications',
          subtitle: 'Manage alert preferences',
          onTap: () {
            Navigator.pushNamed(context, '/notification-settings');
          },
        ),
        const SizedBox(height: 12),
        _buildPreferenceTile(
          icon: Icons.security_rounded,
          title: 'Security',
          subtitle: 'Password, biometrics',
          onTap: () {
            Navigator.pushNamed(context, '/security-settings');
          },
        ),
        const SizedBox(height: 12),
        _buildPreferenceTile(
          icon: Icons.palette_rounded,
          title: 'Appearance',
          subtitle: 'Theme, display options',
          onTap: () {
            Navigator.pushNamed(context, '/appearance-settings');
          },
        ),
        const SizedBox(height: 12),
        _buildPreferenceTile(
          icon: Icons.attach_money_rounded,
          title: 'Currency',
          subtitle: 'USD',
          onTap: () {
            Navigator.pushNamed(context, '/currency-settings');
          },
        ),
      ],
    );
  }

  Widget _buildPreferenceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
                  color: LightColor.navyBlue1.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: LightColor.navyBlue1, size: 22),
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
              const Icon(
                Icons.chevron_right_rounded,
                color: LightColor.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionSection(AuthAuthenticated state) {
    final isPro = state.user.isPro;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isPro
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [LightColor.yellow2, LightColor.yellow],
              )
            : null,
        color: isPro ? null : LightColor.lightGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPro
                    ? Icons.workspace_premium_rounded
                    : Icons.rocket_launch_rounded,
                color: isPro ? Colors.white : LightColor.yellow2,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPro ? 'Pro Subscription' : 'Upgrade to Pro',
                      style: GoogleFonts.mulish(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color:
                            isPro ? Colors.white : LightColor.titleTextColor,
                      ),
                    ),
                    Text(
                      isPro
                          ? 'All features unlocked'
                          : 'Unlock bank & email scanning',
                      style: GoogleFonts.mulish(
                        fontSize: 12,
                        color: isPro
                            ? Colors.white.withOpacity(0.8)
                            : LightColor.subTitleTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isPro) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/pro-upgrade');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: LightColor.yellow2,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'View Plans',
                  style: GoogleFonts.mulish(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          if (isPro) ...[
            const SizedBox(height: 12),
            Text(
              'Manage subscription',
              style: GoogleFonts.mulish(
                fontSize: 13,
                color: Colors.white.withOpacity(0.9),
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Support',
          style: GoogleFonts.mulish(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: LightColor.titleTextColor,
          ),
        ),
        const SizedBox(height: 16),
        _buildSupportTile(
          icon: Icons.help_outline_rounded,
          title: 'Help Center',
          onTap: () {
            Navigator.pushNamed(context, '/help');
          },
        ),
        const SizedBox(height: 12),
        _buildSupportTile(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Contact Support',
          onTap: () {
            Navigator.pushNamed(context, '/contact');
          },
        ),
        const SizedBox(height: 12),
        _buildSupportTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          onTap: () {
            Navigator.pushNamed(context, '/privacy');
          },
        ),
        const SizedBox(height: 12),
        _buildSupportTile(
          icon: Icons.description_outlined,
          title: 'Terms of Service',
          onTap: () {
            Navigator.pushNamed(context, '/terms');
          },
        ),
      ],
    );
  }

  Widget _buildSupportTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: LightColor.lightGrey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: LightColor.darkgrey, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.mulish(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: LightColor.titleTextColor,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: LightColor.grey,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _logout,
        style: OutlinedButton.styleFrom(
          foregroundColor: LightColor.freeze,
          side: const BorderSide(color: LightColor.freeze),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, size: 20),
            const SizedBox(width: 8),
            Text(
              'Log Out',
              style: GoogleFonts.mulish(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionInfo() {
    return Center(
      child: Text(
        'Money Guardian v1.0.0',
        style: GoogleFonts.mulish(
          fontSize: 12,
          color: LightColor.grey,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'pro':
        return LightColor.yellow;
      case 'premium':
        return LightColor.accent;
      default:
        return LightColor.grey;
    }
  }

  String _getTierLabel(String tier) {
    switch (tier) {
      case 'pro':
        return 'PRO';
      case 'premium':
        return 'PREMIUM';
      default:
        return 'FREE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColor.background,
      appBar: AppBar(
        backgroundColor: LightColor.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: LightColor.titleTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.mulish(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: LightColor.titleTextColor,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          if (authState is AuthAuthenticated) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserSection(authState),
                  const SizedBox(height: 28),
                  _buildConnectionsSection(),
                  const SizedBox(height: 28),
                  _buildSubscriptionSection(authState),
                  const SizedBox(height: 28),
                  _buildPreferencesSection(),
                  const SizedBox(height: 28),
                  _buildSupportSection(),
                  const SizedBox(height: 32),
                  _buildLogoutButton(),
                  const SizedBox(height: 24),
                  _buildVersionInfo(),
                  const SizedBox(height: 40),
                ],
              ),
            );
          }

          return const Center(
            child: CircularProgressIndicator(color: LightColor.accent),
          );
        },
      ),
    );
  }
}
