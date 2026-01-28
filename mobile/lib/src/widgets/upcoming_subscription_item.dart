import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:money_guardian/src/theme/light_color.dart';
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), // Minimal padding like List Tile
        decoration: BoxDecoration(
           color: Colors.white,
           borderRadius: BorderRadius.circular(10),
           boxShadow: [
             BoxShadow(
               color: Color(0xfff1f1f3).withOpacity(0.4),
               blurRadius: 10,
               spreadRadius: 10,
               offset: const Offset(5, 5),
             ),
           ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: LightColor.navyBlue1,
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: Icon(
              icon ?? Icons.subscriptions_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          title: Text(
            name,
            style: GoogleFonts.mulish(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: LightColor.titleTextColor,
            ),
          ),
          subtitle: Text(
            DateFormatter.formatShort(dueDate),
            style: GoogleFonts.mulish(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: LightColor.subTitleTextColor,
            ),
          ),
          trailing: Container(
             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
             decoration: BoxDecoration(
               color: LightColor.lightGrey,
               borderRadius: BorderRadius.all(Radius.circular(10)),
             ),
             child: Text(
               CurrencyFormatter.format(amount),
               style: GoogleFonts.mulish(
                 fontSize: 14,
                 fontWeight: FontWeight.w700,
                 color: LightColor.titleTextColor,
               ),
             ),
          ),
        ),
      ),
    );
  }
}
