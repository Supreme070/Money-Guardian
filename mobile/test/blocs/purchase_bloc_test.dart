import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:money_guardian/core/di/injection.dart';
import 'package:money_guardian/core/services/analytics_service.dart';
import 'package:money_guardian/data/models/purchase_model.dart';
import 'package:money_guardian/data/repositories/purchase_repository.dart';
import 'package:money_guardian/presentation/blocs/purchase/purchase_bloc.dart';
import 'package:money_guardian/presentation/blocs/purchase/purchase_event.dart';
import 'package:money_guardian/presentation/blocs/purchase/purchase_state.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────

class MockPurchaseRepository extends Mock implements PurchaseRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

// ── Test Data ──────────────────────────────────────────────────────────────

final CustomerInfoModel _freeCustomerInfo = CustomerInfoModel(
  appUserId: 'user-001',
  firstSeen: DateTime(2026, 1, 1),
  entitlements: const {},
  activeSubscriptions: const [],
  allPurchasedProductIdentifiers: const [],
);

final CustomerInfoModel _proCustomerInfo = CustomerInfoModel(
  appUserId: 'user-001',
  firstSeen: DateTime(2026, 1, 1),
  entitlements: {
    'pro': EntitlementInfoModel(
      identifier: 'pro',
      isActive: true,
      expirationDate: DateTime(2027, 1, 1),
      productIdentifier: 'pro_monthly',
      willRenew: true,
      periodType: 'normal',
      latestPurchaseDate: DateTime(2026, 3, 1),
      originalPurchaseDate: DateTime(2026, 3, 1),
      isSandbox: true,
    ),
  },
  activeSubscriptions: const ['pro_monthly'],
  allPurchasedProductIdentifiers: const ['pro_monthly'],
);

const PackageOffering _monthlyPackage = PackageOffering(
  identifier: '\$rc_monthly',
  packageType: 'monthly',
  product: ProductOffering(
    identifier: 'pro_monthly',
    title: 'Pro Monthly',
    description: 'Monthly Pro subscription',
    price: 4.99,
    priceString: '\$4.99',
    currencyCode: 'USD',
    type: ProductType.subscription,
  ),
);

const PackageOffering _yearlyPackage = PackageOffering(
  identifier: '\$rc_annual',
  packageType: 'annual',
  product: ProductOffering(
    identifier: 'pro_yearly',
    title: 'Pro Yearly',
    description: 'Yearly Pro subscription',
    price: 39.99,
    priceString: '\$39.99',
    currencyCode: 'USD',
    type: ProductType.subscription,
  ),
);

const OfferingsModel _testOfferings = OfferingsModel(
  availablePackages: [_monthlyPackage, _yearlyPackage],
  currentOffering: _monthlyPackage,
);

