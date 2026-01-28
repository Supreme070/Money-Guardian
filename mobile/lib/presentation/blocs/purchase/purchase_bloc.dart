import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../data/models/purchase_model.dart';
import '../../../data/repositories/purchase_repository.dart';
import 'purchase_event.dart';
import 'purchase_state.dart';

/// BLoC for in-app purchase state management
@injectable
class PurchaseBloc extends Bloc<PurchaseEvent, PurchaseState> {
  final PurchaseRepository _purchaseRepository;
  StreamSubscription<CustomerInfoModel>? _customerInfoSubscription;

  PurchaseBloc(this._purchaseRepository) : super(const PurchaseInitial()) {
    on<PurchaseInitializeRequested>(_onInitializeRequested);
    on<PurchaseOfferingsRequested>(_onOfferingsRequested);
    on<PurchaseCustomerInfoRequested>(_onCustomerInfoRequested);
    on<PurchasePackageRequested>(_onPackageRequested);
    on<PurchaseRestoreRequested>(_onRestoreRequested);
    on<PurchaseLoginRequested>(_onLoginRequested);
    on<PurchaseLogoutRequested>(_onLogoutRequested);
    on<PurchaseCustomerInfoUpdated>(_onCustomerInfoUpdated);
  }

  Future<void> _onInitializeRequested(
    PurchaseInitializeRequested event,
    Emitter<PurchaseState> emit,
  ) async {
    emit(const PurchaseInitializing());

    try {
      // Get API key from environment - must be configured
      const apiKey = String.fromEnvironment(
        'REVENUECAT_API_KEY',
        defaultValue: '',
      );

      if (apiKey.isEmpty) {
        // In development, allow proceeding without RevenueCat
        emit(PurchaseLoaded(
          offerings: const OfferingsModel(availablePackages: []),
          customerInfo: CustomerInfoModel(
            appUserId: event.appUserId ?? 'anonymous',
            firstSeen: DateTime.now(),
            entitlements: const {},
            activeSubscriptions: const [],
            allPurchasedProductIdentifiers: const [],
          ),
        ));
        return;
      }

      await _purchaseRepository.initialize(
        apiKey: apiKey,
        appUserId: event.appUserId,
      );

      // Start listening to customer info updates
      _customerInfoSubscription?.cancel();
      _customerInfoSubscription = _purchaseRepository.customerInfoStream.listen(
        (_) => add(const PurchaseCustomerInfoUpdated()),
      );

      // Load offerings and customer info
      add(const PurchaseOfferingsRequested());
    } catch (e) {
      emit(PurchaseError(message: 'Failed to initialize: ${e.toString()}'));
    }
  }

  Future<void> _onOfferingsRequested(
    PurchaseOfferingsRequested event,
    Emitter<PurchaseState> emit,
  ) async {
    emit(const PurchaseLoading());

    try {
      final results = await Future.wait([
        _purchaseRepository.getOfferings(),
        _purchaseRepository.getCustomerInfo(),
      ]);

      final offerings = results[0] as OfferingsModel;
      final customerInfo = results[1] as CustomerInfoModel;

      emit(PurchaseLoaded(
        offerings: offerings,
        customerInfo: customerInfo,
      ));
    } catch (e) {
      emit(PurchaseError(message: e.toString()));
    }
  }

  Future<void> _onCustomerInfoRequested(
    PurchaseCustomerInfoRequested event,
    Emitter<PurchaseState> emit,
  ) async {
    final currentState = state;
    if (currentState is! PurchaseLoaded) return;

    try {
      final customerInfo = await _purchaseRepository.getCustomerInfo();
      emit(currentState.copyWith(customerInfo: customerInfo));
    } catch (e) {
      emit(PurchaseError(
        message: e.toString(),
        previousState: currentState,
      ));
    }
  }

  Future<void> _onPackageRequested(
    PurchasePackageRequested event,
    Emitter<PurchaseState> emit,
  ) async {
    final currentState = state;
    if (currentState is! PurchaseLoaded) return;

    emit(PurchaseInProgress(
      previousState: currentState,
      packageId: event.packageId,
    ));

    try {
      final result = await _purchaseRepository.purchasePackage(event.packageId);

      if (result.userCancelled) {
        emit(PurchaseCancelled(previousState: currentState));
        // Return to loaded state after brief delay
        await Future.delayed(const Duration(milliseconds: 500));
        emit(currentState);
        return;
      }

      if (!result.success) {
        emit(PurchaseError(
          message: result.errorMessage ?? 'Purchase failed',
          previousState: currentState,
        ));
        return;
      }

      emit(PurchaseSuccess(
        customerInfo: result.customerInfo!,
        message: 'Welcome to Pro! Your subscription is now active.',
      ));
    } catch (e) {
      emit(PurchaseError(
        message: e.toString(),
        previousState: currentState,
      ));
    }
  }

  Future<void> _onRestoreRequested(
    PurchaseRestoreRequested event,
    Emitter<PurchaseState> emit,
  ) async {
    final currentState = state;
    if (currentState is! PurchaseLoaded) return;

    emit(PurchaseRestoreInProgress(previousState: currentState));

    try {
      final result = await _purchaseRepository.restorePurchases();

      if (!result.success) {
        emit(PurchaseError(
          message: result.errorMessage ?? 'Restore failed',
          previousState: currentState,
        ));
        return;
      }

      String message;
      if (result.hasPurchases) {
        if (result.customerInfo!.isPro) {
          message = 'Pro subscription restored successfully!';
        } else {
          message = 'Purchases restored, but no active Pro subscription found.';
        }
      } else {
        message = 'No previous purchases found.';
      }

      emit(PurchaseRestoreSuccess(
        customerInfo: result.customerInfo!,
        restoredCount: result.restoredPurchases,
        message: message,
      ));
    } catch (e) {
      emit(PurchaseError(
        message: e.toString(),
        previousState: currentState,
      ));
    }
  }

  Future<void> _onLoginRequested(
    PurchaseLoginRequested event,
    Emitter<PurchaseState> emit,
  ) async {
    try {
      final customerInfo = await _purchaseRepository.logIn(event.appUserId);

      // Refresh offerings after login
      final offerings = await _purchaseRepository.getOfferings();

      emit(PurchaseLoaded(
        offerings: offerings,
        customerInfo: customerInfo,
      ));
    } catch (e) {
      emit(PurchaseError(message: 'Login failed: ${e.toString()}'));
    }
  }

  Future<void> _onLogoutRequested(
    PurchaseLogoutRequested event,
    Emitter<PurchaseState> emit,
  ) async {
    try {
      final customerInfo = await _purchaseRepository.logOut();

      // Refresh offerings after logout
      final offerings = await _purchaseRepository.getOfferings();

      emit(PurchaseLoaded(
        offerings: offerings,
        customerInfo: customerInfo,
      ));
    } catch (e) {
      emit(PurchaseError(message: 'Logout failed: ${e.toString()}'));
    }
  }

  Future<void> _onCustomerInfoUpdated(
    PurchaseCustomerInfoUpdated event,
    Emitter<PurchaseState> emit,
  ) async {
    final currentState = state;
    if (currentState is! PurchaseLoaded) return;

    try {
      final customerInfo = await _purchaseRepository.getCustomerInfo();
      emit(currentState.copyWith(customerInfo: customerInfo));
    } catch (_) {
      // Silently ignore errors from stream updates
    }
  }

  @override
  Future<void> close() {
    _customerInfoSubscription?.cancel();
    return super.close();
  }
}
