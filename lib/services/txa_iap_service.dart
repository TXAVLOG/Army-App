import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'txa_auth_service.dart';
import '../widgets/txa_toast.dart';
import 'txa_language.dart';
import '../main.dart';
import 'txa_logger.dart';
import 'txa_config.dart';


class TXAIAPService extends ChangeNotifier {
  static final TXAIAPService instance = TXAIAPService._internal();
  TXAIAPService._internal() {
    _initialize();
  }

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  static const String monthlyProductId = TXAConfig.iapMonthlyProductId;
  static const String yearlyProductId = TXAConfig.iapYearlyProductId;

  bool get isVipActive {
    if (kIsWeb || Platform.isWindows) {
      return true; // Bypass on Windows/Web
    }
    final user = TXAAuthService.instance.currentUser;
    return user?.isVipActive ?? false;
  }

  void _initialize() {
    if (kIsWeb || Platform.isWindows) return;

    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _subscription?.cancel();
      },
      onError: (error) {
        TXALogger.logError(error, extraInfo: {'service': 'TXAIAPService', 'action': 'purchaseStream'});
      },
    );
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (kIsWeb || Platform.isWindows) return;

    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) return;

    const Set<String> ids = {monthlyProductId, yearlyProductId};
    final ProductDetailsResponse response = await _iap.queryProductDetails(ids);
    if (response.notFoundIDs.isNotEmpty) {
      TXALogger.logWarning('Products not found: ${response.notFoundIDs}', extraInfo: {'service': 'TXAIAPService', 'action': '_loadProducts'});
    }
    _products = response.productDetails;
    notifyListeners();
  }

  Future<void> buySubscription(ProductDetails product) async {
    if (Platform.isIOS) {
      // iOS Toast placeholder as requested
      final context = navigatorKey.currentContext;
      if (context != null) {
        TXAToast.show(
          context,
          TXALanguage.instance.getText('ios_iap_unsupported') ?? '⚠️ Tính năng đăng ký gói Army Gold Pass 🌟 hiện chưa hỗ trợ trên thiết bị iOS. Vui lòng quay lại sau!',
          icon: Icons.warning_amber_rounded,
        );
      }
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    try {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e, stack) {
      TXALogger.logError(e, stackTrace: stack, extraInfo: {'service': 'TXAIAPService', 'action': 'buySubscription'});
    }
  }

  Future<void> restorePurchases() async {
    if (kIsWeb || Platform.isWindows) return;
    try {
      await _iap.restorePurchases();
    } catch (e, stack) {
      TXALogger.logError(e, stackTrace: stack, extraInfo: {'service': 'TXAIAPService', 'action': 'restorePurchases'});
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      if (purchaseDetails.status == PurchaseState.pending) {
        // Handle pending state
      } else {
        if (purchaseDetails.status == PurchaseState.error) {
          debugPrint('Purchase error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseState.purchased ||
            purchaseDetails.status == PurchaseState.restored) {
          // Verify purchase and update user VIP status in Firestore
          await _verifyAndActivateVIP(purchaseDetails);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    });
  }

  Future<void> _verifyAndActivateVIP(PurchaseDetails purchase) async {
    final user = TXAAuthService.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.id).update({
        'isVipActive': true,
        'vipPurchaseToken': purchase.purchaseID,
        'vipPurchaseDate': DateTime.now().toIso8601String(),
      });
      await TXAAuthService.instance.syncUserFromFirestore();
    } catch (e) {
      debugPrint('Error updating VIP status: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

