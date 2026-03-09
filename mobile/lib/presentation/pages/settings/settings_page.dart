import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../presentation/blocs/auth/auth_bloc.dart';
import '../../../presentation/blocs/auth/auth_event.dart';
import '../../../presentation/blocs/auth/auth_state.dart';
import '../../../presentation/blocs/banking/banking_bloc.dart';
import '../../../presentation/blocs/banking/banking_event.dart';
import '../../../presentation/blocs/banking/banking_state.dart';
import '../../../presentation/blocs/email_scanning/email_scanning_bloc.dart';
import '../../../presentation/blocs/email_scanning/email_scanning_event.dart';
import '../../../presentation/blocs/email_scanning/email_scanning_state.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/analytics_service.dart';
import '../../../src/theme/light_color.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    getIt<AnalyticsService>().logScreenView(screenName: 'Settings');
    context.read<BankingBloc>().add(const BankingLoadRequested());
    context.read<EmailScanningBloc>().add(const EmailLoadRequested());
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign Out?', style: GoogleFonts.mulish(fontWeight: FontWeight.w700)),
        content: const Text('Your data will remain guarded, but you will need to sign back in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.mulish(color: LightColor.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(const AuthLogoutRequested());
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: Text('Sign Out', style: GoogleFonts.mulish(color: LightColor.freeze, fontWeight: FontWeight.w600)),
          ),
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
          'Settings',
          style: GoogleFonts.mulish(
            color: LightColor.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  
                  // 1. Profile Hero
                  _buildProfileHero(state),
                  
                  const SizedBox(height: 32),
                  
                  // 2. Connections
                  _buildSectionHeader('Connections'),
                  const SizedBox(height: 16),
                  _buildConnectionTiles(),
                  
                  const SizedBox(height: 32),
                  
                  // 3. Security & Preferences
                  _buildSectionHeader('Account & Security'),
                  const SizedBox(height: 16),
                  _buildSettingsList([
                    _SettingsItem(Icons.security_outlined, 'Security', 'Passcode, Face ID, Password', '/security-settings'),
                    _SettingsItem(Icons.notifications_none_outlined, 'Notifications', 'Alert & pulse frequency', '/notification-settings'),
                    _SettingsItem(Icons.account_balance_wallet_outlined, 'Billing', 'Manage your subscription', '/pro-upgrade'),
                  ]),

                  const SizedBox(height: 32),

                  // 4. Data & Privacy
                  _buildSectionHeader('Data & Privacy'),
                  const SizedBox(height: 16),
                  _buildSettingsList([
                    _SettingsItem(Icons.download_outlined, 'Export My Data', 'Download all your data', '/export-data'),
                    _SettingsItem(Icons.privacy_tip_outlined, 'Privacy Policy', 'How we guard your data', '/privacy'),
                    _SettingsItem(Icons.description_outlined, 'Terms of Service', 'Usage terms and conditions', '/terms'),
                  ]),

                  const SizedBox(height: 32),

                  // 5. Support
                  _buildSectionHeader('Support'),
                  const SizedBox(height: 16),
                  _buildSettingsList([
                    _SettingsItem(Icons.help_outline, 'Help Center', 'Guides and troubleshooting', '/help'),
                    _SettingsItem(Icons.chat_bubble_outline, 'Contact Us', 'Chat with the Guardian team', '/contact'),
                  ]),
                  
                  const SizedBox(height: 48),
                  
                  // Logout
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LightColor.freeze,
                        side: const BorderSide(color: LightColor.freeze),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('Sign Out', style: GoogleFonts.mulish(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Money Guardian v1.0.0',
                      style: GoogleFonts.mulish(color: LightColor.textTertiary, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          }
          return Skeletonizer(
            enabled: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: LightColor.textPrimary, borderRadius: BorderRadius.circular(24)),
                    child: Row(
                      children: [
                        Container(height: 64, width: 64, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Loading User', style: GoogleFonts.mulish(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('user@example.com', style: GoogleFonts.mulish(color: Colors.white60, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text('Connections', style: GoogleFonts.mulish(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  ...List.generate(2, (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: LightColor.surface, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.link, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: Text('Connection', style: GoogleFonts.mulish(fontWeight: FontWeight.w600, fontSize: 15))),
                          const Icon(Icons.chevron_right, color: LightColor.textTertiary),
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHero(AuthAuthenticated state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: LightColor.textPrimary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: LightColor.primary.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: LightColor.primary.withOpacity(0.3), width: 2),
            ),
            child: Center(
              child: Text(
                state.user.fullName?.substring(0, 1).toUpperCase() ?? 'M',
                style: GoogleFonts.mulish(color: LightColor.primary, fontSize: 24, fontWeight: FontWeight.w700),
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
                  style: GoogleFonts.mulish(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  state.user.email,
                  style: GoogleFonts.mulish(color: Colors.white.withOpacity(0.6), fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: LightColor.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    state.user.isPro ? 'PRO PLAN' : 'FREE PLAN',
                    style: GoogleFonts.mulish(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.mulish(
        color: LightColor.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildConnectionTiles() {
    return Column(
      children: [
        BlocBuilder<BankingBloc, BankingState>(
          builder: (context, bankState) {
            String bankSubtitle = 'Not connected';
            if (bankState is BankingLoaded) {
              final count = bankState.accountCount;
              bankSubtitle = count > 0
                  ? '$count account${count == 1 ? '' : 's'} linked'
                  : 'Not connected';
            } else if (bankState is BankingLoading) {
              bankSubtitle = 'Loading...';
            }
            return _buildConnectionRow(
              Icons.account_balance_outlined,
              'Bank Connections',
              bankSubtitle,
              () => Navigator.pushNamed(context, '/connect-bank'),
            );
          },
        ),
        const SizedBox(height: 12),
        BlocBuilder<EmailScanningBloc, EmailScanningState>(
          builder: (context, emailState) {
            String emailSubtitle = 'Not connected';
            if (emailState is EmailScanningLoaded) {
              final count = emailState.connections.length;
              if (count > 0) {
                emailSubtitle = 'Scanning ${emailState.connections.first.emailAddress}';
              }
            } else if (emailState is EmailScanningLoading) {
              emailSubtitle = 'Loading...';
            }
            return _buildConnectionRow(
              Icons.alternate_email,
              'Email Scanning',
              emailSubtitle,
              () => Navigator.pushNamed(context, '/connect-email'),
            );
          },
        ),
      ],
    );
  }

  Widget _buildConnectionRow(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: LightColor.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: LightColor.textPrimary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.mulish(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.mulish(color: LightColor.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: LightColor.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsList(List<_SettingsItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: LightColor.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: LightColor.divider.withOpacity(0.5), indent: 56),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            leading: Icon(item.icon, color: LightColor.textPrimary, size: 22),
            title: Text(item.title, style: GoogleFonts.mulish(fontWeight: FontWeight.w500, fontSize: 15)),
            subtitle: Text(item.subtitle, style: GoogleFonts.mulish(color: LightColor.textTertiary, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: LightColor.textTertiary, size: 20),
            onTap: () => Navigator.pushNamed(context, item.route),
          );
        },
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  _SettingsItem(this.icon, this.title, this.subtitle, this.route);
}
