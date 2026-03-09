import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:money_guardian/core/di/injection.dart';
import 'package:money_guardian/data/repositories/auth_repository.dart';
import 'package:money_guardian/src/pages/export_data_page.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────

class MockAuthRepository extends Mock implements AuthRepository {}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();

    // Register mock in GetIt (ExportDataPage resolves via getIt)
    if (getIt.isRegistered<AuthRepository>()) {
      getIt.unregister<AuthRepository>();
    }
    getIt.registerSingleton<AuthRepository>(mockAuthRepository);
  });

  tearDown(() {
    if (getIt.isRegistered<AuthRepository>()) {
      getIt.unregister<AuthRepository>();
    }
  });

  Widget buildTestWidget() {
    return const MaterialApp(
      home: ExportDataPage(),
    );
  }

  group('ExportDataPage', () {
    testWidgets('renders Export My Data title', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Export My Data'), findsWidgets);
    });

    testWidgets('renders GDPR info text', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
        find.text(
          'Under GDPR Article 20, you have the right to receive a copy of your personal data in a portable format.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders info icon', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });

    testWidgets('renders "What\'s included" header', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text("What's included"), findsOneWidget);
    });

    testWidgets('renders all included data items', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Profile information'), findsOneWidget);
      expect(find.text('All subscriptions'), findsOneWidget);
      expect(find.text('Alert history'), findsOneWidget);
      expect(find.text('Bank connection metadata'), findsOneWidget);
      expect(find.text('Email connection metadata'), findsOneWidget);
    });

    testWidgets('renders sensitive tokens disclaimer', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
        find.text(
          'Sensitive tokens (bank access, OAuth) are never included.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders export button in initial state', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // "Export My Data" appears both as title and button label
      final exportButtons = find.widgetWithText(ElevatedButton, 'Export My Data');
      expect(exportButtons, findsOneWidget);
    });

    testWidgets('shows loading indicator when exporting', (tester) async {
      // Make the export hang so we can observe the loading state
      when(() => mockAuthRepository.exportUserData())
          .thenAnswer((_) => Future.delayed(const Duration(seconds: 30)));

      await tester.pumpWidget(buildTestWidget());

      // Tap the export button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Export My Data'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows success state after export completes', (tester) async {
      final Map<String, dynamic> testExportData = {
        'exported_at': '2026-03-08T12:00:00Z',
        'user': {'id': 'user-001', 'email': 'test@example.com'},
        'subscriptions': <Map<String, dynamic>>[],
        'alerts': <Map<String, dynamic>>[],
      };

      when(() => mockAuthRepository.exportUserData())
          .thenAnswer((_) async => testExportData);

      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.widgetWithText(ElevatedButton, 'Export My Data'));
      await tester.pumpAndSettle();

      expect(find.text('Data exported successfully'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('shows Copy to Clipboard button after export', (tester) async {
      final Map<String, dynamic> testExportData = {
        'exported_at': '2026-03-08T12:00:00Z',
        'user': {'id': 'user-001'},
      };

      when(() => mockAuthRepository.exportUserData())
          .thenAnswer((_) async => testExportData);

      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.widgetWithText(ElevatedButton, 'Export My Data'));
      await tester.pumpAndSettle();

      expect(find.text('Copy to Clipboard'), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });

    testWidgets('shows error message on export failure', (tester) async {
      when(() => mockAuthRepository.exportUserData())
          .thenThrow(Exception('Server error'));

      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.widgetWithText(ElevatedButton, 'Export My Data'));
      await tester.pumpAndSettle();

      expect(
        find.text('Failed to export data. Please try again.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders back button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });
  });
}
