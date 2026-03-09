import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:money_guardian/core/di/injection.dart';
import 'package:money_guardian/core/error/exceptions.dart';
import 'package:money_guardian/core/services/analytics_service.dart';
import 'package:money_guardian/data/models/bank_connection_model.dart';
import 'package:money_guardian/data/repositories/banking_repository.dart';
import 'package:money_guardian/presentation/blocs/banking/banking_bloc.dart';
import 'package:money_guardian/presentation/blocs/banking/banking_event.dart';
import 'package:money_guardian/presentation/blocs/banking/banking_state.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────

class MockBankingRepository extends Mock implements BankingRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class FakeConvertRecurringToSubscriptionRequest extends Fake
    implements ConvertRecurringToSubscriptionRequest {}

// ── Test Data ──────────────────────────────────────────────────────────────

final DateTime _now = DateTime(2026, 3, 8);

final BankAccountModel _testAccount = BankAccountModel(
  id: 'acct-001',
  name: 'Checking',
  accountType: BankAccountType.checking,
  currentBalance: 2500.00,
  availableBalance: 2400.00,
  currency: 'USD',
  isActive: true,
  isPrimary: true,
  includeInPulse: true,
);

final BankConnectionModel _testConnection = BankConnectionModel(
  id: 'conn-001',
  provider: BankingProvider.plaid,
  institutionName: 'Chase Bank',
  status: BankConnectionStatus.connected,
  accounts: [_testAccount],
  createdAt: _now,
  updatedAt: _now,
);

final BankConnectionListResponse _testListResponse = BankConnectionListResponse(
  connections: [_testConnection],
  totalBalance: 2400.00,
  accountCount: 1,
);

const LinkTokenResponse _testLinkToken = LinkTokenResponse(
  linkToken: 'link-sandbox-abc123',
  expiration: '2026-03-08T13:00:00Z',
  provider: 'plaid',
);

const SyncTransactionsResponse _testSyncResponse = SyncTransactionsResponse(
  newTransactions: 15,
  connectionId: 'conn-001',
);

final RecurringTransactionModel _testRecurring = RecurringTransactionModel(
  streamId: 'stream-001',
  accountId: 'acct-001',
  description: 'Netflix Subscription',
  merchantName: 'Netflix',
  averageAmount: 15.99,
  currency: 'USD',
  frequency: 'MONTHLY',
  lastDate: '2026-03-01',
  nextExpectedDate: '2026-04-01',
  isActive: true,
);

