import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:money_guardian/core/di/injection.dart';
import 'package:money_guardian/core/error/exceptions.dart';
import 'package:money_guardian/core/services/analytics_service.dart';
import 'package:money_guardian/data/models/alert_model.dart';
import 'package:money_guardian/data/repositories/alert_repository.dart';
import 'package:money_guardian/presentation/blocs/alerts/alert_bloc.dart';
import 'package:money_guardian/presentation/blocs/alerts/alert_event.dart';
import 'package:money_guardian/presentation/blocs/alerts/alert_state.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────

class MockAlertRepository extends Mock implements AlertRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

// ── Test Data ──────────────────────────────────────────────────────────────

final DateTime _now = DateTime(2026, 3, 8);

final AlertModel _overdraftAlert = AlertModel(
  id: 'alert-001',
  tenantId: 'tenant-001',
  userId: 'user-001',
  alertType: AlertType.overdraftWarning,
  severity: AlertSeverity.critical,
  title: 'Overdraft Risk',
  message: 'Your balance may go below zero by March 12',
  amount: 150.00,
  alertDate: DateTime(2026, 3, 12),
  isRead: false,
  isDismissed: false,
  isActioned: false,
  createdAt: _now,
  updatedAt: _now,
);

final AlertModel _upcomingChargeAlert = AlertModel(
  id: 'alert-002',
  tenantId: 'tenant-001',
  userId: 'user-001',
  subscriptionId: 'sub-001',
  alertType: AlertType.upcomingCharge,
  severity: AlertSeverity.info,
  title: 'Netflix Renewal',
  message: 'Netflix \$15.99 renews on March 15',
  amount: 15.99,
  alertDate: DateTime(2026, 3, 15),
  isRead: false,
  isDismissed: false,
  isActioned: false,
  createdAt: _now,
  updatedAt: _now,
);

final AlertModel _priceIncreaseAlert = AlertModel(
  id: 'alert-003',
  tenantId: 'tenant-001',
  userId: 'user-001',
  subscriptionId: 'sub-002',
  alertType: AlertType.priceIncrease,
  severity: AlertSeverity.warning,
  title: 'Spotify Price Increase',
  message: 'Spotify increased from \$9.99 to \$11.99',
  amount: 11.99,
  isRead: true,
  isDismissed: false,
  isActioned: false,
  createdAt: _now,
  updatedAt: _now,
);

