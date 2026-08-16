import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/txa_admob_service.dart';
import '../services/txa_network_monitor.dart';
import '../services/txa_language.dart';
import '../services/txa_logger.dart';
import '../screens/txa_gold_pass_paywall_screen.dart';

class TXANativeAdFeedCard extends StatefulWidget {
  const TXANativeAdFeedCard({super.key});

  @override
  State<TXANativeAdFeedCard> createState() => _TXANativeAdFeedCardState();
}

class _TXANativeAdFeedCardState extends State<TXANativeAdFeedCard> {
  NativeAd? _nativeAd;
  bool _adLoaded = false;
  bool _adFailed = false;
  double _adLoadProgress = 0.0;
  Timer? _progressTimer;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _progressTimer?.cancel();
    _timeoutTimer?.cancel();
    _nativeAd?.dispose();
    _nativeAd = null;

    if (mounted) {
      setState(() {
        _adLoaded = false;
        _adFailed = false;
        _adLoadProgress = 0.0;
      });
    }

    if (kIsWeb || Platform.isWindows || !TXANetworkMonitor.instance.hasConnection) {
      if (mounted) {
        setState(() {
          _adFailed = true;
        });
      }
      return;
    }

    // Giả lập thanh tiến độ ads chạy từ 0 đến 90% trong lúc đợi AdMob load
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted && !_adLoaded && !_adFailed) {
        setState(() {
          if (_adLoadProgress < 0.9) {
            _adLoadProgress += 0.05;
          }
        });
      }
    });

    // Safety timeout: 6 seconds max waiting for AdMob response
    _timeoutTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && !_adLoaded && !_adFailed) {
        _progressTimer?.cancel();
        _nativeAd?.dispose();
        _nativeAd = null;
        setState(() {
          _adFailed = true;
        });
      }
    });

    _nativeAd = NativeAd(
      adUnitId: TXAAdMobService.instance.nativeAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _progressTimer?.cancel();
          _timeoutTimer?.cancel();
          if (mounted) {
            setState(() {
              _adLoadProgress = 1.0;
              _adLoaded = true;
              _adFailed = false;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          _progressTimer?.cancel();
          _timeoutTimer?.cancel();
          TXALogger.logError(error, extraInfo: {'widget': 'TXANativeAdFeedCard', 'action': 'onAdFailedToLoad'});
          ad.dispose();
          if (mounted) {
            setState(() {
              _nativeAd = null;
              _adLoaded = false;
              _adFailed = true;
            });
          }
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
      _timeoutTimer?.cancel();
      TXALogger.logError(e, stackTrace: stack, extraInfo: {'widget': 'TXANativeAdFeedCard', 'action': '_loadAd'});
      _nativeAd?.dispose();
      _nativeAd = null;
      if (mounted) {
        setState(() {
          _adLoaded = false;
          _adFailed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _timeoutTimer?.cancel();
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;

    // 1. Offline Guard Check - Render TXALanguage notification card
    if (!TXANetworkMonitor.instance.hasConnection) {
      return _buildOfflinePlaceholder();
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
                        : (_adFailed ? _buildErrorPlaceholder() : _buildPremiumPlaceholder()),

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
                          text: txaLang.getText('ad_sponsored_tooltip'),
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
                                txaLang.getText('ad_sponsored_label'),
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

  Widget _buildErrorPlaceholder() {
    final txaLang = TXALanguage.instance;

    return Container(
      color: const Color(0xFF13131A),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.workspace_premium_rounded, color: const Color(0xFFFFD700).withAlpha(120), size: 44),
          const SizedBox(height: 12),
          Text(
            txaLang.getText('ad_failed_title'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            txaLang.getText('ad_failed_desc'),
            style: const TextStyle(color: Colors.white54, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _loadAd,
                icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
                label: Text(
                  txaLang.getText('retry_btn_label'),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TXAGoldPassPaywallScreen()),
                  );
                },
                icon: const Icon(Icons.star_rounded, size: 14, color: Colors.black),
                label: const Text(
                  'Gold Pass 🌟',
                  style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
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
            txaLang.getText('ad_loading_text'),
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

  Widget _buildOfflinePlaceholder() {
    final txaLang = TXALanguage.instance;

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
                color: const Color(0xFF13131A),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.wifi_off_rounded, color: Colors.white70, size: 40),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      txaLang.getText('ad_offline_title'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      txaLang.getText('ad_offline_notice'),
                      style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _loadAd();
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                      label: Text(
                        txaLang.getText('retry_btn_label'),
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
}
