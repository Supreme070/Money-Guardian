import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:money_guardian/core/di/injection.dart';
import 'package:money_guardian/core/error/exceptions.dart';
import 'package:money_guardian/core/services/analytics_service.dart';
import 'package:money_guardian/data/models/pulse_model.dart';
import 'package:money_guardian/data/repositories/pulse_repository.dart';
import 'package:money_guardian/presentation/blocs/pulse/pulse_bloc.dart';
import 'package:money_guardian/presentation/blocs/pulse/pulse_event.dart';
import 'package:money_guardian/presentation/blocs/pulse/pulse_state.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────

class MockPulseRepository extends Mock implements PulseRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

// ── Test Data ──────────────────────────────────────────────────────────────

final DateTime _now = DateTime(2026, 3, 8);

final PulseResponse _testPulse = PulseResponse(
  status: PulseStatus.safe,
  statusMessage: 'You are safe to spend today',
  safeToSpend: 1250.00,
  currentBalance: 3500.00,
  hasBankConnected: true,
  upcomingCharges: [
    UpcomingCharge(
      subscriptionId: 'sub-001',
      name: 'Netflix',
      amount: 15.99,
      date: DateTime(2026, 3, 10),
      isWarning: false,
    ),
    UpcomingCharge(
      subscriptionId: 'sub-002',
      name: 'Spotify',
      amount: 9.99,
      date: DateTime(2026, 3, 12),
      isWarning: false,
    ),
  ],
  upcomingTotal: 25.98,
  activeSubscriptionsCount: 5,
  monthlySubscriptionTotal: 89.95,
  unreadAlertsCount: 2,
  calculatedAt: _now,
  nextRefreshAt: _now.add(const Duration(hours: 6)),
);

final PulseResponse _refreshedPulse = PulseResponse(
  status: PulseStatus.caution,
  statusMessage: 'Be careful with spending today',
  safeToSpend: 450.00,
  currentBalance: 1200.00,
  hasBankConnected: true,
  upcomingCharges: [
    UpcomingCharge(
      subscriptionId: 'sub-001',
      name: 'Netflix',
      amount: 15.99,
      date: DateTime(2026, 3, 10),
      isWarning: true,
    ),
  ],
  upcomingTotal: 15.99,
  activeSubscriptionsCount: 5,
  monthlySubscriptionTotal: 89.95,
  unreadAlertsCount: 3,
  calculatedAt: _now,
  nextRefreshAt: _now.add(const Duration(hours: 6)),
);

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  late MockPulseRepository mockPulseRepository;
  late MockAnalyticsService mockAnalyticsService;

  setUp(() {
    mockPulseRepository = MockPulseRepository();
    mockAnalyticsService = MockAnalyticsService();

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(mockAnalyticsService);

    when(() => mockAnalyticsService.logPulseViewed(
          status: any(named: 'status'),
        )).thenAnswer((_) async {});
    when(() => mockAnalyticsService.logPulseRefreshed())
        .thenAnswer((_) async {});
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  group('PulseBloc', () {
    // ── PulseLoadRequested ───────────────────────────────────────────────

    blocTest<PulseBloc, PulseState>(
      'emits [PulseLoading, PulseLoaded] on successful load',
      build: () {
        when(() => mockPulseRepository.getPulse())
            .thenAnswer((_) async => _testPulse);
        return PulseBloc(mockPulseRepository);
      },
      act: (bloc) => bloc.add(const PulseLoadRequested()),
      expect: () => [
        const PulseLoading(),
        PulseLoaded(pulse: _testPulse),
      ],
      verify: (_) {
        verify(() => mockPulseRepository.getPulse()).called(1);
        verify(() => mockAnalyticsService.logPulseViewed(status: 'safe'))
            .called(1);
      },
    );

    blocTest<PulseBloc, PulseState>(
      'emits [PulseLoading, PulseError] on load failure',
      build: () {
        when(() => mockPulseRepository.getPulse())
            .thenThrow(const NetworkException());
        return PulseBloc(mockPulseRepository);
      },
      act: (bloc) => bloc.add(const PulseLoadRequested()),
      expect: () => [
        const PulseLoading(),
        const PulseError(
          message: 'Check your internet connection and try again.',
        ),
      ],
    );

    blocTest<PulseBloc, PulseState>(
      'emits [PulseLoading, PulseError] on ServerException',
      build: () {
        when(() => mockPulseRepository.getPulse())
            .thenThrow(const ServerException(
          message: 'Internal server error',
          statusCode: 500,
        ));
        return PulseBloc(mockPulseRepository);
      },
      act: (bloc) => bloc.add(const PulseLoadRequested()),
      expect: () => [
        const PulseLoading(),
        const PulseError(
          message: 'Something went wrong. Please try again.',
        ),
      ],
    );

    // ── PulseRefreshRequested ────────────────────────────────────────────

    blocTest<PulseBloc, PulseState>(
      'emits [PulseRefreshing, PulseLoaded] on successful refresh '
      'when previous state is PulseLoaded',
      build: () {
        when(() => mockPulseRepository.getPulse())
            .thenAnswer((_) async => _testPulse);
        when(() => mockPulseRepository.refreshPulse())
            .thenAnswer((_) async => _refreshedPulse);
        return PulseBloc(mockPulseRepository);
      },
      seed: () => PulseLoaded(pulse: _testPulse),
      act: (bloc) => bloc.add(const PulseRefreshRequested()),
      expect: () => [
        PulseRefreshing(previousPulse: _testPulse),
        PulseLoaded(pulse: _refreshedPulse),
      ],
      verify: (_) {
        verify(() => mockPulseRepository.refreshPulse()).called(1);
        verify(() => mockAnalyticsService.logPulseRefreshed()).called(1);
      },
    );

    blocTest<PulseBloc, PulseState>(
      'emits [PulseLoading, PulseLoaded] on refresh from initial state',
      build: () {
        when(() => mockPulseRepository.refreshPulse())
            .thenAnswer((_) async => _refreshedPulse);
        return PulseBloc(mockPulseRepository);
      },
      act: (bloc) => bloc.add(const PulseRefreshRequested()),
      expect: () => [
        const PulseLoading(),
        PulseLoaded(pulse: _refreshedPulse),
      ],
    );

    blocTest<PulseBloc, PulseState>(
      'emits [PulseRefreshing, PulseError, PulseLoaded(previous)] '
      'on refresh failure with previous data',
      build: () {
        when(() => mockPulseRepository.refreshPulse())
            .thenThrow(const ServerException(
          message: 'Server error',
          statusCode: 500,
        ));
        return PulseBloc(mockPulseRepository);
      },
      seed: () => PulseLoaded(pulse: _testPulse),
      act: (bloc) => bloc.add(const PulseRefreshRequested()),
      expect: () => [
        PulseRefreshing(previousPulse: _testPulse),
        const PulseError(
          message: 'Something went wrong. Please try again.',
        ),
        // Restores previous state on failure
        PulseLoaded(pulse: _testPulse),
      ],
    );
  });
}
