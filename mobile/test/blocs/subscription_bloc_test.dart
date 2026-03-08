import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:money_guardian/core/di/injection.dart';
import 'package:money_guardian/core/error/exceptions.dart';
import 'package:money_guardian/core/services/analytics_service.dart';
import 'package:money_guardian/data/models/subscription_model.dart';
import 'package:money_guardian/data/repositories/subscription_repository.dart';
import 'package:money_guardian/presentation/blocs/subscriptions/subscription_bloc.dart';
import 'package:money_guardian/presentation/blocs/subscriptions/subscription_event.dart';
import 'package:money_guardian/presentation/blocs/subscriptions/subscription_state.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────

class MockSubscriptionRepository extends Mock
    implements SubscriptionRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class FakeSubscriptionCreateRequest extends Fake
    implements SubscriptionCreateRequest {}

class FakeSubscriptionUpdateRequest extends Fake
    implements SubscriptionUpdateRequest {}

// ── Test Data ──────────────────────────────────────────────────────────────

final DateTime _now = DateTime(2026, 3, 8);

final SubscriptionModel _netflixSub = SubscriptionModel(
  id: 'sub-001',
  tenantId: 'tenant-001',
  userId: 'user-001',
  name: 'Netflix',
  amount: 15.99,
  currency: 'USD',
  billingCycle: BillingCycle.monthly,
  nextBillingDate: DateTime(2026, 3, 15),
  isActive: true,
  isPaused: false,
  aiFlag: AIFlag.none,
  source: SubscriptionSource.manual,
  createdAt: _now,
  updatedAt: _now,
);

final SubscriptionModel _spotifySub = SubscriptionModel(
  id: 'sub-002',
  tenantId: 'tenant-001',
  userId: 'user-001',
  name: 'Spotify',
  amount: 9.99,
  currency: 'USD',
  billingCycle: BillingCycle.monthly,
  nextBillingDate: DateTime(2026, 3, 20),
  isActive: true,
  isPaused: false,
  aiFlag: AIFlag.unused,
  aiFlagReason: 'No usage detected in 60 days',
  source: SubscriptionSource.plaid,
  createdAt: _now,
  updatedAt: _now,
);

final SubscriptionListResponse _testListResponse = SubscriptionListResponse(
  subscriptions: [_netflixSub, _spotifySub],
  totalCount: 2,
  monthlyTotal: 25.98,
  yearlyTotal: 311.76,
  flaggedCount: 1,
);

final SubscriptionCreateRequest _createRequest = SubscriptionCreateRequest(
  name: 'Disney+',
  amount: 13.99,
  billingCycle: BillingCycle.monthly,
  nextBillingDate: DateTime(2026, 4, 1),
);

final SubscriptionModel _createdSub = SubscriptionModel(
  id: 'sub-003',
  tenantId: 'tenant-001',
  userId: 'user-001',
  name: 'Disney+',
  amount: 13.99,
  currency: 'USD',
  billingCycle: BillingCycle.monthly,
  nextBillingDate: DateTime(2026, 4, 1),
  isActive: true,
  isPaused: false,
  aiFlag: AIFlag.none,
  source: SubscriptionSource.manual,
  createdAt: _now,
  updatedAt: _now,
);

// Response after creation (includes new sub)
final SubscriptionListResponse _updatedListResponse = SubscriptionListResponse(
  subscriptions: [_netflixSub, _spotifySub, _createdSub],
  totalCount: 3,
  monthlyTotal: 39.97,
  yearlyTotal: 479.64,
  flaggedCount: 1,
);

