import 'package:flutter/material.dart';
import 'package:money_guardian/src/theme/light_color.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:money_guardian/core/utils/currency_formatter.dart';
import 'package:money_guardian/core/utils/date_formatter.dart';

class UpcomingSubscriptionItem extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final IconData? icon;
  final double amount;
  final DateTime dueDate;
  final bool isWarning;
  final VoidCallback? onTap;

  const UpcomingSubscriptionItem({
    Key? key,
    required this.name,
    this.logoUrl,
    this.icon,
    required this.amount,
    required this.dueDate,
    this.isWarning = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final daysUntil = DateFormatter.daysUntil(dueDate);
    final isToday = daysUntil == 0;
    final isTomorrow = daysUntil == 1;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isWarning
              ? Border.all(color: LightColor.caution.withOpacity(0.5), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Logo/Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: LightColor.lightGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: logoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildIconPlaceholder(),
                      ),
                    )
                  : _buildIconPlaceholder(),
            ),
            const SizedBox(width: 14),
            // Name and date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.mulish(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: LightColor.titleTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: isToday ? LightColor.freeze : LightColor.subTitleTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getDateLabel(isToday, isTomorrow, daysUntil),
                        style: GoogleFonts.mulish(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isToday ? LightColor.freeze : LightColor.subTitleTextColor,
                        ),
                      ),
                    ],
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
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: LightColor.titleTextColor,
                  ),
                ),
                if (isWarning) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: LightColor.caution.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Low funds',
                      style: GoogleFonts.mulish(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: LightColor.caution,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconPlaceholder() {
    return Center(
      child: Icon(
        icon ?? Icons.subscriptions_rounded,
        color: LightColor.accent,
        size: 24,
      ),
    );
  }

  String _getDateLabel(bool isToday, bool isTomorrow, int daysUntil) {
    if (isToday) return 'Today';
    if (isTomorrow) return 'Tomorrow';
    return DateFormatter.formatShort(dueDate);
  }
}
