import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IapService extends ChangeNotifier {
  IapService._();
  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  ProductDetails? _removeAdsProduct;
  ProductDetails? get removeAdsProduct => _removeAdsProduct;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  static const String removeAdsId = 'remove_ads_yearly';

  void initialize() {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint('IAP Error: $error');
    });

    _initStoreInfo();
  }

  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _initStoreInfo() async {
    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      notifyListeners();
      return;
    }

    final ProductDetailsResponse response = await _iap.queryProductDetails({removeAdsId});
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Product $removeAdsId not found in store.');
    }
    
    if (response.productDetails.isNotEmpty) {
      _removeAdsProduct = response.productDetails.first;
    }
    
    notifyListeners();
  }

  void buyRemoveAds() {
    if (_removeAdsProduct == null) return;
    _isLoading = true;
    notifyListeners();
    
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: _removeAdsProduct!);
    _iap.buyConsumable(purchaseParam: purchaseParam);
  }

  void restorePurchases() {
    _isLoading = true;
    notifyListeners();
    _iap.restorePurchases();
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _isLoading = true;
        notifyListeners();
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase Error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased || 
                   purchaseDetails.status == PurchaseStatus.restored) {
          
          await _verifyAndDeliverProduct(purchaseDetails);
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _verifyAndDeliverProduct(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.productID == removeAdsId) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'isPremium': true,
          }, SetOptions(merge: true));
          debugPrint('Successfully set isPremium to true for user ${user.uid}');
        } catch (e) {
          debugPrint('Failed to update premium status: $e');
        }
      }
    }
  }
}
