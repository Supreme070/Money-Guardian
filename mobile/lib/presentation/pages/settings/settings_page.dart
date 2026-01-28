import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../presentation/blocs/auth/auth_bloc.dart';
import '../../../presentation/blocs/auth/auth_event.dart';
import '../../../presentation/blocs/auth/auth_state.dart';
import '../../../presentation/blocs/banking/banking_bloc.dart';
import '../../../presentation/blocs/banking/banking_event.dart';
import '../../../presentation/blocs/banking/banking_state.dart';
import '../../../presentation/blocs/email_scanning/email_scanning_bloc.dart';
import '../../../presentation/blocs/email_scanning/email_scanning_event.dart';
import '../../../presentation/blocs/email_scanning/email_scanning_state.dart';

// --- Color System (Consistent) ---
class AppColors {
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F7);
  static const Color primary = Color(0xFFCEA734); 
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);
  static const Color safe = Color(0xFF00E676);
  static const Color freeze = Color(0xFFCF6679);
  static const Color divider = Color(0xFFE0E0E0);
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    context.read<BankingBloc>().add(const BankingLoadRequested());
    context.read<EmailScanningBloc>().add(const EmailLoadRequested());
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign Out?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: const Text('Your data will remain guarded, but you will need to sign back in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(const AuthLogoutRequested());
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: Text('Sign Out', style: GoogleFonts.inter(color: AppColors.freeze, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
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
                    _SettingsItem(Icons.security_outlined, 'Security', 'Passcode, Face ID, Password'),
                    _SettingsItem(Icons.notifications_none_outlined, 'Notifications', 'Alert & pulse frequency'),
                    _SettingsItem(Icons.account_balance_wallet_outlined, 'Billing', 'Manage your subscription'),
                  ]),
                  
                  const SizedBox(height: 32),
                  
                  // 4. Support
                  _buildSectionHeader('Support'),
                  const SizedBox(height: 16),
                  _buildSettingsList([
                    _SettingsItem(Icons.help_outline, 'Help Center', 'Guides and troubleshooting'),
                    _SettingsItem(Icons.chat_bubble_outline, 'Contact Us', 'Chat with the Guardian team'),
                    _SettingsItem(Icons.privacy_tip_outlined, 'Privacy Policy', 'How we guard your data'),
                  ]),
                  
                  const SizedBox(height: 48),
                  
                  // Logout
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.freeze,
                        side: const BorderSide(color: AppColors.freeze),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Money Guardian v1.0.0',
                      style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          }
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        },
      ),
    );
  }

  Widget _buildProfileHero(AuthAuthenticated state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
            ),
            child: Center(
              child: Text(
                state.user.fullName?.substring(0, 1).toUpperCase() ?? 'M',
                style: GoogleFonts.inter(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.w700),
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
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  state.user.email,
                  style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    state.user.isPro ? 'PRO PLAN' : 'FREE PLAN',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
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
      style: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildConnectionTiles() {
    return Column(
      children: [
        _buildConnectionRow(
          Icons.account_balance_outlined,
          'Bank Connections',
          '3 accounts linked',
          () => Navigator.pushNamed(context, '/connect-bank'),
        ),
        const SizedBox(height: 12),
        _buildConnectionRow(
          Icons.alternate_email,
          'Email Scanning',
          'Scanning gmail.com',
          () => Navigator.pushNamed(context, '/connect-email'),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: AppColors.textPrimary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsList(List<_SettingsItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.divider.withOpacity(0.5), indent: 56),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            leading: Icon(item.icon, color: AppColors.textPrimary, size: 22),
            title: Text(item.title, style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 15)),
            subtitle: Text(item.subtitle, style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
            onTap: () {},
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

  _SettingsItem(this.icon, this.title, this.subtitle);
}
