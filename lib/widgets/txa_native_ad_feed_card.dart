import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/txa_admob_service.dart';
import '../services/txa_network_monitor.dart';
import '../services/txa_language.dart';
import '../services/txa_logger.dart';

class TXANativeAdFeedCard extends StatefulWidget {
  const TXANativeAdFeedCard({super.key});

  @override
  State<TXANativeAdFeedCard> createState() => _TXANativeAdFeedCardState();
}

class _TXANativeAdFeedCardState extends State<TXANativeAdFeedCard> {
  NativeAd? _nativeAd;
  bool _adLoaded = false;
  double _adLoadProgress = 0.0;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (kIsWeb || Platform.isWindows || !TXANetworkMonitor.instance.hasConnection) {
      return;
    }

    // Giả lập thanh tiến độ ads chạy từ 0 đến 90% trong lúc đợi AdMob load
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          if (_adLoadProgress < 0.9) {
            _adLoadProgress += 0.05;
          }
        });
      }
    });

    _nativeAd = NativeAd(
      adUnitId: TXAAdMobService.instance.nativeAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _progressTimer?.cancel();
          if (mounted) {
            setState(() {
              _adLoadProgress = 1.0;
              _adLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          _progressTimer?.cancel();
          TXALogger.logError(error, extraInfo: {'widget': 'TXANativeAdFeedCard', 'action': 'onAdFailedToLoad'});
          ad.dispose();
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.transparent,
      ),
    );
    try {
      _nativeAd!.load();
    } catch (e, stack) {
      _progressTimer?.cancel();
      TXALogger.logError(e, stackTrace: stack, extraInfo: {'widget': 'TXANativeAdFeedCard', 'action': '_loadAd'});
      _nativeAd?.dispose();
      _nativeAd = null;
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;

    // 1. Offline Guard Check
    if (!TXANetworkMonitor.instance.hasConnection) {
      return const SizedBox.shrink();
    }

    // On Windows/Web, hide ads completely
    final isDesktopOrWeb = kIsWeb || Platform.isWindows;
    if (isDesktopOrWeb) {
      return const SizedBox.shrink(); 
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 350,
          maxHeight: MediaQuery.of(context).size.height * 0.52,
        ),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24),
                  border: Border.all(color: Colors.white10),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Căn giữa toàn bộ Native Ad Widget trong khung hình
                    _adLoaded && _nativeAd != null
                        ? Center(
                            child: SizedBox(
                              height: 320, // Kích thước chuẩn cho Medium template
                              child: AdWidget(ad: _nativeAd!),
                            ),
                          )
                        : _buildPremiumPlaceholder(),

                    // Sponsored Label and Tooltip at Bottom Left
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: Tooltip(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16161A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        richMessage: TextSpan(
                          text: txaLang.currentLanguage == 'vi'
                              ? "Quảng cáo này giúp duy trì ứng dụng Army miễn phí cho tất cả mọi người. Đăng ký Army Gold Pass 🌟 để ẩn toàn bộ quảng cáo."
                              : "This ad helps keep Army free for everyone. Subscribe to Army Gold Pass 🌟 to remove all ads.",
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(180),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                txaLang.currentLanguage == 'vi' ? 'ⓘ Được tài trợ' : 'ⓘ Sponsored',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumPlaceholder() {
    final txaLang = TXALanguage.instance;
    return Container(
      color: const Color(0xFF13131A),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.workspace_premium_rounded, color: const Color(0xFFFFD700).withAlpha(200), size: 48),
          const SizedBox(height: 16),
          Text(
            txaLang.currentLanguage == 'vi' ? 'Đang tải quảng cáo tài trợ...' : 'Loading sponsored content...',
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 16),
          // Thanh tiến độ ads phong cách AdMob
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 4,
                child: LinearProgressIndicator(
                  value: _adLoadProgress,
                  backgroundColor: Colors.white12,
                  color: const Color(0xFFFFD700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
