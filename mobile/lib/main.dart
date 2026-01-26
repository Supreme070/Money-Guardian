import 'package:flutter/material.dart';
import 'package:money_guardian/src/theme/theme.dart';
import 'package:google_fonts/google_fonts.dart';

import 'src/pages/homePage.dart';
import 'src/pages/subscriptions_page.dart';
import 'src/pages/calendar_page.dart';
import 'src/pages/alerts_page.dart';

void main() => runApp(const MoneyGuardianApp());

class MoneyGuardianApp extends StatelessWidget {
  const MoneyGuardianApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Money Guardian',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme.copyWith(
        textTheme: GoogleFonts.mulishTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      initialRoute: '/',
      routes: <String, WidgetBuilder>{
        '/': (_) => const HomePage(),
        '/subscriptions': (_) => const SubscriptionsPage(),
        '/calendar': (_) => const CalendarPage(),
        '/alerts': (_) => const AlertsPage(),
        '/settings': (_) => const _SettingsPlaceholder(),
      },
    );
  }
}

// Temporary placeholder for Settings page
class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.mulish(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff15294a),
        elevation: 0,
      ),
      body: const Center(
        child: Text('Settings page coming soon'),
      ),
    );
  }
}