// Response after deletion (one sub removed)
final SubscriptionListResponse _afterDeleteResponse = SubscriptionListResponse(
  subscriptions: [_spotifySub],
  totalCount: 1,
  monthlyTotal: 9.99,
  yearlyTotal: 119.88,
  flaggedCount: 1,
);

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  late MockSubscriptionRepository mockSubscriptionRepository;
  late MockAnalyticsService mockAnalyticsService;

  setUpAll(() {
    registerFallbackValue(FakeSubscriptionCreateRequest());
    registerFallbackValue(FakeSubscriptionUpdateRequest());
  });

  setUp(() {
    mockSubscriptionRepository = MockSubscriptionRepository();
    mockAnalyticsService = MockAnalyticsService();

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(mockAnalyticsService);

    // Stub all analytics methods used by SubscriptionBloc
    when(() => mockAnalyticsService.logSubscriptionAdded(
          merchantName: any(named: 'merchantName'),
          amount: any(named: 'amount'),
          billingCycle: any(named: 'billingCycle'),
        )).thenAnswer((_) async {});
    when(() => mockAnalyticsService.logSubscriptionDeleted(
          subscriptionId: any(named: 'subscriptionId'),
        )).thenAnswer((_) async {});
    when(() => mockAnalyticsService.logSubscriptionPaused(
          subscriptionId: any(named: 'subscriptionId'),
        )).thenAnswer((_) async {});
    when(() => mockAnalyticsService.logSubscriptionResumed(
          subscriptionId: any(named: 'subscriptionId'),
        )).thenAnswer((_) async {});
    when(() => mockAnalyticsService.logSubscriptionCancelled(
          subscriptionId: any(named: 'subscriptionId'),
        )).thenAnswer((_) async {});
    when(() => mockAnalyticsService.logSubscriptionAnalyzed(
          flaggedCount: any(named: 'flaggedCount'),
        )).thenAnswer((_) async {});
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  group('SubscriptionBloc', () {
    // ── Load Subscriptions ──────────────────────────────────────────────

    blocTest<SubscriptionBloc, SubscriptionState>(
      'emits [SubscriptionLoading, SubscriptionLoaded] on successful load',
      build: () {
        when(() => mockSubscriptionRepository.getSubscriptions(
              isActive: any(named: 'isActive'),
              aiFlag: any(named: 'aiFlag'),
            )).thenAnswer((_) async => _testListResponse);
        return SubscriptionBloc(mockSubscriptionRepository);
      },
      act: (bloc) => bloc.add(const SubscriptionLoadRequested()),
      expect: () => [
        const SubscriptionLoading(),
        SubscriptionLoaded(
          subscriptions: [_netflixSub, _spotifySub],
          totalCount: 2,
          monthlyTotal: 25.98,
          yearlyTotal: 311.76,
          flaggedCount: 1,
        ),
      ],
      verify: (_) {
        verify(() => mockSubscriptionRepository.getSubscriptions(
              isActive: null,
              aiFlag: null,
            )).called(1);
      },
    );

    blocTest<SubscriptionBloc, SubscriptionState>(
      'emits [SubscriptionLoading, SubscriptionError] on load failure',
      build: () {
        when(() => mockSubscriptionRepository.getSubscriptions(
              isActive: any(named: 'isActive'),
              aiFlag: any(named: 'aiFlag'),
            )).thenThrow(const NetworkException());
        return SubscriptionBloc(mockSubscriptionRepository);
      },
      act: (bloc) => bloc.add(const SubscriptionLoadRequested()),
      expect: () => [
        const SubscriptionLoading(),
        const SubscriptionError(
          message: 'Check your internet connection and try again.',
        ),
      ],
    );

    blocTest<SubscriptionBloc, SubscriptionState>(
      'emits [SubscriptionLoading, SubscriptionError] on ServerException',
      build: () {
        when(() => mockSubscriptionRepository.getSubscriptions(
              isActive: any(named: 'isActive'),
              aiFlag: any(named: 'aiFlag'),
            )).thenThrow(const ServerException(
          message: 'Internal server error',
          statusCode: 500,
        ));
        return SubscriptionBloc(mockSubscriptionRepository);
      },
      act: (bloc) => bloc.add(const SubscriptionLoadRequested()),
      expect: () => [
        const SubscriptionLoading(),
        const SubscriptionError(
          message: 'Something went wrong. Please try again.',
        ),
      ],
    );

    // ── Create Subscription ─────────────────────────────────────────────

    blocTest<SubscriptionBloc, SubscriptionState>(
      'creates subscription and reloads list on success',
      build: () {
        when(() => mockSubscriptionRepository.createSubscription(any()))
            .thenAnswer((_) async => _createdSub);
        // The BLoC dispatches SubscriptionLoadRequested after create
        when(() => mockSubscriptionRepository.getSubscriptions(
              isActive: any(named: 'isActive'),
              aiFlag: any(named: 'aiFlag'),
            )).thenAnswer((_) async => _updatedListResponse);
        return SubscriptionBloc(mockSubscriptionRepository);
      },
      seed: () => SubscriptionLoaded(
        subscriptions: [_netflixSub, _spotifySub],
        totalCount: 2,
        monthlyTotal: 25.98,
        yearlyTotal: 311.76,
        flaggedCount: 1,
      ),
      act: (bloc) => bloc.add(
        SubscriptionCreateRequested(request: _createRequest),
      ),
      expect: () => [
        // Shows operation in progress with previous state
        isA<SubscriptionOperationInProgress>(),
        // Then reloads - emits Loading and Loaded from the internal add()
        const SubscriptionLoading(),
        SubscriptionLoaded(
          subscriptions: [_netflixSub, _spotifySub, _createdSub],
          totalCount: 3,
          monthlyTotal: 39.97,
          yearlyTotal: 479.64,
          flaggedCount: 1,
        ),
      ],
      verify: (_) {
        verify(() => mockSubscriptionRepository.createSubscription(any()))
            .called(1);
        verify(() => mockAnalyticsService.logSubscriptionAdded(
              merchantName: 'Disney+',
              amount: 13.99,
              billingCycle: 'monthly',
            )).called(1);
      },
    );

    // ── Delete Subscription ─────────────────────────────────────────────

    blocTest<SubscriptionBloc, SubscriptionState>(
      'deletes subscription and reloads list on success',
      build: () {
        when(() => mockSubscriptionRepository.deleteSubscription(any()))
            .thenAnswer((_) async {});
        when(() => mockSubscriptionRepository.getSubscriptions(
              isActive: any(named: 'isActive'),
              aiFlag: any(named: 'aiFlag'),
            )).thenAnswer((_) async => _afterDeleteResponse);
        return SubscriptionBloc(mockSubscriptionRepository);
      },
      seed: () => SubscriptionLoaded(
        subscriptions: [_netflixSub, _spotifySub],
        totalCount: 2,
        monthlyTotal: 25.98,
        yearlyTotal: 311.76,
        flaggedCount: 1,
      ),
      act: (bloc) => bloc.add(
        const SubscriptionDeleteRequested(subscriptionId: 'sub-001'),
      ),
      expect: () => [
        isA<SubscriptionOperationInProgress>(),
        const SubscriptionLoading(),
        SubscriptionLoaded(
          subscriptions: [_spotifySub],
          totalCount: 1,
          monthlyTotal: 9.99,
          yearlyTotal: 119.88,
          flaggedCount: 1,
        ),
      ],
      verify: (_) {
        verify(() =>
            mockSubscriptionRepository.deleteSubscription('sub-001')).called(1);
        verify(() => mockAnalyticsService.logSubscriptionDeleted(
              subscriptionId: 'sub-001',
            )).called(1);
      },
    );

    // ── Pro Limit Reached ───────────────────────────────────────────────

    blocTest<SubscriptionBloc, SubscriptionState>(
      'emits SubscriptionProRequired when TierLimitException is thrown',
      build: () {
        when(() => mockSubscriptionRepository.createSubscription(any()))
            .thenThrow(const TierLimitException(
          message: 'Free tier limit reached. Upgrade to Pro.',
          currentCount: 5,
          limit: 5,
          upgradeRequired: true,
        ));
        return SubscriptionBloc(mockSubscriptionRepository);
      },
      seed: () => SubscriptionLoaded(
        subscriptions: [_netflixSub, _spotifySub],
        totalCount: 2,
        monthlyTotal: 25.98,
        yearlyTotal: 311.76,
        flaggedCount: 1,
      ),
      act: (bloc) => bloc.add(
        SubscriptionCreateRequested(request: _createRequest),
      ),
      expect: () => [
        isA<SubscriptionOperationInProgress>(),
        const SubscriptionProRequired(
          currentCount: 5,
          maxAllowed: 5,
          message: 'Free tier limit reached. Upgrade to Pro.',
        ),
        // Restores previous loaded state
        SubscriptionLoaded(
          subscriptions: [_netflixSub, _spotifySub],
          totalCount: 2,
          monthlyTotal: 25.98,
          yearlyTotal: 311.76,
          flaggedCount: 1,
        ),
      ],
    );

    // ── Create Failure (non-tier) ───────────────────────────────────────

    blocTest<SubscriptionBloc, SubscriptionState>(
      'emits SubscriptionError on create failure and restores previous state',
      build: () {
        when(() => mockSubscriptionRepository.createSubscription(any()))
            .thenThrow(const ServerException(
          message: 'Validation error',
          statusCode: 422,
        ));
        return SubscriptionBloc(mockSubscriptionRepository);
      },
      seed: () => SubscriptionLoaded(
        subscriptions: [_netflixSub],
        totalCount: 1,
        monthlyTotal: 15.99,
        yearlyTotal: 191.88,
        flaggedCount: 0,
      ),
      act: (bloc) => bloc.add(
        SubscriptionCreateRequested(request: _createRequest),
      ),
      expect: () => [
        isA<SubscriptionOperationInProgress>(),
        const SubscriptionError(
          message: 'Something went wrong. Please try again.',
        ),
        // Restores previous loaded state
        SubscriptionLoaded(
          subscriptions: [_netflixSub],
          totalCount: 1,
          monthlyTotal: 15.99,
          yearlyTotal: 191.88,
          flaggedCount: 0,
        ),
      ],
    );

    // ── Load with filters ───────────────────────────────────────────────

    blocTest<SubscriptionBloc, SubscriptionState>(
      'passes filter parameters to repository',
      build: () {
        when(() => mockSubscriptionRepository.getSubscriptions(
              isActive: any(named: 'isActive'),
              aiFlag: any(named: 'aiFlag'),
            )).thenAnswer((_) async => _testListResponse);
        return SubscriptionBloc(mockSubscriptionRepository);
      },
      act: (bloc) => bloc.add(
        const SubscriptionLoadRequested(isActive: true, aiFlag: 'unused'),
      ),
      expect: () => [
        const SubscriptionLoading(),
        isA<SubscriptionLoaded>(),
      ],
      verify: (_) {
        verify(() => mockSubscriptionRepository.getSubscriptions(
              isActive: true,
              aiFlag: 'unused',
            )).called(1);
      },
    );
  });
}
