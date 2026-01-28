import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/light_color.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({Key? key}) : super(key: key);

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
          'Privacy Policy',
          style: GoogleFonts.mulish(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: LightColor.titleTextColor,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Last updated: January 28, 2026',
            style: GoogleFonts.mulish(
              fontSize: 12,
              color: LightColor.grey,
            ),
          ),
          const SizedBox(height: 20),
          _buildSection(
            'Information We Collect',
            'Money Guardian collects the following information to provide our service:\n\n'
                '• Account information (email, name)\n'
                '• Bank transaction data (read-only via Plaid)\n'
                '• Email metadata for subscription detection\n'
                '• Subscription and billing information you enter\n'
                '• Device information for push notifications',
          ),
          _buildSection(
            'How We Use Your Data',
            '• Detect and track your subscriptions\n'
                '• Calculate your safe-to-spend amount\n'
                '• Send alerts about upcoming charges and overdraft risks\n'
                '• Improve our AI waste detection algorithms\n'
                '• Provide customer support',
          ),
          _buildSection(
            'Bank Data Security',
            'We use Plaid to connect to your bank accounts. We never store your bank login credentials. We only receive read-only access to transaction data. Plaid is SOC 2 Type II certified and used by major financial apps including Venmo and Cash App.',
          ),
          _buildSection(
            'Email Scanning',
            'When you connect your email, we scan for subscription-related receipts and confirmations only. We do not read, store, or process personal email content. Email access can be revoked at any time through Settings.',
          ),
          _buildSection(
            'Data Storage',
            'Your data is stored securely using industry-standard encryption (AES-256 at rest, TLS 1.3 in transit). Our servers are hosted on secure cloud infrastructure with SOC 2 compliance.',
          ),
          _buildSection(
            'Data Sharing',
            'We do not sell your personal data. We share data only with:\n\n'
                '• Plaid (bank connection)\n'
                '• Stripe (payment processing for Pro subscriptions)\n'
                '• Firebase (push notifications and authentication)\n\n'
                'Each third-party provider is bound by their own privacy policies and data protection agreements.',
          ),
          _buildSection(
            'Your Rights',
            '• Access: Request a copy of your data\n'
                '• Delete: Delete your account and all associated data\n'
                '• Portability: Export your subscription data\n'
                '• Opt-out: Disable notifications and email scanning\n\n'
                'To exercise these rights, contact support@moneyguardian.app',
          ),
          _buildSection(
            'Data Retention',
            'We retain your data for as long as your account is active. If you delete your account, all personal data is permanently removed within 30 days.',
          ),
          _buildSection(
            'Contact',
            'For privacy-related inquiries:\n\n'
                'Email: privacy@moneyguardian.app\n'
                'Support: support@moneyguardian.app',
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.mulish(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: LightColor.titleTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.mulish(
              fontSize: 14,
              color: LightColor.subTitleTextColor,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
