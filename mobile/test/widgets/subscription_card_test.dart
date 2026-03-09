import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:money_guardian/src/widgets/subscription_card.dart';

void main() {
  group('SubscriptionCard', () {
    final DateTime nextBilling = DateTime(2026, 4, 15);

    Widget buildTestWidget({
      String name = 'Netflix',
      double amount = 15.99,
      String billingCycle = 'monthly',
      DateTime? nextBillingDate,
      SubscriptionFlag flag = SubscriptionFlag.none,
      bool isActive = true,
      VoidCallback? onTap,
      VoidCallback? onLongPress,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SubscriptionCard(
            name: name,
            amount: amount,
            billingCycle: billingCycle,
            nextBillingDate: nextBillingDate ?? nextBilling,
            flag: flag,
            isActive: isActive,
            onTap: onTap,
            onLongPress: onLongPress,
          ),
        ),
      );
    }

    // ── Basic rendering ────────────────────────────────────────────────

    testWidgets('renders subscription name', (tester) async {
      await tester.pumpWidget(buildTestWidget(name: 'Spotify'));
      expect(find.text('Spotify'), findsOneWidget);
    });

    testWidgets('renders formatted amount', (tester) async {
      await tester.pumpWidget(buildTestWidget(amount: 15.99));
      // CurrencyFormatter.format(15.99) => "$15.99"
      expect(find.text('\$15.99'), findsOneWidget);
    });

    testWidgets('renders large amount with commas', (tester) async {
      await tester.pumpWidget(buildTestWidget(amount: 1234.56));
      expect(find.text('\$1,234.56'), findsOneWidget);
    });

    // ── Billing cycle labels ───────────────────────────────────────────

    testWidgets('renders Monthly billing cycle label', (tester) async {
      await tester.pumpWidget(buildTestWidget(billingCycle: 'monthly'));
      expect(find.text('Monthly'), findsOneWidget);
    });

    testWidgets('renders Weekly billing cycle label', (tester) async {
      await tester.pumpWidget(buildTestWidget(billingCycle: 'weekly'));
      expect(find.text('Weekly'), findsOneWidget);
    });

    testWidgets('renders Yearly billing cycle label', (tester) async {
      await tester.pumpWidget(buildTestWidget(billingCycle: 'yearly'));
      expect(find.text('Yearly'), findsOneWidget);
    });

    testWidgets('renders Quarterly billing cycle label', (tester) async {
      await tester.pumpWidget(buildTestWidget(billingCycle: 'quarterly'));
      expect(find.text('Quarterly'), findsOneWidget);
    });

    // ── AI flag banners ────────────────────────────────────────────────

    testWidgets('does not show flag banner when flag is none', (tester) async {
      await tester.pumpWidget(buildTestWidget(flag: SubscriptionFlag.none));
      expect(find.text("Haven't used this in 30+ days"), findsNothing);
      expect(find.text('Similar to another subscription'), findsNothing);
      expect(find.text('Price increased recently'), findsNothing);
      expect(find.text('Free trial ending soon'), findsNothing);
      expect(find.text('You might have forgotten about this'), findsNothing);
    });

    testWidgets('shows unused flag banner', (tester) async {
      await tester.pumpWidget(buildTestWidget(flag: SubscriptionFlag.unused));
      expect(find.text("Haven't used this in 30+ days"), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_empty_rounded), findsOneWidget);
    });

    testWidgets('shows duplicate flag banner', (tester) async {
      await tester.pumpWidget(buildTestWidget(flag: SubscriptionFlag.duplicate));
      expect(find.text('Similar to another subscription'), findsOneWidget);
      expect(find.byIcon(Icons.content_copy_rounded), findsOneWidget);
    });

    testWidgets('shows price increase flag banner', (tester) async {
      await tester.pumpWidget(buildTestWidget(flag: SubscriptionFlag.priceIncrease));
      expect(find.text('Price increased recently'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    });

    testWidgets('shows trial ending flag banner', (tester) async {
      await tester.pumpWidget(buildTestWidget(flag: SubscriptionFlag.trialEnding));
      expect(find.text('Free trial ending soon'), findsOneWidget);
      expect(find.byIcon(Icons.timer_rounded), findsOneWidget);
    });

    testWidgets('shows forgotten flag banner', (tester) async {
      await tester.pumpWidget(buildTestWidget(flag: SubscriptionFlag.forgotten));
      expect(find.text('You might have forgotten about this'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
    });

    // ── Inactive state ─────────────────────────────────────────────────

    testWidgets('shows pause icon when inactive', (tester) async {
      await tester.pumpWidget(buildTestWidget(isActive: false));
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('does not show pause icon when active', (tester) async {
      await tester.pumpWidget(buildTestWidget(isActive: true));
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });

    // ── Tap callbacks ──────────────────────────────────────────────────

    testWidgets('calls onTap callback when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(buildTestWidget(onTap: () => tapped = true));
      await tester.tap(find.byType(SubscriptionCard));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('calls onLongPress callback on long press', (tester) async {
      bool longPressed = false;

      await tester.pumpWidget(
        buildTestWidget(onLongPress: () => longPressed = true),
      );
      await tester.longPress(find.byType(SubscriptionCard));
      await tester.pump();

      expect(longPressed, isTrue);
    });

    // ── Default icon ───────────────────────────────────────────────────

    testWidgets('renders default subscriptions icon when no logo or icon', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byIcon(Icons.subscriptions_rounded), findsOneWidget);
    });
  });
}
