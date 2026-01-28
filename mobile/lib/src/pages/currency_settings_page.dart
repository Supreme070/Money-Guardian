import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/light_color.dart';

class CurrencySettingsPage extends StatefulWidget {
  const CurrencySettingsPage({Key? key}) : super(key: key);

  @override
  State<CurrencySettingsPage> createState() => _CurrencySettingsPageState();
}

class _CurrencySettingsPageState extends State<CurrencySettingsPage> {
  String _selectedCurrency = 'USD';

  static const List<Map<String, String>> _currencies = [
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$', 'flag': '🇺🇸'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€', 'flag': '🇪🇺'},
    {'code': 'GBP', 'name': 'British Pound', 'symbol': '£', 'flag': '🇬🇧'},
    {'code': 'NGN', 'name': 'Nigerian Naira', 'symbol': '₦', 'flag': '🇳🇬'},
    {'code': 'ZAR', 'name': 'South African Rand', 'symbol': 'R', 'flag': '🇿🇦'},
    {'code': 'KES', 'name': 'Kenyan Shilling', 'symbol': 'KSh', 'flag': '🇰🇪'},
    {'code': 'GHS', 'name': 'Ghanaian Cedi', 'symbol': '₵', 'flag': '🇬🇭'},
    {'code': 'CAD', 'name': 'Canadian Dollar', 'symbol': 'C\$', 'flag': '🇨🇦'},
    {'code': 'AUD', 'name': 'Australian Dollar', 'symbol': 'A\$', 'flag': '🇦🇺'},
    {'code': 'INR', 'name': 'Indian Rupee', 'symbol': '₹', 'flag': '🇮🇳'},
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
          'Currency',
          style: GoogleFonts.mulish(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: LightColor.titleTextColor,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Select your primary currency for displaying amounts.',
              style: GoogleFonts.mulish(
                fontSize: 13,
                color: LightColor.subTitleTextColor,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _currencies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final currency = _currencies[index];
                final isSelected = _selectedCurrency == currency['code'];

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedCurrency = currency['code']!);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Currency set to ${currency['name']}',
                            style: GoogleFonts.mulish(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: LightColor.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: LightColor.lightGrey,
                        borderRadius: BorderRadius.circular(14),
                        border: isSelected
                            ? Border.all(color: LightColor.accent, width: 2)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Text(
                            currency['flag']!,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currency['name']!,
                                  style: GoogleFonts.mulish(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: LightColor.titleTextColor,
                                  ),
                                ),
                                Text(
                                  '${currency['code']} (${currency['symbol']})',
                                  style: GoogleFonts.mulish(
                                    fontSize: 12,
                                    color: LightColor.subTitleTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: LightColor.accent,
                              size: 24,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
