import 'dart:async';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../models/purchase_model.dart';

/// Repository for RevenueCat purchase operations
/// Wraps the Purchases SDK with typed models
@lazySingleton
class PurchaseRepository {
  bool _isInitialized = false;

  /// Initialize RevenueCat SDK
  /// Must be called once at app startup
  Future<void> initialize({
    required String apiKey,
    String? appUserId,
  }) async {
    if (_isInitialized) return;

    await Purchases.setLogLevel(LogLevel.debug);

    final PurchasesConfiguration configuration;

    if (Platform.isIOS) {
      configuration = PurchasesConfiguration(apiKey);
    } else if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(apiKey);
    } else {
      throw UnsupportedError('Platform not supported for purchases');
    }

    if (appUserId != null && appUserId.isNotEmpty) {
      configuration.appUserID = appUserId;
    }

    await Purchases.configure(configuration);
    _isInitialized = true;
  }

  /// Check if SDK is initialized
  bool get isInitialized => _isInitialized;

  /// Get current customer info
  Future<CustomerInfoModel> getCustomerInfo() async {
    _ensureInitialized();

    final customerInfo = await Purchases.getCustomerInfo();
    return _mapCustomerInfo(customerInfo);
  }

  /// Get available offerings (products)
  Future<OfferingsModel> getOfferings() async {
    _ensureInitialized();

    final offerings = await Purchases.getOfferings();
    final current = offerings.current;

    if (current == null) {
      return const OfferingsModel(availablePackages: []);
    }

    final packages = current.availablePackages.map(_mapPackage).toList();
    final currentPackage =
        current.monthly != null ? _mapPackage(current.monthly!) : null;

    return OfferingsModel(
      availablePackages: packages,
      currentOffering: currentPackage,
    );
  }

  /// Purchase a package
  Future<PurchaseResultModel> purchasePackage(String packageId) async {
    _ensureInitialized();

    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;

      if (current == null) {
        return PurchaseResultModel.error('No offerings available');
      }

      final package = current.availablePackages.firstWhere(
        (p) => p.identifier == packageId,
        orElse: () => throw Exception('Package not found: $packageId'),
      );

      final result = await Purchases.purchasePackage(package);
      return PurchaseResultModel.success(_mapCustomerInfo(result.customerInfo));
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseResultModel.cancelled();
      }
      return PurchaseResultModel.error(_mapErrorCode(e));
    } catch (e) {
      return PurchaseResultModel.error(e.toString());
    }
  }

  /// Purchase a specific product by ID
  Future<PurchaseResultModel> purchaseProduct(String productId) async {
    _ensureInitialized();

    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;

      if (current == null) {
        return PurchaseResultModel.error('No offerings available');
      }

      // Find package containing this product
      Package? targetPackage;
      for (final package in current.availablePackages) {
        if (package.storeProduct.identifier == productId) {
          targetPackage = package;
          break;
        }
      }

      if (targetPackage == null) {
        return PurchaseResultModel.error('Product not found: $productId');
      }

      final result = await Purchases.purchasePackage(targetPackage);
      return PurchaseResultModel.success(_mapCustomerInfo(result.customerInfo));
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseResultModel.cancelled();
      }
      return PurchaseResultModel.error(_mapErrorCode(e));
    } catch (e) {
      return PurchaseResultModel.error(e.toString());
    }
  }

  /// Restore purchases
  Future<RestoreResultModel> restorePurchases() async {
    _ensureInitialized();

    try {
      final customerInfo = await Purchases.restorePurchases();
      final restoredCount =
          customerInfo.allPurchasedProductIdentifiers.length;

      return RestoreResultModel.success(
        _mapCustomerInfo(customerInfo),
        restoredCount,
      );
    } on PurchasesErrorCode catch (e) {
      return RestoreResultModel.error(_mapErrorCode(e));
    } catch (e) {
      return RestoreResultModel.error(e.toString());
    }
  }

  /// Log in user with their app user ID
  Future<CustomerInfoModel> logIn(String appUserId) async {
    _ensureInitialized();

    final result = await Purchases.logIn(appUserId);
    return _mapCustomerInfo(result.customerInfo);
  }

  /// Log out current user
  Future<CustomerInfoModel> logOut() async {
    _ensureInitialized();

    final customerInfo = await Purchases.logOut();
    return _mapCustomerInfo(customerInfo);
  }

  /// Check if user has Pro entitlement
  Future<bool> isPro() async {
    final customerInfo = await getCustomerInfo();
    return customerInfo.isPro;
  }

  /// Get management URL for subscription
  Future<String?> getManagementUrl() async {
    final customerInfo = await getCustomerInfo();
    return customerInfo.managementUrl;
  }

  /// Listen to customer info changes
  /// RevenueCat 8.x uses listeners instead of streams, so we convert to a stream
  Stream<CustomerInfoModel> get customerInfoStream {
    final controller = StreamController<CustomerInfoModel>.broadcast();

    void listener(CustomerInfo info) {
      controller.add(_mapCustomerInfo(info));
    }

    Purchases.addCustomerInfoUpdateListener(listener);

    controller.onCancel = () {
      Purchases.removeCustomerInfoUpdateListener(listener);
    };

    return controller.stream;
  }

  /// Ensure SDK is initialized before operations
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'PurchaseRepository not initialized. Call initialize() first.',
      );
    }
  }

  /// Map RevenueCat CustomerInfo to our model
  /// Note: RevenueCat 8.x returns dates as ISO8601 strings, so we parse them
  CustomerInfoModel _mapCustomerInfo(CustomerInfo info) {
    final entitlements = <String, EntitlementInfoModel>{};

    info.entitlements.all.forEach((key, value) {
      entitlements[key] = EntitlementInfoModel(
        identifier: value.identifier,
        isActive: value.isActive,
        expirationDate: _parseDate(value.expirationDate),
        productIdentifier: value.productIdentifier,
        willRenew: value.willRenew,
        periodType: value.periodType.name,
        latestPurchaseDate: _parseDate(value.latestPurchaseDate),
        originalPurchaseDate: _parseDate(value.originalPurchaseDate),
        isSandbox: value.isSandbox,
      );
    });

    return CustomerInfoModel(
      appUserId: info.originalAppUserId,
      firstSeen: _parseDate(info.firstSeen) ?? DateTime.now(),
      entitlements: entitlements,
      activeSubscriptions: info.activeSubscriptions.toList(),
      allPurchasedProductIdentifiers:
          info.allPurchasedProductIdentifiers.toList(),
      latestExpirationDate: _parseDate(info.latestExpirationDate),
      managementUrl: info.managementURL?.toString(),
    );
  }

  /// Parse ISO8601 date string to DateTime
  /// RevenueCat 8.x returns dates as strings instead of DateTime objects
  DateTime? _parseDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return null;
    }
    return DateTime.tryParse(dateString);
  }

  /// Map RevenueCat Package to our model
  PackageOffering _mapPackage(Package package) {
    final product = package.storeProduct;

    ProductType productType;
    if (package.packageType == PackageType.lifetime) {
      productType = ProductType.lifetime;
    } else if (product.productCategory == ProductCategory.subscription) {
      productType = ProductType.subscription;
    } else {
      productType = ProductType.nonRenewing;
    }

    return PackageOffering(
      identifier: package.identifier,
      packageType: package.packageType.name,
      product: ProductOffering(
        identifier: product.identifier,
        title: product.title,
        description: product.description,
        price: product.price,
        priceString: product.priceString,
        currencyCode: product.currencyCode,
        type: productType,
        introductoryPrice: product.introductoryPrice?.priceString,
        trialDays: product.introductoryPrice?.cycles,
      ),
    );
  }

  /// Map RevenueCat error codes to user-friendly messages
  String _mapErrorCode(PurchasesErrorCode code) {
    switch (code) {
      case PurchasesErrorCode.purchaseCancelledError:
        return 'Purchase was cancelled';
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Purchase not allowed on this device';
      case PurchasesErrorCode.purchaseInvalidError:
        return 'Invalid purchase';
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        return 'Product not available for purchase';
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return 'Product already purchased';
      case PurchasesErrorCode.receiptAlreadyInUseError:
        return 'Receipt already in use by another account';
      case PurchasesErrorCode.invalidCredentialsError:
        return 'Invalid credentials';
      case PurchasesErrorCode.networkError:
        return 'Network error. Please check your connection.';
      case PurchasesErrorCode.storeProblemError:
        return 'There was a problem with the App Store. Please try again.';
      case PurchasesErrorCode.operationAlreadyInProgressError:
        return 'Another purchase is in progress';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
