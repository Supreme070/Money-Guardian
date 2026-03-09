import 'package:equatable/equatable.dart';

/// Purchase events
sealed class PurchaseEvent extends Equatable {
  const PurchaseEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize RevenueCat SDK
class PurchaseInitializeRequested extends PurchaseEvent {
  final String? appUserId;

  const PurchaseInitializeRequested({this.appUserId});

  @override
  List<Object?> get props => [appUserId];
}

/// Load available offerings
class PurchaseOfferingsRequested extends PurchaseEvent {
  const PurchaseOfferingsRequested();
}

/// Load customer info
class PurchaseCustomerInfoRequested extends PurchaseEvent {
  const PurchaseCustomerInfoRequested();
}

/// Purchase a package by identifier
class PurchasePackageRequested extends PurchaseEvent {
  final String packageId;

  const PurchasePackageRequested({required this.packageId});

  @override
  List<Object?> get props => [packageId];
}

/// Restore previous purchases
class PurchaseRestoreRequested extends PurchaseEvent {
  const PurchaseRestoreRequested();
}

/// Log in user to RevenueCat
class PurchaseLoginRequested extends PurchaseEvent {
  final String appUserId;

  const PurchaseLoginRequested({required this.appUserId});

  @override
  List<Object?> get props => [appUserId];
}

/// Log out user from RevenueCat
class PurchaseLogoutRequested extends PurchaseEvent {
  const PurchaseLogoutRequested();
}

/// Customer info updated (from stream)
class PurchaseCustomerInfoUpdated extends PurchaseEvent {
  const PurchaseCustomerInfoUpdated();
}

/// Sync subscription tier with backend after purchase
class PurchaseSyncRequested extends PurchaseEvent {
  const PurchaseSyncRequested();
}