const OfferingsModel _emptyOfferings = OfferingsModel(
  availablePackages: [],
);

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  late MockPurchaseRepository mockPurchaseRepository;
  late MockAnalyticsService mockAnalyticsService;

  setUp(() {
    mockPurchaseRepository = MockPurchaseRepository();
    mockAnalyticsService = MockAnalyticsService();

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(mockAnalyticsService);

    // Stub analytics methods
    when(() => mockAnalyticsService.logProUpgradeCompleted(
          packageId: any(named: 'packageId'),
        )).thenAnswer((_) async {});
    when(() => mockAnalyticsService.logProUpgradeCancelled())
        .thenAnswer((_) async {});
    when(() => mockAnalyticsService.logPurchaseRestored(
          restoredCount: any(named: 'restoredCount'),
        )).thenAnswer((_) async {});

    // Stub customerInfoStream (needed by PurchaseBloc constructor indirectly)
    when(() => mockPurchaseRepository.customerInfoStream)
        .thenAnswer((_) => const Stream<CustomerInfoModel>.empty());
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  group('PurchaseBloc', () {
    // ── Initialize ─────────────────────────────────────────────────────

    blocTest<PurchaseBloc, PurchaseState>(
      'emits [PurchaseInitializing, PurchaseLoaded] with empty offerings when no API key',
      build: () => PurchaseBloc(mockPurchaseRepository),
      act: (bloc) => bloc.add(const PurchaseInitializeRequested(
        appUserId: 'user-001',
      )),
      expect: () => [
        const PurchaseInitializing(),
        isA<PurchaseLoaded>()
            .having(
              (s) => s.offerings.availablePackages.length,
              'empty packages',
              0,
            )
            .having(
              (s) => s.customerInfo.appUserId,
              'appUserId',
              'user-001',
            ),
      ],
    );

    // ── Load Offerings ─────────────────────────────────────────────────

    blocTest<PurchaseBloc, PurchaseState>(
      'emits [PurchaseLoading, PurchaseLoaded] on successful offerings load',
      build: () {
        when(() => mockPurchaseRepository.getOfferings())
            .thenAnswer((_) async => _testOfferings);
        when(() => mockPurchaseRepository.getCustomerInfo())
            .thenAnswer((_) async => _freeCustomerInfo);
        return PurchaseBloc(mockPurchaseRepository);
      },
      act: (bloc) => bloc.add(const PurchaseOfferingsRequested()),
      expect: () => [
        const PurchaseLoading(),
        PurchaseLoaded(
          offerings: _testOfferings,
          customerInfo: _freeCustomerInfo,
        ),
      ],
      verify: (_) {
        verify(() => mockPurchaseRepository.getOfferings()).called(1);
        verify(() => mockPurchaseRepository.getCustomerInfo()).called(1);
      },
    );

    blocTest<PurchaseBloc, PurchaseState>(
      'emits [PurchaseLoading, PurchaseError] on offerings load failure',
      build: () {
        when(() => mockPurchaseRepository.getOfferings())
            .thenThrow(Exception('Network error'));
        when(() => mockPurchaseRepository.getCustomerInfo())
            .thenAnswer((_) async => _freeCustomerInfo);
        return PurchaseBloc(mockPurchaseRepository);
      },
      act: (bloc) => bloc.add(const PurchaseOfferingsRequested()),
      expect: () => [
        const PurchaseLoading(),
        isA<PurchaseError>().having(
          (s) => s.message,
          'message',
          contains('Network error'),
        ),
      ],
    );

    // ── Purchase Package ───────────────────────────────────────────────

    blocTest<PurchaseBloc, PurchaseState>(
      'emits [PurchaseInProgress, PurchaseSuccess] on successful purchase',
      build: () {
        when(() => mockPurchaseRepository.purchasePackage(any()))
            .thenAnswer((_) async => PurchaseResultModel.success(_proCustomerInfo));
        return PurchaseBloc(mockPurchaseRepository);
      },
      seed: () => PurchaseLoaded(
        offerings: _testOfferings,
        customerInfo: _freeCustomerInfo,
      ),
      act: (bloc) => bloc.add(
        const PurchasePackageRequested(packageId: '\$rc_monthly'),
      ),
      expect: () => [
        isA<PurchaseInProgress>().having(
          (s) => s.packageId,
          'packageId',
          '\$rc_monthly',
        ),
        isA<PurchaseSuccess>()
            .having((s) => s.isPro, 'isPro', isTrue)
            .having(
              (s) => s.message,
              'message',
              'Welcome to Pro! Your subscription is now active.',
            ),
      ],
      verify: (_) {
        verify(() => mockAnalyticsService.logProUpgradeCompleted(
              packageId: '\$rc_monthly',
            )).called(1);
      },
    );

    blocTest<PurchaseBloc, PurchaseState>(
      'emits [PurchaseInProgress, PurchaseCancelled, PurchaseLoaded] when user cancels purchase',
      build: () {
        when(() => mockPurchaseRepository.purchasePackage(any()))
            .thenAnswer((_) async => PurchaseResultModel.cancelled());
        return PurchaseBloc(mockPurchaseRepository);
      },
      seed: () => PurchaseLoaded(
        offerings: _testOfferings,
        customerInfo: _freeCustomerInfo,
      ),
      act: (bloc) => bloc.add(
        const PurchasePackageRequested(packageId: '\$rc_monthly'),
      ),
      wait: const Duration(seconds: 1),
      expect: () => [
        isA<PurchaseInProgress>(),
        isA<PurchaseCancelled>(),
        isA<PurchaseLoaded>(),
      ],
      verify: (_) {
        verify(() => mockAnalyticsService.logProUpgradeCancelled()).called(1);
      },
    );

    blocTest<PurchaseBloc, PurchaseState>(
      'emits [PurchaseInProgress, PurchaseError] on purchase failure',
      build: () {
        when(() => mockPurchaseRepository.purchasePackage(any())).thenAnswer(
          (_) async => PurchaseResultModel.error('Payment declined'),
        );
        return PurchaseBloc(mockPurchaseRepository);
      },
      seed: () => PurchaseLoaded(
        offerings: _testOfferings,
        customerInfo: _freeCustomerInfo,
      ),
      act: (bloc) => bloc.add(
        const PurchasePackageRequested(packageId: '\$rc_monthly'),
      ),
      expect: () => [
        isA<PurchaseInProgress>(),
        isA<PurchaseError>().having(
          (s) => s.message,
          'message',
          'Payment declined',
        ),
      ],
    );

    blocTest<PurchaseBloc, PurchaseState>(
      'does nothing when purchasing from non-loaded state',
      build: () => PurchaseBloc(mockPurchaseRepository),
      act: (bloc) => bloc.add(
        const PurchasePackageRequested(packageId: '\$rc_monthly'),
      ),
      expect: () => <PurchaseState>[],
    );

    // ── Restore Purchases ──────────────────────────────────────────────

    blocTest<PurchaseBloc, PurchaseState>(
      'emits [PurchaseRestoreInProgress, PurchaseRestoreSuccess] on successful restore with Pro',
      build: () {
        when(() => mockPurchaseRepository.restorePurchases()).thenAnswer(
          (_) async => RestoreResultModel.success(_proCustomerInfo, 1),
        );
        return PurchaseBloc(mockPurchaseRepository);
      },
      seed: () => PurchaseLoaded(
        offerings: _testOfferings,
        customerInfo: _freeCustomerInfo,
      ),
      act: (bloc) => bloc.add(const PurchaseRestoreRequested()),
      expect: () => [
        isA<PurchaseRestoreInProgress>(),
        isA<PurchaseRestoreSuccess>()
            .having((s) => s.restoredCount, 'restoredCount', 1)
            .having((s) => s.isPro, 'isPro', isTrue)
            .having(
              (s) => s.message,
              'message',
              'Pro subscription restored successfully!',
            ),
      ],
      verify: (_) {
        verify(() => mockAnalyticsService.logPurchaseRestored(restoredCount: 1))
            .called(1);
      },
    );

    blocTest<PurchaseBloc, PurchaseState>(
      'emits restore success with "no purchases found" message when nothing to restore',
      build: () {
        when(() => mockPurchaseRepository.restorePurchases()).thenAnswer(
          (_) async => RestoreResultModel.success(_freeCustomerInfo, 0),
        );
        return PurchaseBloc(mockPurchaseRepository);
      },
      seed: () => PurchaseLoaded(
        offerings: _testOfferings,
        customerInfo: _freeCustomerInfo,
      ),
      act: (bloc) => bloc.add(const PurchaseRestoreRequested()),
      expect: () => [
        isA<PurchaseRestoreInProgress>(),
        isA<PurchaseRestoreSuccess>().having(
          (s) => s.message,
          'message',
          'No previous purchases found.',
        ),
      ],
    );

    blocTest<PurchaseBloc, PurchaseState>(
      'emits [PurchaseRestoreInProgress, PurchaseError] on restore failure',
      build: () {
        when(() => mockPurchaseRepository.restorePurchases()).thenAnswer(
          (_) async => RestoreResultModel.error('Restore failed'),
        );
        return PurchaseBloc(mockPurchaseRepository);
      },
      seed: () => PurchaseLoaded(
        offerings: _testOfferings,
        customerInfo: _freeCustomerInfo,
      ),
      act: (bloc) => bloc.add(const PurchaseRestoreRequested()),
      expect: () => [
        isA<PurchaseRestoreInProgress>(),
        isA<PurchaseError>().having(
          (s) => s.message,
          'message',
          'Restore failed',
        ),
      ],
    );

    blocTest<PurchaseBloc, PurchaseState>(
      'does nothing when restoring from non-loaded state',
      build: () => PurchaseBloc(mockPurchaseRepository),
      act: (bloc) => bloc.add(const PurchaseRestoreRequested()),
      expect: () => <PurchaseState>[],
    );

    // ── Login ──────────────────────────────────────────────────────────

    blocTest<PurchaseBloc, PurchaseState>(
      'emits [PurchaseLoaded] on successful login',
      build: () {
        when(() => mockPurchaseRepository.logIn(any()))
            .thenAnswer((_) async => _freeCustomerInfo);
        when(() => mockPurchaseRepository.getOfferings())
            .thenAnswer((_) async => _testOfferings);
        return PurchaseBloc(mockPurchaseRepository);
      },
      act: (bloc) => bloc.add(
        const PurchaseLoginRequested(appUserId: 'user-001'),
      ),
      expect: () => [
        PurchaseLoaded(
          offerings: _testOfferings,
          customerInfo: _freeCustomerInfo,
        ),
      ],
    );

    blocTest<PurchaseBloc, PurchaseState>(
      'emits [PurchaseError] on login failure',
      build: () {
        when(() => mockPurchaseRepository.logIn(any()))
            .thenThrow(Exception('Login failed'));
        return PurchaseBloc(mockPurchaseRepository);
      },
      act: (bloc) => bloc.add(
        const PurchaseLoginRequested(appUserId: 'user-001'),
      ),
      expect: () => [
        isA<PurchaseError>().having(
          (s) => s.message,
          'message',
          contains('Login failed'),
        ),
      ],
    );

    // ── Logout ─────────────────────────────────────────────────────────

    blocTest<PurchaseBloc, PurchaseState>(
      'emits [PurchaseLoaded] on successful logout',
      build: () {
        when(() => mockPurchaseRepository.logOut())
            .thenAnswer((_) async => _freeCustomerInfo);
        when(() => mockPurchaseRepository.getOfferings())
            .thenAnswer((_) async => _emptyOfferings);
        return PurchaseBloc(mockPurchaseRepository);
      },
      act: (bloc) => bloc.add(const PurchaseLogoutRequested()),
      expect: () => [
        PurchaseLoaded(
          offerings: _emptyOfferings,
          customerInfo: _freeCustomerInfo,
        ),
      ],
    );

    // ── Customer Info Updated ──────────────────────────────────────────

    blocTest<PurchaseBloc, PurchaseState>(
      'updates customer info when stream event fires from loaded state',
      build: () {
        when(() => mockPurchaseRepository.getCustomerInfo())
            .thenAnswer((_) async => _proCustomerInfo);
        return PurchaseBloc(mockPurchaseRepository);
      },
      seed: () => PurchaseLoaded(
        offerings: _testOfferings,
        customerInfo: _freeCustomerInfo,
      ),
      act: (bloc) => bloc.add(const PurchaseCustomerInfoUpdated()),
      expect: () => [
        PurchaseLoaded(
          offerings: _testOfferings,
          customerInfo: _proCustomerInfo,
        ),
      ],
    );

    blocTest<PurchaseBloc, PurchaseState>(
      'does nothing on customer info update from non-loaded state',
      build: () => PurchaseBloc(mockPurchaseRepository),
      act: (bloc) => bloc.add(const PurchaseCustomerInfoUpdated()),
      expect: () => <PurchaseState>[],
    );
  });
}