final AlertListResponse _testAlertListResponse = AlertListResponse(
  alerts: [_overdraftAlert, _upcomingChargeAlert, _priceIncreaseAlert],
  totalCount: 3,
  unreadCount: 2,
  criticalCount: 1,
);

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  late MockAlertRepository mockAlertRepository;
  late MockAnalyticsService mockAnalyticsService;

  setUp(() {
    mockAlertRepository = MockAlertRepository();
    mockAnalyticsService = MockAnalyticsService();

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(mockAnalyticsService);

    when(() => mockAnalyticsService.logAlertDismissed(
          alertId: any(named: 'alertId'),
        )).thenAnswer((_) async {});
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  group('AlertBloc', () {
    // ── Load Alerts ─────────────────────────────────────────────────────

    blocTest<AlertBloc, AlertState>(
      'emits [AlertLoading, AlertLoaded] on successful load',
      build: () {
        when(() => mockAlertRepository.getAlerts(
              unreadOnly: any(named: 'unreadOnly'),
              severity: any(named: 'severity'),
            )).thenAnswer((_) async => _testAlertListResponse);
        return AlertBloc(mockAlertRepository);
      },
      act: (bloc) => bloc.add(const AlertLoadRequested()),
      expect: () => [
        const AlertLoading(),
        AlertLoaded(
          alerts: [_overdraftAlert, _upcomingChargeAlert, _priceIncreaseAlert],
          totalCount: 3,
          unreadCount: 2,
          criticalCount: 1,
        ),
      ],
      verify: (_) {
        verify(() => mockAlertRepository.getAlerts(
              unreadOnly: null,
              severity: null,
            )).called(1);
      },
    );

    blocTest<AlertBloc, AlertState>(
      'emits [AlertLoading, AlertError] on load failure',
      build: () {
        when(() => mockAlertRepository.getAlerts(
              unreadOnly: any(named: 'unreadOnly'),
              severity: any(named: 'severity'),
            )).thenThrow(const NetworkException());
        return AlertBloc(mockAlertRepository);
      },
      act: (bloc) => bloc.add(const AlertLoadRequested()),
      expect: () => [
        const AlertLoading(),
        const AlertError(
          message: 'Check your internet connection and try again.',
        ),
      ],
    );

    blocTest<AlertBloc, AlertState>(
      'emits [AlertLoading, AlertError] on ServerException',
      build: () {
        when(() => mockAlertRepository.getAlerts(
              unreadOnly: any(named: 'unreadOnly'),
              severity: any(named: 'severity'),
            )).thenThrow(const ServerException(
          message: 'Internal server error',
          statusCode: 500,
        ));
        return AlertBloc(mockAlertRepository);
      },
      act: (bloc) => bloc.add(const AlertLoadRequested()),
      expect: () => [
        const AlertLoading(),
        const AlertError(
          message: 'Something went wrong. Please try again.',
        ),
      ],
    );

    blocTest<AlertBloc, AlertState>(
      'passes filter parameters to repository',
      build: () {
        when(() => mockAlertRepository.getAlerts(
              unreadOnly: any(named: 'unreadOnly'),
              severity: any(named: 'severity'),
            )).thenAnswer((_) async => _testAlertListResponse);
        return AlertBloc(mockAlertRepository);
      },
      act: (bloc) => bloc.add(
        const AlertLoadRequested(unreadOnly: true, severity: 'critical'),
      ),
      expect: () => [
        const AlertLoading(),
        isA<AlertLoaded>(),
      ],
      verify: (_) {
        verify(() => mockAlertRepository.getAlerts(
              unreadOnly: true,
              severity: 'critical',
            )).called(1);
      },
    );

    // ── Mark Alert Read ─────────────────────────────────────────────────

    blocTest<AlertBloc, AlertState>(
      'updates local state optimistically when marking alerts as read',
      build: () {
        when(() => mockAlertRepository.markAlertsAsRead(any()))
            .thenAnswer((_) async {});
        return AlertBloc(mockAlertRepository);
      },
      seed: () => AlertLoaded(
        alerts: [_overdraftAlert, _upcomingChargeAlert, _priceIncreaseAlert],
        totalCount: 3,
        unreadCount: 2,
        criticalCount: 1,
      ),
      act: (bloc) => bloc.add(
        const AlertMarkReadRequested(alertIds: ['alert-001']),
      ),
      expect: () => [
        isA<AlertLoaded>().having(
          (state) => state.unreadCount,
          'unreadCount',
          1,
        ),
      ],
      verify: (_) {
        verify(() => mockAlertRepository.markAlertsAsRead(['alert-001']))
            .called(1);
      },
    );

    blocTest<AlertBloc, AlertState>(
      'emits error and restores state when mark read fails',
      build: () {
        when(() => mockAlertRepository.markAlertsAsRead(any()))
            .thenThrow(const ServerException(
          message: 'Server error',
          statusCode: 500,
        ));
        return AlertBloc(mockAlertRepository);
      },
      seed: () => AlertLoaded(
        alerts: [_overdraftAlert, _upcomingChargeAlert],
        totalCount: 2,
        unreadCount: 2,
        criticalCount: 1,
      ),
      act: (bloc) => bloc.add(
        const AlertMarkReadRequested(alertIds: ['alert-001']),
      ),
      expect: () => [
        const AlertError(
          message: 'Something went wrong. Please try again.',
        ),
        // Restores the previous loaded state
        AlertLoaded(
          alerts: [_overdraftAlert, _upcomingChargeAlert],
          totalCount: 2,
          unreadCount: 2,
          criticalCount: 1,
        ),
      ],
    );

    blocTest<AlertBloc, AlertState>(
      'does nothing when mark read is called from non-loaded state',
      build: () {
        return AlertBloc(mockAlertRepository);
      },
      act: (bloc) => bloc.add(
        const AlertMarkReadRequested(alertIds: ['alert-001']),
      ),
      expect: () => <AlertState>[],
      verify: (_) {
        verifyNever(() => mockAlertRepository.markAlertsAsRead(any()));
      },
    );

    // ── Dismiss Alert ───────────────────────────────────────────────────

    blocTest<AlertBloc, AlertState>(
      'removes alert from local state on successful dismiss',
      build: () {
        when(() => mockAlertRepository.dismissAlert(any()))
            .thenAnswer((_) async {});
        return AlertBloc(mockAlertRepository);
      },
      seed: () => AlertLoaded(
        alerts: [_overdraftAlert, _upcomingChargeAlert, _priceIncreaseAlert],
        totalCount: 3,
        unreadCount: 2,
        criticalCount: 1,
      ),
      act: (bloc) => bloc.add(
        const AlertDismissRequested(alertId: 'alert-001'),
      ),
      expect: () => [
        // Overdraft alert (critical, unread) is removed
        AlertLoaded(
          alerts: [_upcomingChargeAlert, _priceIncreaseAlert],
          totalCount: 2,
          unreadCount: 1, // was 2, removed an unread alert
          criticalCount: 0, // was 1, removed the critical alert
        ),
      ],
      verify: (_) {
        verify(() => mockAlertRepository.dismissAlert('alert-001')).called(1);
        verify(() => mockAnalyticsService.logAlertDismissed(
              alertId: 'alert-001',
            )).called(1);
      },
    );

    blocTest<AlertBloc, AlertState>(
      'dismissing a read alert does not decrement unreadCount',
      build: () {
        when(() => mockAlertRepository.dismissAlert(any()))
            .thenAnswer((_) async {});
        return AlertBloc(mockAlertRepository);
      },
      seed: () => AlertLoaded(
        alerts: [_overdraftAlert, _priceIncreaseAlert],
        totalCount: 2,
        unreadCount: 1,
        criticalCount: 1,
      ),
      act: (bloc) => bloc.add(
        // alert-003 is the price increase alert which is already read
        const AlertDismissRequested(alertId: 'alert-003'),
      ),
      expect: () => [
        AlertLoaded(
          alerts: [_overdraftAlert],
          totalCount: 1,
          unreadCount: 1, // unchanged because dismissed alert was already read
          criticalCount: 1, // unchanged because dismissed alert was warning, not critical
        ),
      ],
    );

    blocTest<AlertBloc, AlertState>(
      'emits error and restores state when dismiss fails',
      build: () {
        when(() => mockAlertRepository.dismissAlert(any()))
            .thenThrow(const NetworkException());
        return AlertBloc(mockAlertRepository);
      },
      seed: () => AlertLoaded(
        alerts: [_overdraftAlert, _upcomingChargeAlert],
        totalCount: 2,
        unreadCount: 2,
        criticalCount: 1,
      ),
      act: (bloc) => bloc.add(
        const AlertDismissRequested(alertId: 'alert-001'),
      ),
      expect: () => [
        const AlertError(
          message: 'Check your internet connection and try again.',
        ),
        // Restores previous state
        AlertLoaded(
          alerts: [_overdraftAlert, _upcomingChargeAlert],
          totalCount: 2,
          unreadCount: 2,
          criticalCount: 1,
        ),
      ],
    );

    blocTest<AlertBloc, AlertState>(
      'does nothing when dismiss is called from non-loaded state',
      build: () {
        return AlertBloc(mockAlertRepository);
      },
      act: (bloc) => bloc.add(
        const AlertDismissRequested(alertId: 'alert-001'),
      ),
      expect: () => <AlertState>[],
      verify: (_) {
        verifyNever(() => mockAlertRepository.dismissAlert(any()));
      },
    );
  });
}
