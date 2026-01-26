import 'package:flutter/material.dart';
import 'package:money_guardian/src/theme/light_color.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:money_guardian/core/utils/currency_formatter.dart';
import 'package:money_guardian/core/utils/date_formatter.dart';

/// AI-detected flags for subscriptions
enum SubscriptionFlag {
  none,
  unused,          // Not used in 30+ days
  duplicate,       // Similar to another subscription
  priceIncrease,   // Price went up recently
  trialEnding,     // Free trial ending soon
  forgotten,       // Added long ago, rarely used
}

class SubscriptionCard extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final IconData? icon;
  final Color? iconColor;
  final double amount;
  final String billingCycle; // 'monthly', 'yearly', 'weekly'
  final DateTime nextBillingDate;
  final SubscriptionFlag flag;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SubscriptionCard({
    Key? key,
    required this.name,
    this.logoUrl,
    this.icon,
    this.iconColor,
    required this.amount,
    required this.billingCycle,
    required this.nextBillingDate,
    this.flag = SubscriptionFlag.none,
    this.isActive = true,
    this.onTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: _hasFlagBorder()
              ? Border.all(color: _getFlagColor().withOpacity(0.4), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Logo/Icon with optional inactive overlay
                Stack(
                  children: [
                    _buildLogo(),
                    if (!isActive)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.pause_rounded,
                              color: LightColor.grey,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                // Name and cycle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.mulish(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? LightColor.titleTextColor
                              : LightColor.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getBillingCycleLabel(),
                        style: GoogleFonts.mulish(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: LightColor.subTitleTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(amount),
                      style: GoogleFonts.mulish(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isActive
                            ? LightColor.titleTextColor
                            : LightColor.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: LightColor.subTitleTextColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getNextBillingLabel(),
                          style: GoogleFonts.mulish(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: LightColor.subTitleTextColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            // AI Flag indicator
            if (flag != SubscriptionFlag.none) ...[
              const SizedBox(height: 12),
              _buildFlagBanner(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: iconColor?.withOpacity(0.1) ?? LightColor.lightGrey,
        borderRadius: BorderRadius.circular(14),
      ),
      child: logoUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildIconPlaceholder(),
              ),
            )
          : _buildIconPlaceholder(),
    );
  }

  Widget _buildIconPlaceholder() {
    return Center(
      child: Icon(
        icon ?? Icons.subscriptions_rounded,
        color: iconColor ?? LightColor.accent,
        size: 28,
      ),
    );
  }

  Widget _buildFlagBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getFlagColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _getFlagIcon(),
            size: 16,
            color: _getFlagColor(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getFlagMessage(),
              style: GoogleFonts.mulish(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getFlagColor(),
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: _getFlagColor(),
          ),
        ],
      ),
    );
  }

  bool _hasFlagBorder() {
    return flag == SubscriptionFlag.unused ||
        flag == SubscriptionFlag.duplicate ||
        flag == SubscriptionFlag.forgotten;
  }

  Color _getFlagColor() {
    switch (flag) {
      case SubscriptionFlag.none:
        return Colors.transparent;
      case SubscriptionFlag.unused:
      case SubscriptionFlag.duplicate:
      case SubscriptionFlag.forgotten:
        return LightColor.caution;
      case SubscriptionFlag.priceIncrease:
        return LightColor.freeze;
      case SubscriptionFlag.trialEnding:
        return LightColor.accent;
    }
  }

  IconData _getFlagIcon() {
    switch (flag) {
      case SubscriptionFlag.none:
        return Icons.check;
      case SubscriptionFlag.unused:
        return Icons.hourglass_empty_rounded;
      case SubscriptionFlag.duplicate:
        return Icons.content_copy_rounded;
      case SubscriptionFlag.priceIncrease:
        return Icons.trending_up_rounded;
      case SubscriptionFlag.trialEnding:
        return Icons.timer_rounded;
      case SubscriptionFlag.forgotten:
        return Icons.visibility_off_rounded;
    }
  }

  String _getFlagMessage() {
    switch (flag) {
      case SubscriptionFlag.none:
        return '';
      case SubscriptionFlag.unused:
        return "Haven't used this in 30+ days";
      case SubscriptionFlag.duplicate:
        return 'Similar to another subscription';
      case SubscriptionFlag.priceIncrease:
        return 'Price increased recently';
      case SubscriptionFlag.trialEnding:
        return 'Free trial ending soon';
      case SubscriptionFlag.forgotten:
        return 'You might have forgotten about this';
    }
  }

  String _getBillingCycleLabel() {
    switch (billingCycle.toLowerCase()) {
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
      case 'annual':
        return 'Yearly';
      case 'quarterly':
        return 'Quarterly';
      default:
        return billingCycle;
    }
  }

  String _getNextBillingLabel() {
    final daysUntil = DateFormatter.daysUntil(nextBillingDate);
    if (daysUntil == 0) return 'Today';
    if (daysUntil == 1) return 'Tomorrow';
    if (daysUntil < 7) return 'in $daysUntil days';
    return DateFormatter.formatShort(nextBillingDate);
  }
}
