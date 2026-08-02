import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'txa_supabase_service.dart';
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
    return user?.isVipCurrentlyActive ?? false;
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
      TXALogger.logError('Products not found: ${response.notFoundIDs}', extraInfo: {'service': 'TXAIAPService', 'action': '_loadProducts'});
    }
    _products = response.productDetails;
    notifyListeners();
  }

  Future<void> buySubscription(ProductDetails product) async {
    if (Platform.isIOS) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        TXAToast.show(
          context,
          TXALanguage.instance.getText('ios_iap_unsupported'),
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

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Handle pending state
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          await _verifyAndActivateVIP(purchaseDetails);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _verifyAndActivateVIP(PurchaseDetails purchase) async {
    final user = TXAAuthService.instance.currentUser;
    if (user == null) return;

    final context = navigatorKey.currentContext;
    final txaLang = TXALanguage.instance;

    // Lấy thông tin tài khoản đăng ký hiện tại (Gmail)
    final googleEmail = FirebaseAuth.instance.currentUser?.email;

    try {
      // 1. Kiểm tra chéo xem giao dịch đã được liên kết với một App UID khác chưa
      final existingUserQuery = await TXASupabaseService.instance.client
          .from('txa_users')
          .select('id, email, vipGoogleEmail')
          .eq('vipPurchaseToken', purchase.purchaseID ?? '')
          .maybeSingle();

      if (existingUserQuery != null && existingUserQuery['id'] != user.id) {
        // Giao dịch đã thuộc về tài khoản app khác
        if (context != null && context.mounted) {
          TXAToast.show(
            context,
            txaLang.getText('restore_wrong_account'),
            icon: Icons.error_outline_rounded,
          );
        }
        return;
      }

      // Tự tính hạn lâm thời (Webhook Edge Function sẽ ghi đè chính xác sau)
      int durationDays = purchase.productID == yearlyProductId ? 365 : 30;
      final expiryDate = DateTime.now().add(Duration(days: durationDays));

      await TXASupabaseService.instance.client.from('txa_users').update({
        'isVipActive': true,
        'vipProductId': purchase.productID,
        'vipPurchaseToken': purchase.purchaseID,
        'vipPurchaseDate': DateTime.now().toIso8601String(),
        'vipExpiryDate': expiryDate.toIso8601String(),
        'vipGoogleEmail': googleEmail,
      }).eq('id', user.id);

      await TXAAuthService.instance.syncUserFromFirestore();

      if (context != null && context.mounted) {
        TXAToast.show(
          context,
          purchase.status == PurchaseStatus.restored
              ? txaLang.getText('purchase_restored_toast')
              : txaLang.getText('purchase_success_toast'),
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      debugPrint('Error updating VIP status: $e');
    }
  }

  /// Quét trạng thái hạn dùng VIP
  Future<void> checkVipExpiry() async {
    final user = TXAAuthService.instance.currentUser;
    if (user == null || !user.isVipActive) return;

    if (user.vipExpiryDate != null) {
      final expiry = DateTime.tryParse(user.vipExpiryDate!);
      if (expiry != null && expiry.isBefore(DateTime.now())) {
        // Gói cước đã hết hạn thực tế
        await TXAAuthService.instance.downgradeToFree();
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          TXAToast.show(
            context,
            TXALanguage.instance.getText('vip_downgraded_toast'),
            icon: Icons.info_outline_rounded,
          );
        }
      }
    }
  }

  /// Hủy gia hạn gói cước
  Future<void> openCancelSubscription() async {
    // Package name của app
    const String packageName = 'com.txavlog.army'; 
    final Uri url = Uri.parse(
      'https://play.google.com/store/account/subscriptions?sku=$monthlyProductId&package=$packageName',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        TXAToast.show(
          context,
          'Could not open Subscriptions page',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
