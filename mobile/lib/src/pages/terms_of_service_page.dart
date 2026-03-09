import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/light_color.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({Key? key}) : super(key: key);

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
          'Terms of Service',
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
            '1. Acceptance of Terms',
            'By using Money Guardian, you agree to these terms. If you do not agree, do not use the app. We may update these terms periodically and will notify you of material changes.',
          ),
          _buildSection(
            '2. Service Description',
            'Money Guardian is a subscription tracking and money protection service. We help you:\n\n'
                '• Track recurring subscriptions and charges\n'
                '• Monitor your safe-to-spend amount\n'
                '• Receive alerts before charges happen\n'
                '• Detect unused or overpriced subscriptions\n\n'
                'Money Guardian is NOT a financial advisor, bank, or payment processor. We provide informational tools only.',
          ),
          _buildSection(
            '3. Account Responsibilities',
            '• You must provide accurate account information\n'
                '• You are responsible for maintaining your password security\n'
                '• You must be at least 18 years old to use the service\n'
                '• You are responsible for all activity under your account\n'
                '• Notify us immediately of any unauthorized access',
          ),
          _buildSection(
            '4. Pro Subscription',
            '• Pro subscriptions are billed monthly or annually\n'
                '• You can cancel at any time; access continues until period end\n'
                '• Refunds follow the applicable app store policy\n'
                '• We reserve the right to change pricing with 30 days notice\n'
                '• Free trial converts to paid unless cancelled before trial end',
          ),
          _buildSection(
            '5. Bank and Email Connections',
            '• Bank connections are provided through Plaid and are read-only\n'
                '• Email connections scan for subscription receipts only\n'
                '• You can disconnect bank or email access at any time\n'
                '• We are not responsible for third-party service availability\n'
                '• Data accuracy depends on information provided by your bank',
          ),
          _buildSection(
            '6. Limitations',
            '• We do not guarantee 100% accuracy of subscription detection\n'
                '• Safe-to-spend calculations are estimates, not financial advice\n'
                '• We are not liable for missed alerts due to connectivity issues\n'
                '• AI flags are suggestions and may not always be accurate\n'
                '• We are not responsible for charges from your subscription providers',
          ),
          _buildSection(
            '7. Intellectual Property',
            'All content, features, and functionality of Money Guardian are owned by Money Guardian and protected by copyright, trademark, and other intellectual property laws.',
          ),
          _buildSection(
            '8. Termination',
            'We may suspend or terminate your account if you violate these terms. You may delete your account at any time through Settings > Security > Delete Account.',
          ),
          _buildSection(
            '9. Contact',
            'For questions about these terms:\n\n'
                'Email: legal@moneyguardian.co\n'
                'Support: support@moneyguardian.co',
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
