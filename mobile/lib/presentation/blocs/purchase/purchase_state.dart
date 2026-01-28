import 'package:equatable/equatable.dart';

import '../../../data/models/purchase_model.dart';

/// Purchase states
sealed class PurchaseState extends Equatable {
  const PurchaseState();

  @override
  List<Object?> get props => [];
}

/// Initial state - SDK not initialized
class PurchaseInitial extends PurchaseState {
  const PurchaseInitial();
}

/// SDK initializing
class PurchaseInitializing extends PurchaseState {
  const PurchaseInitializing();
}

/// SDK initialized, loading offerings
class PurchaseLoading extends PurchaseState {
  const PurchaseLoading();
}

/// Offerings and customer info loaded
class PurchaseLoaded extends PurchaseState {
  final OfferingsModel offerings;
  final CustomerInfoModel customerInfo;

  const PurchaseLoaded({
    required this.offerings,
    required this.customerInfo,
  });

  @override
  List<Object?> get props => [offerings, customerInfo];

  /// Check if user has Pro entitlement
  bool get isPro => customerInfo.isPro;

  /// Check if user is on trial
  bool get isOnTrial => customerInfo.isOnTrial;

  /// Get days remaining in subscription/trial
  int? get daysRemaining => customerInfo.daysRemaining;

  /// Copy with updated values
  PurchaseLoaded copyWith({
    OfferingsModel? offerings,
    CustomerInfoModel? customerInfo,
  }) {
    return PurchaseLoaded(
      offerings: offerings ?? this.offerings,
      customerInfo: customerInfo ?? this.customerInfo,
    );
  }
}

/// Purchase in progress
class PurchaseInProgress extends PurchaseState {
  final PurchaseLoaded previousState;
  final String packageId;

  const PurchaseInProgress({
    required this.previousState,
    required this.packageId,
  });

  @override
  List<Object?> get props => [previousState, packageId];
}

/// Purchase successful
class PurchaseSuccess extends PurchaseState {
  final CustomerInfoModel customerInfo;
  final String message;

  const PurchaseSuccess({
    required this.customerInfo,
    required this.message,
  });

  @override
  List<Object?> get props => [customerInfo, message];

  /// Check if user now has Pro
  bool get isPro => customerInfo.isPro;
}

/// Purchase cancelled by user
class PurchaseCancelled extends PurchaseState {
  final PurchaseLoaded previousState;

  const PurchaseCancelled({required this.previousState});

  @override
  List<Object?> get props => [previousState];
}

/// Restore in progress
class PurchaseRestoreInProgress extends PurchaseState {
  final PurchaseLoaded previousState;

  const PurchaseRestoreInProgress({required this.previousState});

  @override
  List<Object?> get props => [previousState];
}

/// Restore successful
class PurchaseRestoreSuccess extends PurchaseState {
  final CustomerInfoModel customerInfo;
  final int restoredCount;
  final String message;

  const PurchaseRestoreSuccess({
    required this.customerInfo,
    required this.restoredCount,
    required this.message,
  });

  @override
  List<Object?> get props => [customerInfo, restoredCount, message];

  /// Check if any purchases were restored
  bool get hasPurchases => restoredCount > 0;

  /// Check if user now has Pro
  bool get isPro => customerInfo.isPro;
}

/// Error state
class PurchaseError extends PurchaseState {
  final String message;
  final PurchaseLoaded? previousState;

  const PurchaseError({
    required this.message,
    this.previousState,
  });

  @override
  List<Object?> get props => [message, previousState];
}
