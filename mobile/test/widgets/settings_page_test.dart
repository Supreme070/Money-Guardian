import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:money_guardian/core/di/injection.dart';
import 'package:money_guardian/core/services/analytics_service.dart';
import 'package:money_guardian/data/models/user_model.dart';
import 'package:money_guardian/presentation/blocs/auth/auth_bloc.dart';
import 'package:money_guardian/presentation/blocs/auth/auth_state.dart';
import 'package:money_guardian/presentation/blocs/banking/banking_bloc.dart';
import 'package:money_guardian/presentation/blocs/banking/banking_state.dart';
import 'package:money_guardian/presentation/blocs/email_scanning/email_scanning_bloc.dart';
import 'package:money_guardian/presentation/blocs/email_scanning/email_scanning_state.dart';
import 'package:money_guardian/presentation/pages/settings/settings_page.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────

class MockAuthBloc extends Mock implements AuthBloc {}

class MockBankingBloc extends Mock implements BankingBloc {}

class MockEmailScanningBloc extends Mock implements EmailScanningBloc {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

// ── Test Data ──────────────────────────────────────────────────────────────

final DateTime _now = DateTime(2026, 3, 8);

final UserModel _testUser = UserModel(
  id: 'user-001',
  tenantId: 'tenant-001',
  email: 'guardian@example.com',
  fullName: 'Test Guardian',
  isActive: true,
  isVerified: true,
  pushNotificationsEnabled: true,
  emailNotificationsEnabled: true,
  subscriptionTier: SubscriptionTier.free,
  onboardingCompleted: true,
  createdAt: _now,
  updatedAt: _now,
);

final UserModel _proUser = UserModel(
  id: 'user-002',
  tenantId: 'tenant-001',
  email: 'pro@example.com',
  fullName: 'Pro Guardian',
  isActive: true,
  isVerified: true,
  pushNotificationsEnabled: true,
  emailNotificationsEnabled: true,
  subscriptionTier: SubscriptionTier.pro,
  onboardingCompleted: true,
  createdAt: _now,
  updatedAt: _now,
);

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  late MockAuthBloc mockAuthBloc;
  late MockBankingBloc mockBankingBloc;
  late MockEmailScanningBloc mockEmailScanningBloc;
  late MockAnalyticsService mockAnalyticsService;

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    mockBankingBloc = MockBankingBloc();
    mockEmailScanningBloc = MockEmailScanningBloc();
    mockAnalyticsService = MockAnalyticsService();

    // Register analytics service in GetIt (SettingsPage calls it in initState)
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(mockAnalyticsService);

    // Stub analytics
    when(() => mockAnalyticsService.logScreenView(
          screenName: any(named: 'screenName'),
          screenClass: any(named: 'screenClass'),
        )).thenAnswer((_) async {});

    // Stub BLoC streams
    when(() => mockAuthBloc.stream)
        .thenAnswer((_) => const Stream<AuthState>.empty());
    when(() => mockBankingBloc.stream)
        .thenAnswer((_) => const Stream<BankingState>.empty());
    when(() => mockEmailScanningBloc.stream)
        .thenAnswer((_) => const Stream<EmailScanningState>.empty());

    // Stub close methods
    when(() => mockAuthBloc.close()).thenAnswer((_) async {});
    when(() => mockBankingBloc.close()).thenAnswer((_) async {});
    when(() => mockEmailScanningBloc.close()).thenAnswer((_) async {});
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  Widget buildTestWidget({AuthState? authState}) {
    when(() => mockAuthBloc.state)
        .thenReturn(authState ?? AuthAuthenticated(user: _testUser));
    when(() => mockBankingBloc.state).thenReturn(const BankingInitial());
    when(() => mockEmailScanningBloc.state)
        .thenReturn(const EmailScanningInitial());

    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: mockAuthBloc),
          BlocProvider<BankingBloc>.value(value: mockBankingBloc),
          BlocProvider<EmailScanningBloc>.value(value: mockEmailScanningBloc),
        ],
        child: const SettingsPage(),
      ),
    );
  }

  group('SettingsPage', () {
    testWidgets('renders Settings title in app bar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders profile hero with user full name', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Test Guardian'), findsOneWidget);
    });

    testWidgets('renders profile hero with user email', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('guardian@example.com'), findsOneWidget);
    });

    testWidgets('renders user initial in avatar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('renders FREE PLAN badge for free user', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('FREE PLAN'), findsOneWidget);
    });

    testWidgets('renders PRO PLAN badge for pro user', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(authState: AuthAuthenticated(user: _proUser)),
      );
      await tester.pump();

      expect(find.text('PRO PLAN'), findsOneWidget);
    });

    testWidgets('renders Connections section header', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Connections'), findsOneWidget);
    });

    testWidgets('renders Bank Connections tile', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Bank Connections'), findsOneWidget);
    });

    testWidgets('renders Email Scanning tile', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Email Scanning'), findsOneWidget);
    });

    testWidgets('renders Account & Security section', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Account & Security'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Billing'), findsOneWidget);
    });

    testWidgets('renders Data & Privacy section', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Data & Privacy'), findsOneWidget);
      expect(find.text('Export My Data'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
    });

    testWidgets('renders Support section', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Support'), findsOneWidget);
      expect(find.text('Help Center'), findsOneWidget);
      expect(find.text('Contact Us'), findsOneWidget);
    });

    testWidgets('renders Sign Out button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('renders app version text', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Money Guardian v1.0.0'), findsOneWidget);
    });

    testWidgets('shows logout confirmation dialog on sign out tap',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      expect(find.text('Sign Out?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('renders skeleton when not authenticated', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(authState: const AuthLoading()),
      );
      await tester.pump();

      expect(find.text('Loading User'), findsOneWidget);
    });
  });
}
