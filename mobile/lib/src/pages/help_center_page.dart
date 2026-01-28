import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/light_color.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({Key? key}) : super(key: key);

  static const List<Map<String, String>> _faqs = [
    {
      'question': 'What is the Daily Pulse?',
      'answer':
          'The Daily Pulse is your at-a-glance financial health indicator. It shows SAFE (green), CAUTION (yellow), or FREEZE (red) based on your upcoming charges relative to your available balance. Check it daily to know your spending status in 5 seconds.',
    },
    {
      'question': 'How does Money Guardian detect subscriptions?',
      'answer':
          'Money Guardian uses three methods: 1) Bank connection via Plaid to detect recurring charges, 2) Email scanning to find subscription receipts, and 3) Manual entry. Our AI analyzes patterns to flag unused, duplicate, or price-increased subscriptions.',
    },
    {
      'question': 'Is my bank data safe?',
      'answer':
          'We use Plaid for bank connections, which is the same service used by Venmo, Cash App, and thousands of financial apps. We only have read-only access to your transaction data. We never store your bank credentials and cannot move money.',
    },
    {
      'question': 'What does SAFE / CAUTION / FREEZE mean?',
      'answer':
          'SAFE (green): Your upcoming charges are covered and you have comfortable spending room.\n\nCAUTION (yellow): Upcoming charges will significantly reduce your balance. Be careful with discretionary spending.\n\nFREEZE (red): Upcoming charges may overdraft your account. Avoid non-essential spending.',
    },
    {
      'question': 'How do alerts work?',
      'answer':
          'Money Guardian sends alerts before charges happen, not after. You get notified about: upcoming subscription charges, overdraft risk, price increases, trial endings, and unused subscriptions you might want to cancel.',
    },
    {
      'question': 'What is included in the Pro plan?',
      'answer':
          'Pro unlocks: automatic bank connection for transaction sync, email scanning to find hidden subscriptions, AI-powered waste detection, unlimited subscription tracking, and priority alerts.',
    },
    {
      'question': 'Can I cancel my Pro subscription?',
      'answer':
          'Yes, you can cancel anytime through Settings > Subscription. You will continue to have Pro access until the end of your current billing period.',
    },
    {
      'question': 'How do I add a subscription manually?',
      'answer':
          'Tap the "Add" quick action on the home screen, or go to the Subscriptions tab and tap the + button. Enter the subscription name, amount, billing cycle, and next billing date.',
    },
  ];

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
          'Help Center',
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
          // Search (visual only for now)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: LightColor.lightGrey,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: LightColor.grey),
                const SizedBox(width: 12),
                Text(
                  'Search help articles...',
                  style: GoogleFonts.mulish(
                    color: LightColor.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Frequently Asked Questions',
            style: GoogleFonts.mulish(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: LightColor.titleTextColor,
            ),
          ),
          const SizedBox(height: 16),
          ..._faqs.map((faq) => _FaqTile(
                question: faq['question']!,
                answer: faq['answer']!,
              )),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: LightColor.lightGrey,
              borderRadius: BorderRadius.circular(14),
              border: _isExpanded
                  ? Border.all(color: LightColor.accent.withOpacity(0.3))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.question,
                        style: GoogleFonts.mulish(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: LightColor.titleTextColor,
                        ),
                      ),
                    ),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: LightColor.accent,
                    ),
                  ],
                ),
                if (_isExpanded) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.answer,
                    style: GoogleFonts.mulish(
                      fontSize: 13,
                      color: LightColor.subTitleTextColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
