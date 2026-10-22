/// Google Play billing for the term and annual plans.
///
/// The APK links `in_app_purchase` and validates receipts through
/// `/billing/play/verify` (see [ApiClient.verifyPlayPurchase]). This service
/// owns the purchase stream: it queries the plans, starts a purchase, restores
/// previous purchases and reports the active plan to the UI.
///
/// When Play Billing is unavailable — desktop builds, an emulator without Play
/// services, widget tests — [state] becomes [SubscriptionState.notAvailable]
/// and the subscription screen explains that purchases happen in the Play
/// Store instead of failing.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'api_client.dart';

/// One purchasable subscription.
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.title,
    required this.period,
    required this.description,
  });

  /// The product id configured in the Play Console.
  final String id;

  final String title;

  /// How often the plan renews, e.g. "كل شهر".
  final String period;

  final String description;

  /// The plans the app offers when the backend does not override them.
  static const List<SubscriptionPlan> defaults = [
    SubscriptionPlan(
      id: 'zaker_monthly',
      title: 'الخطة الشهرية',
      period: 'كل شهر',
      description: 'كل الأدوات والمدرس الذكي من غير إعلانات.',
    ),
    SubscriptionPlan(
      id: 'zaker_annual',
      title: 'الخطة السنوية',
      period: 'كل سنة',
      description: 'نفس المزايا بسعر أقل — شهرين مجانًا.',
    ),
  ];

  /// The default product ids, as a set for the billing client.
  static Set<String> get defaultIds =>
      defaults.map((p) => p.id).toSet();
}

/// The subscription state shown by the UI.
enum SubscriptionState {
  /// Nothing checked yet.
  unknown,

  /// Play Billing is not available on this device.
  notAvailable,

  /// Checked and the user has no active plan.
  free,

  /// An active plan was purchased or restored.
  active,
}

/// Wraps [InAppPurchase] and keeps the latest purchase state.
class BillingService extends ChangeNotifier {
  BillingService({ApiClient? api, InAppPurchase? iap})
    : _api = api ?? ApiClient(),
      _iap = iap ?? InAppPurchase.instance;

  final ApiClient _api;
  final InAppPurchase _iap;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final Map<String, ProductDetails> products = {};
  final Set<String> unavailableProducts = {};

  SubscriptionState state = SubscriptionState.unknown;
  String? activeProductId;
  String? lastError;

  bool get available => state != SubscriptionState.notAvailable;

  /// The list the screen shows: the store's live products when loaded,
  /// otherwise the bundled plan metadata with no price.
  List<({SubscriptionPlan plan, ProductDetails? product})> get offers => [
    for (final plan in SubscriptionPlan.defaults)
      (plan: plan, product: products[plan.id]),
  ];

  /// Connects the purchase stream. Safe to call more than once.
  Future<void> init() async {
    if (_subscription != null || state == SubscriptionState.notAvailable) {
      return;
    }
    try {
      final ok = await _iap.isAvailable();
      if (!ok) {
        state = SubscriptionState.notAvailable;
        notifyListeners();
        return;
      }
      _subscription = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) {
          lastError = '$e';
          debugPrint('billing: purchase stream error ($e)');
          notifyListeners();
        },
      );
    } catch (e) {
      state = SubscriptionState.notAvailable;
      debugPrint('billing: Play Billing unavailable ($e)');
      notifyListeners();
    }
  }

  /// Queries the store for the plan details.
  Future<void> loadProducts({Set<String>? ids}) async {
    await init();
    if (state == SubscriptionState.notAvailable) return;
    try {
      final response = await _iap.queryProductDetails(
        ids ?? SubscriptionPlan.defaultIds,
      );
      products.clear();
      unavailableProducts
        ..clear()
        ..addAll(response.notFoundIDs);
      for (final detail in response.productDetails) {
        products[detail.id] = detail;
      }
      if (response.error != null) {
        lastError = response.error!.message;
      }
      if (state == SubscriptionState.unknown) state = SubscriptionState.free;
      notifyListeners();
    } catch (e) {
      lastError = '$e';
      debugPrint('billing: queryProductDetails failed ($e)');
      if (state == SubscriptionState.unknown) {
        state = SubscriptionState.free;
      }
      notifyListeners();
    }
  }

  /// Starts the Play purchase flow for [product].
  Future<bool> buy(ProductDetails product) async {
    await init();
    if (state == SubscriptionState.notAvailable) return false;
    try {
      return await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      lastError = '$e';
      debugPrint('billing: buyNonConsumable failed ($e)');
      return false;
    }
  }

  /// Restores purchases made on another device.
  Future<void> restore() async {
    await init();
    if (state == SubscriptionState.notAvailable) return;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      lastError = '$e';
      debugPrint('billing: restorePurchases failed ($e)');
    }
  }

  /// Sends a purchase token to the backend for server-side validation.
  Future<bool> verifyWithBackend(PurchaseDetails purchase) async {
    final token = purchase.verificationData.serverVerificationData;
    if (token.isEmpty) return false;
    try {
      return await _api.verifyPlayPurchase(
        purchaseToken: token,
        productId: purchase.productID,
      );
    } catch (e) {
      debugPrint('billing: backend verification failed ($e)');
      return false;
    }
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          activeProductId = purchase.productID;
          state = SubscriptionState.active;
          // Fire and forget: the local entitlement does not depend on the
          // network round trip.
          unawaited(verifyWithBackend(purchase));
        case PurchaseStatus.error:
          lastError = purchase.error?.message;
        case PurchaseStatus.canceled:
        case PurchaseStatus.pending:
          break;
      }
      if (purchase.pendingCompletePurchase) {
        unawaited(_iap.completePurchase(purchase));
      }
    }
    notifyListeners();
  }

  /// Releases the purchase stream.
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
