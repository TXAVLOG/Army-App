import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_analytics.dart';
import '../services/txa_iap_service.dart';
import '../widgets/txa_toast.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class TXAGoldPassPaywallScreen extends StatefulWidget {
  const TXAGoldPassPaywallScreen({super.key});

  @override
  State<TXAGoldPassPaywallScreen> createState() => _TXAGoldPassPaywallScreenState();
}

class _TXAGoldPassPaywallScreenState extends State<TXAGoldPassPaywallScreen> {
  bool _isYearlySelected = true;

  @override
  void initState() {
    super.initState();
    TXAAnalytics.logScreenView(screenName: TXAAnalytics.screenGoldPass);
    TXAIAPService.instance.addListener(_onIapChanged);
  }

  void _onIapChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    TXAIAPService.instance.removeListener(_onIapChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final iapService = TXAIAPService.instance;

    // Find products
    ProductDetails? monthlyProduct;
    ProductDetails? yearlyProduct;
    for (var prod in iapService.products) {
      if (prod.id == TXAIAPService.monthlyProductId) {
        monthlyProduct = prod;
      } else if (prod.id == TXAIAPService.yearlyProductId) {
        yearlyProduct = prod;
      }
    }

    final selectedProduct = _isYearlySelected ? yearlyProduct : monthlyProduct;
    final periodSuffix = txaLang.isVietnamese
        ? (_isYearlySelected ? ' / năm' : ' / tháng')
        : (_isYearlySelected ? ' / year' : ' / month');
    final rawDisplay = selectedProduct?.price ?? (_isYearlySelected ? '189.000đ' : '29.000đ');
    final displayPrice = rawDisplay.contains('/') ? rawDisplay : '$rawDisplay$periodSuffix';
    final originalYearlyPrice = _getYearlyOriginalPrice(monthlyProduct);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: iapService.isRestoring
                ? null
                : () async {
                    await iapService.restorePurchases(context);
                  },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iapService.isRestoring) ...[
                  const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD700)),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  txaLang.getText('restore_purchases'),
                  style: TextStyle(
                    color: iapService.isRestoring ? const Color(0xFFFFD700) : Colors.white70,
                    fontSize: 13,
                    fontWeight: iapService.isRestoring ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Mascot or crown header
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                ).createShader(bounds),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 72,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                txaLang.getText('gold_pass_paywall_title'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                txaLang.getText('gold_pass_paywall_subtitle'),
                style: TextStyle(
                  color: TXATheme.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),

              // Toggle Month vs Year
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Monthly Option
                  GestureDetector(
                    onTap: () => setState(() => _isYearlySelected = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: !_isYearlySelected ? const Color(0xFFFFD700) : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: !_isYearlySelected ? const Color(0xFFFFD700) : Colors.white24,
                        ),
                      ),
                      child: Text(
                        txaLang.getText('monthly_plan'),
                        style: TextStyle(
                          color: !_isYearlySelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Yearly Option with floating badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _isYearlySelected = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          decoration: BoxDecoration(
                            color: _isYearlySelected ? const Color(0xFFFFD700) : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _isYearlySelected ? const Color(0xFFFFD700) : Colors.white24,
                            ),
                          ),
                          child: Text(
                            txaLang.getText('yearly_plan'),
                            style: TextStyle(
                              color: _isYearlySelected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // Floating Discount Badge
                      Positioned(
                        top: -12,
                        right: -10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              )
                            ],
                          ),
                          child: Text(
                            txaLang.getText('save_percentage').replaceAll('%count%', '45'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Plan features
              _buildFeatureRow(Icons.block_rounded, txaLang.getText('vip_feature_adfree')),
              _buildFeatureRow(Icons.bolt_rounded, txaLang.getText('vip_feature_unlimited_restore')),
              _buildFeatureRow(Icons.auto_awesome_rounded, txaLang.getText('vip_feature_icons')),
              _buildFeatureRow(Icons.music_note_rounded, txaLang.getText('vip_feature_spotify')),
              _buildFeatureRow(Icons.download_done_rounded, txaLang.getText('vip_feature_watermark')),
              _buildFeatureRow(Icons.security_rounded, txaLang.getText('vip_feature_security')),

              const SizedBox(height: 40),

              // Pricing details & Subscribe button
              if (_isYearlySelected) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      originalYearlyPrice,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.white54,
                        decorationThickness: 2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      displayPrice,
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  txaLang.getText('yearly_discount_hint').replaceAll('%count%', '45'),
                  style: TextStyle(
                    color: const Color(0xFFFFD700).withAlpha(220),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                Text(
                  displayPrice,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    if (selectedProduct != null) {
                      await iapService.buySubscription(selectedProduct, context);
                    } else if (Platform.isIOS) {
                      // Trigger iOS notice
                      await iapService.buySubscription(
                        ProductDetails(
                          id: _isYearlySelected ? TXAIAPService.yearlyProductId : TXAIAPService.monthlyProductId,
                          title: 'Gold Pass',
                          description: 'Premium subscription',
                          price: displayPrice,
                          rawPrice: _isYearlySelected ? 6.99 : 0.99,
                          currencyCode: 'USD',
                        ),
                        context,
                      );
                    } else {
                      TXAToast.show(
                        context,
                        txaLang.getText('iap_unavailable_store_toast'),
                        icon: Icons.info_outline_rounded,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    txaLang.getText('subscribe_now'),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD700), size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getYearlyOriginalPrice(ProductDetails? monthlyProduct) {
    if (monthlyProduct != null && monthlyProduct.rawPrice > 0) {
      final originalRaw = monthlyProduct.rawPrice * 12;
      final code = monthlyProduct.currencyCode.toUpperCase();
      final symbol = monthlyProduct.currencySymbol.isNotEmpty ? monthlyProduct.currencySymbol : '';
      final priceStr = monthlyProduct.price;

      // 1. Zero-decimal currencies (VND, JPY, KRW, IDR, etc.)
      final isZeroDecimal = code == 'JPY' ||
          code == 'KRW' ||
          code == 'VND' ||
          code == 'IDR' ||
          priceStr.contains('đ') ||
          priceStr.contains('₫') ||
          priceStr.contains('¥') ||
          priceStr.contains('￥') ||
          priceStr.contains('₩');

      if (isZeroDecimal) {
        if (code == 'VND' || priceStr.contains('đ') || priceStr.contains('₫')) {
          final formatted = originalRaw.round().toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]}.',
          );
          final curr = symbol.isNotEmpty ? symbol : 'đ';
          return '$formatted$curr';
        } else {
          // JPY (Yên), KRW (Won), etc. (format with commas: 3,600)
          final formatted = originalRaw.round().toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
          if (priceStr.startsWith(symbol) ||
              priceStr.startsWith('¥') ||
              priceStr.startsWith('￥') ||
              priceStr.startsWith('₩')) {
            final s = symbol.isNotEmpty ? symbol : (code == 'JPY' ? '¥' : '₩');
            return '$s$formatted';
          } else {
            final s = symbol.isNotEmpty ? symbol : code;
            return '$formatted $s';
          }
        }
      }

      // 2. Standard decimal currencies (USD, EUR, GBP, AUD, etc.)
      final formattedNum = originalRaw.toStringAsFixed(2);
      if (symbol.isNotEmpty && priceStr.endsWith(symbol)) {
        return '$formattedNum $symbol';
      } else if (symbol.isNotEmpty) {
        return '$symbol$formattedNum';
      } else if (code.isNotEmpty) {
        return '$code $formattedNum';
      } else {
        return '\$$formattedNum';
      }
    }
    return '348.000đ';
  }
}