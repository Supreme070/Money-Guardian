import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:money_guardian/src/widgets/pulse_status_card.dart';

void main() {
  group('PulseStatusCard', () {
    Widget buildTestWidget({
      required PulseStatus status,
      required double safeToSpend,
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: PulseStatusCard(
            status: status,
            safeToSpend: safeToSpend,
            onTap: onTap,
          ),
        ),
      );
    }

    // ── SAFE status ────────────────────────────────────────────────────

    testWidgets('renders SAFE status label and message', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        status: PulseStatus.safe,
        safeToSpend: 250.75,
      ));

      expect(find.text('SAFE'), findsOneWidget);
      expect(find.text("You're good to spend"), findsOneWidget);
    });

    testWidgets('renders safe-to-spend amount floored', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        status: PulseStatus.safe,
        safeToSpend: 250.75,
      ));

      expect(find.text('250'), findsOneWidget);
      expect(find.text('\$'), findsOneWidget);
      expect(find.text('Safe to Spend Today'), findsOneWidget);
    });

    testWidgets('renders check icon for SAFE status', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        status: PulseStatus.safe,
        safeToSpend: 100.0,
      ));

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    // ── CAUTION status ─────────────────────────────────────────────────

    testWidgets('renders CAUTION status label and message', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        status: PulseStatus.caution,
        safeToSpend: 50.0,
      ));

      expect(find.text('CAUTION'), findsOneWidget);
      expect(find.text('Be careful with spending'), findsOneWidget);
    });

    testWidgets('renders warning icon for CAUTION status', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        status: PulseStatus.caution,
        safeToSpend: 50.0,
      ));

      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    });

    // ── FREEZE status ──────────────────────────────────────────────────

    testWidgets('renders FREEZE status label and message', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        status: PulseStatus.freeze,
        safeToSpend: 0.0,
      ));

      expect(find.text('FREEZE'), findsOneWidget);
      expect(find.text('Stop non-essential spending'), findsOneWidget);
    });

    testWidgets('renders hand icon for FREEZE status', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        status: PulseStatus.freeze,
        safeToSpend: 0.0,
      ));

      expect(find.byIcon(Icons.front_hand_rounded), findsOneWidget);
    });

    // ── Edge cases ─────────────────────────────────────────────────────

    testWidgets('renders 0 when safeToSpend is zero', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        status: PulseStatus.freeze,
        safeToSpend: 0.0,
      ));

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('renders 0 when safeToSpend is negative', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        status: PulseStatus.freeze,
        safeToSpend: -50.0,
      ));

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('calls onTap callback when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(buildTestWidget(
        status: PulseStatus.safe,
        safeToSpend: 100.0,
        onTap: () => tapped = true,
      ));

      await tester.tap(find.byType(PulseStatusCard));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