final RecurringTransactionsResponse _testRecurringResponse =
    RecurringTransactionsResponse(
  recurringTransactions: [_testRecurring],
  count: 1,
);

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  late MockBankingRepository mockBankingRepository;
  late MockAnalyticsService mockAnalyticsService;

  setUpAll(() {
    registerFallbackValue(FakeConvertRecurringToSubscriptionRequest());
  });

  setUp(() {
    mockBankingRepository = MockBankingRepository();
    mockAnalyticsService = MockAnalyticsService();

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(mockAnalyticsService);

    // Stub analytics methods
    when(() => mockAnalyticsService.logBankConnected(provider: any(named: 'provider')))
        .thenAnswer((_) async {});
    when(() => mockAnalyticsService.logBankDisconnected())
        .thenAnswer((_) async {});
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  group('BankingBloc', () {
    // ── Load Connections ────────────────────────────────────────────────

    blocTest<BankingBloc, BankingState>(
      'emits [BankingLoading, BankingLoaded] on successful load',
      build: () {
        when(() => mockBankingRepository.getBankConnections())
            .thenAnswer((_) async => _testListResponse);
        return BankingBloc(mockBankingRepository);
      },
      act: (bloc) => bloc.add(const BankingLoadRequested()),
      expect: () => [
        const BankingLoading(),
        BankingLoaded(
          connections: [_testConnection],
          totalBalance: 2400.00,
          accountCount: 1,
        ),
      ],
      verify: (_) {
        verify(() => mockBankingRepository.getBankConnections()).called(1);
      },
    );

    blocTest<BankingBloc, BankingState>(
      'emits [BankingLoading, BankingError] on load failure',
      build: () {
        when(() => mockBankingRepository.getBankConnections())
            .thenThrow(const ServerException(
          message: 'Internal server error',
          statusCode: 500,
        ));
        return BankingBloc(mockBankingRepository);
      },
      act: (bloc) => bloc.add(const BankingLoadRequested()),
      expect: () => [
        const BankingLoading(),
        const BankingError(message: 'Something went wrong. Please try again.'),
      ],
    );

    blocTest<BankingBloc, BankingState>(
      'emits [BankingLoading, BankingProRequired] on TierLimitException',
      build: () {
        when(() => mockBankingRepository.getBankConnections())
            .thenThrow(const TierLimitException(
          message: 'Upgrade to Pro',
          currentCount: 0,
          limit: 0,
          upgradeRequired: true,
        ));
        return BankingBloc(mockBankingRepository);
      },
      act: (bloc) => bloc.add(const BankingLoadRequested()),
      expect: () => [
        const BankingLoading(),
        const BankingProRequired(
          feature: 'Bank connection',
          currentTier: 'free',
        ),
      ],
    );

    blocTest<BankingBloc, BankingState>(
      'emits [BankingLoading, BankingError] on NetworkException',
      build: () {
        when(() => mockBankingRepository.getBankConnections())
            .thenThrow(const NetworkException());
        return BankingBloc(mockBankingRepository);
      },
      act: (bloc) => bloc.add(const BankingLoadRequested()),
      expect: () => [
        const BankingLoading(),
        const BankingError(
          message: 'Check your internet connection and try again.',
        ),
      ],
    );

    // ── Create Link Token ──────────────────────────────────────────────

    blocTest<BankingBloc, BankingState>(
      'emits [BankingOperationInProgress, BankingLinkTokenReady] on link token creation',
      build: () {
        when(() => mockBankingRepository.createLinkToken(
              provider: any(named: 'provider'),
            )).thenAnswer((_) async => _testLinkToken);
        return BankingBloc(mockBankingRepository);
      },
      act: (bloc) =>
          bloc.add(const BankingCreateLinkTokenRequested(provider: BankingProvider.plaid)),
      expect: () => [
        const BankingOperationInProgress(
          message: 'Preparing bank connection...',
        ),
        const BankingLinkTokenReady(linkToken: _testLinkToken),
      ],
    );

    blocTest<BankingBloc, BankingState>(
      'emits [BankingOperationInProgress, BankingError] on link token failure',
      build: () {
        when(() => mockBankingRepository.createLinkToken(
              provider: any(named: 'provider'),
            )).thenThrow(const ServerException(
          message: 'Failed',
          statusCode: 500,
        ));
        return BankingBloc(mockBankingRepository);
      },
      act: (bloc) => bloc.add(const BankingCreateLinkTokenRequested()),
      expect: () => [
        const BankingOperationInProgress(
          message: 'Preparing bank connection...',
        ),
        const BankingError(message: 'Something went wrong. Please try again.'),
      ],
    );

    // ── Exchange Token ─────────────────────────────────────────────────

    blocTest<BankingBloc, BankingState>(
      'emits [BankingOperationInProgress, BankingConnectionSuccess, ...] on successful exchange',
      build: () {
        when(() => mockBankingRepository.exchangePublicToken(
              publicToken: any(named: 'publicToken'),
              provider: any(named: 'provider'),
            )).thenAnswer((_) async => _testConnection);
        // After success, BankingLoadRequested is dispatched
        when(() => mockBankingRepository.getBankConnections())
            .thenAnswer((_) async => _testListResponse);
        return BankingBloc(mockBankingRepository);
      },
      act: (bloc) => bloc.add(const BankingExchangeTokenRequested(
        publicToken: 'public-token-xyz',
        provider: BankingProvider.plaid,
      )),
      expect: () => [
        const BankingOperationInProgress(
          message: 'Connecting bank account...',
        ),
        BankingConnectionSuccess(connection: _testConnection),
        // Followed by reload
        const BankingLoading(),
        BankingLoaded(
          connections: [_testConnection],
          totalBalance: 2400.00,
          accountCount: 1,
        ),
      ],
      verify: (_) {
        verify(() => mockAnalyticsService.logBankConnected(provider: 'plaid'))
            .called(1);
      },
    );

    blocTest<BankingBloc, BankingState>(
      'emits [BankingOperationInProgress, BankingError] on exchange failure',
      build: () {
        when(() => mockBankingRepository.exchangePublicToken(
              publicToken: any(named: 'publicToken'),
              provider: any(named: 'provider'),
            )).thenThrow(const ServerException(
          message: 'Exchange failed',
          statusCode: 400,
        ));
        return BankingBloc(mockBankingRepository);
      },
      act: (bloc) => bloc.add(const BankingExchangeTokenRequested(
        publicToken: 'bad-token',
      )),
      expect: () => [
        const BankingOperationInProgress(
          message: 'Connecting bank account...',
        ),
        const BankingError(message: 'Something went wrong. Please try again.'),
      ],
    );

    // ── Disconnect ─────────────────────────────────────────────────────

    blocTest<BankingBloc, BankingState>(
      'emits [BankingOperationInProgress, BankingLoading, BankingLoaded] on successful disconnect',
      build: () {
        when(() => mockBankingRepository.disconnectBank(any()))
            .thenAnswer((_) async {});
        when(() => mockBankingRepository.getBankConnections())
            .thenAnswer((_) async => const BankConnectionListResponse(
                  connections: [],
                  totalBalance: 0.0,
                  accountCount: 0,
                ));
        return BankingBloc(mockBankingRepository);
      },
      act: (bloc) =>
          bloc.add(const BankingDisconnectRequested(connectionId: 'conn-001')),
      expect: () => [
        const BankingOperationInProgress(message: 'Disconnecting bank...'),
        const BankingLoading(),
        const BankingLoaded(
          connections: [],
          totalBalance: 0.0,
          accountCount: 0,
        ),
      ],
      verify: (_) {
        verify(() => mockBankingRepository.disconnectBank('conn-001')).called(1);
        verify(() => mockAnalyticsService.logBankDisconnected()).called(1);
      },
    );

    blocTest<BankingBloc, BankingState>(
      'emits [BankingOperationInProgress, BankingError] on disconnect failure',
      build: () {
        when(() => mockBankingRepository.disconnectBank(any()))
            .thenThrow(const NetworkException());
        return BankingBloc(mockBankingRepository);
      },
      act: (bloc) =>
          bloc.add(const BankingDisconnectRequested(connectionId: 'conn-001')),
      expect: () => [
        const BankingOperationInProgress(message: 'Disconnecting bank...'),
        const BankingError(
          message: 'Check your internet connection and try again.',
        ),
      ],
    );

    // ── Sync Transactions ──────────────────────────────────────────────

    blocTest<BankingBloc, BankingState>(
      'emits [BankingOperationInProgress, BankingSyncComplete, ...] on sync success',
      build: () {
        when(() => mockBankingRepository.syncTransactions(any()))
            .thenAnswer((_) async => _testSyncResponse);
        when(() => mockBankingRepository.getBankConnections())
            .thenAnswer((_) async => _testListResponse);
        return BankingBloc(mockBankingRepository);
      },
      act: (bloc) => bloc.add(
        const BankingSyncTransactionsRequested(connectionId: 'conn-001'),
      ),
      expect: () => [
        const BankingOperationInProgress(message: 'Syncing transactions...'),
        const BankingSyncComplete(newTransactions: 15),
        const BankingLoading(),
        BankingLoaded(
          connections: [_testConnection],
          totalBalance: 2400.00,
          accountCount: 1,
        ),
      ],
    );

    // ── Recurring Transactions ─────────────────────────────────────────

    blocTest<BankingBloc, BankingState>(
      'emits [BankingOperationInProgress, BankingRecurringLoaded] on recurring load',
      build: () {
        when(() => mockBankingRepository.getRecurringTransactions(any()))
            .thenAnswer((_) async => _testRecurringResponse);
        return BankingBloc(mockBankingRepository);
      },
      act: (bloc) => bloc.add(
        const BankingRecurringLoadRequested(connectionId: 'conn-001'),
      ),
      expect: () => [
        const BankingOperationInProgress(
          message: 'Loading recurring transactions...',
        ),
        BankingRecurringLoaded(
          connectionId: 'conn-001',
          recurringTransactions: [_testRecurring],
          count: 1,
        ),
      ],
    );

    // ── Clear Error ────────────────────────────────────────────────────

    blocTest<BankingBloc, BankingState>(
      'emits [BankingLoading, BankingLoaded] on clear error with no previous state',
      build: () {
        when(() => mockBankingRepository.getBankConnections())
            .thenAnswer((_) async => _testListResponse);
        return BankingBloc(mockBankingRepository);
      },
      seed: () => const BankingError(message: 'some error'),
      act: (bloc) => bloc.add(const BankingClearError()),
      expect: () => [
        const BankingLoading(),
        BankingLoaded(
          connections: [_testConnection],
          totalBalance: 2400.00,
          accountCount: 1,
        ),
      ],
    );
  });
}
