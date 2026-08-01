import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'txa_config.dart';
import 'txa_logger.dart';

class TXAAdMobService extends ChangeNotifier {
  static final TXAAdMobService instance = TXAAdMobService._internal();
  TXAAdMobService._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;

  String get rewardedAdUnitId {
    if (kDebugMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/5224354917'; // Test Android Rewarded Ad ID
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/1712485313'; // Test iOS Rewarded Ad ID
      }
    }
    return Platform.isAndroid ? TXAConfig.admobAndroidRewardedAdUnit : (Platform.isIOS ? TXAConfig.admobIosRewardedAdUnit : '');
  }

  String get nativeAdUnitId {
    if (kDebugMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/2247696110'; // Test Android Native Ad ID
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/3986624511'; // Test iOS Native Ad ID
      }
    }
    return Platform.isAndroid ? TXAConfig.admobAndroidNativeAdUnit : (Platform.isIOS ? TXAConfig.admobIosNativeAdUnit : '');
  }

  Future<void> init() async {
    if (kIsWeb || Platform.isWindows) {
      TXALogger.logInfo('AdMob not supported or disabled on this platform.', extraInfo: {'service': 'TXAAdMobService'});
      return;
    }
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      TXALogger.logInfo('AdMob initialized successfully.', extraInfo: {'service': 'TXAAdMobService'});
      loadRewardedAd();
    } catch (e, stack) {
      TXALogger.logError(e, stackTrace: stack, extraInfo: {'service': 'TXAAdMobService', 'action': 'init'});
    }
  }

  void loadRewardedAd() {
    if (kIsWeb || Platform.isWindows || !_initialized || _isRewardedAdLoading) return;
    _isRewardedAdLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
          TXALogger.logInfo('Rewarded ad loaded.', extraInfo: {'service': 'TXAAdMobService'});
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedAdLoading = false;
          TXALogger.logError(error, extraInfo: {'service': 'TXAAdMobService', 'action': 'loadRewardedAd'});
        },
      ),
    );
  }

  void showRewardedAd({
    required Function(RewardItem reward) onUserEarnedReward,
    required VoidCallback onAdDismissed,
    required Function(String error) onAdFailedToShow,
  }) {
    if (kIsWeb || Platform.isWindows) {
      // Direct bypass/reward for non-mobile platforms
      onUserEarnedReward(RewardItem(1, 'streak_credit'));
      onAdDismissed();
      return;
    }

    if (_rewardedAd == null) {
      onAdFailedToShow('No ad loaded. Loading new ad.');
      loadRewardedAd();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdDismissed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdFailedToShow(error.message);
      },
    );

    _rewardedAd!.show(onUserEarnedReward: (ad, reward) => onUserEarnedReward(reward));
  }
}
