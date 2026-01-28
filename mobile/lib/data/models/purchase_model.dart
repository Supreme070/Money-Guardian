/// Purchase data models for RevenueCat integration
/// Strictly typed - NO dynamic, NO Object?, following Zod pattern

/// Product identifier enum for our offerings
enum ProductId {
  proMonthly('pro_monthly'),
  proYearly('pro_yearly'),
  proLifetime('pro_lifetime');

  final String value;
  const ProductId(this.value);

  static ProductId fromString(String value) {
    return ProductId.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ProductId.proMonthly,
    );
  }
}

/// Entitlement identifiers
enum EntitlementId {
  pro('pro');

  final String value;
  const EntitlementId(this.value);

  static EntitlementId fromString(String value) {
    return EntitlementId.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EntitlementId.pro,
    );
  }
}

/// Product type (subscription vs non-renewing)
enum ProductType {
  subscription,
  nonRenewing,
  lifetime;
}

/// Product offering model
class ProductOffering {
  final String identifier;
  final String title;
  final String description;
  final double price;
  final String priceString;
  final String currencyCode;
  final ProductType type;
  final String? introductoryPrice;
  final int? trialDays;

  const ProductOffering({
    required this.identifier,
    required this.title,
    required this.description,
    required this.price,
    required this.priceString,
    required this.currencyCode,
    required this.type,
    this.introductoryPrice,
    this.trialDays,
  });

  /// Check if this is a subscription product
  bool get isSubscription => type == ProductType.subscription;

  /// Check if this has a free trial
  bool get hasFreeTrial => trialDays != null && trialDays! > 0;
}

/// Package model (wrapper around product in an offering)
class PackageOffering {
  final String identifier;
  final ProductOffering product;
  final String? packageType; // monthly, annual, lifetime, etc.

  const PackageOffering({
    required this.identifier,
    required this.product,
    this.packageType,
  });
}

/// Current offerings available
class OfferingsModel {
  final List<PackageOffering> availablePackages;
  final PackageOffering? currentOffering; // The default/recommended offering

  const OfferingsModel({
    required this.availablePackages,
    this.currentOffering,
  });

  /// Get package by identifier
  PackageOffering? getPackage(String identifier) {
    try {
      return availablePackages.firstWhere(
        (p) => p.identifier == identifier,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get monthly package
  PackageOffering? get monthlyPackage => getPackage('\$rc_monthly');

  /// Get annual package
  PackageOffering? get annualPackage => getPackage('\$rc_annual');

  /// Get lifetime package
  PackageOffering? get lifetimePackage => getPackage('\$rc_lifetime');
}

/// Entitlement info model
class EntitlementInfoModel {
  final String identifier;
  final bool isActive;
  final DateTime? expirationDate;
  final String? productIdentifier;
  final bool willRenew;
  final String? periodType; // normal, trial, intro
  final DateTime? latestPurchaseDate;
  final DateTime? originalPurchaseDate;
  final bool isSandbox;

  const EntitlementInfoModel({
    required this.identifier,
    required this.isActive,
    this.expirationDate,
    this.productIdentifier,
    required this.willRenew,
    this.periodType,
    this.latestPurchaseDate,
    this.originalPurchaseDate,
    required this.isSandbox,
  });

  /// Check if this is a trial period
  bool get isTrial => periodType == 'trial';

  /// Check if this is intro pricing
  bool get isIntro => periodType == 'intro';

  /// Check if subscription is expired
  bool get isExpired {
    if (expirationDate == null) return false;
    return DateTime.now().isAfter(expirationDate!);
  }

  /// Days until expiration
  int? get daysUntilExpiration {
    if (expirationDate == null) return null;
    return expirationDate!.difference(DateTime.now()).inDays;
  }
}

/// Customer info model
class CustomerInfoModel {
  final String appUserId;
  final DateTime firstSeen;
  final Map<String, EntitlementInfoModel> entitlements;
  final List<String> activeSubscriptions;
  final List<String> allPurchasedProductIdentifiers;
  final DateTime? latestExpirationDate;
  final String? managementUrl;

  const CustomerInfoModel({
    required this.appUserId,
    required this.firstSeen,
    required this.entitlements,
    required this.activeSubscriptions,
    required this.allPurchasedProductIdentifiers,
    this.latestExpirationDate,
    this.managementUrl,
  });

  /// Check if user has Pro entitlement
  bool get isPro {
    final proEntitlement = entitlements[EntitlementId.pro.value];
    return proEntitlement?.isActive ?? false;
  }

  /// Get Pro entitlement info
  EntitlementInfoModel? get proEntitlement {
    return entitlements[EntitlementId.pro.value];
  }

  /// Check if user has any active subscription
  bool get hasActiveSubscription => activeSubscriptions.isNotEmpty;

  /// Check if user is on trial
  bool get isOnTrial => proEntitlement?.isTrial ?? false;

  /// Days remaining in trial or subscription
  int? get daysRemaining => proEntitlement?.daysUntilExpiration;
}

/// Purchase result model
class PurchaseResultModel {
  final bool success;
  final CustomerInfoModel? customerInfo;
  final String? errorMessage;
  final bool userCancelled;

  const PurchaseResultModel({
    required this.success,
    this.customerInfo,
    this.errorMessage,
    required this.userCancelled,
  });

  /// Create success result
  factory PurchaseResultModel.success(CustomerInfoModel customerInfo) {
    return PurchaseResultModel(
      success: true,
      customerInfo: customerInfo,
      userCancelled: false,
    );
  }

  /// Create error result
  factory PurchaseResultModel.error(String message) {
    return PurchaseResultModel(
      success: false,
      errorMessage: message,
      userCancelled: false,
    );
  }

  /// Create cancelled result
  factory PurchaseResultModel.cancelled() {
    return const PurchaseResultModel(
      success: false,
      userCancelled: true,
    );
  }
}

/// Restore result model
class RestoreResultModel {
  final bool success;
  final CustomerInfoModel? customerInfo;
  final String? errorMessage;
  final int restoredPurchases;

  const RestoreResultModel({
    required this.success,
    this.customerInfo,
    this.errorMessage,
    required this.restoredPurchases,
  });

  /// Create success result
  factory RestoreResultModel.success(
    CustomerInfoModel customerInfo,
    int restoredCount,
  ) {
    return RestoreResultModel(
      success: true,
      customerInfo: customerInfo,
      restoredPurchases: restoredCount,
    );
  }

  /// Create error result
  factory RestoreResultModel.error(String message) {
    return RestoreResultModel(
      success: false,
      errorMessage: message,
      restoredPurchases: 0,
    );
  }

  /// Check if any purchases were restored
  bool get hasPurchases => restoredPurchases > 0;
}
