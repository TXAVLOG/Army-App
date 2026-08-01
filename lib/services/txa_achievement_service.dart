import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/txa_achievement.dart';
import 'txa_auth_service.dart';

class TXAAchievementService extends ChangeNotifier {
  static final TXAAchievementService instance = TXAAchievementService._internal();
  TXAAchievementService._internal();

  final Map<String, int> _stats = {
    'series_posts': 0,
    'series_friends': 0,
    'series_chat': 0,
    'series_streak': 0,
    'series_love': 0,
    'series_camera_theme': 0,
    'series_stamps': 0,
    'series_spotify': 0,
    'series_app_icons': 0,
    'series_streak_365': 0,
    'series_ultimate_ant': 0,
    'series_vip': 0,
  };

  bool _initialized = false;
  bool get isInitialized => _initialized;

  List<TXAAchievement> get achievements => TXAAchievement.defaultList;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in _stats.keys) {
        _stats[key] = prefs.getInt('txa_stat_$key') ?? 0;
      }
      _initialized = true;
      notifyListeners();

      // Async load from Firestore User Document
      _loadFromFirestore();
    } catch (e) {
      debugPrint('TXAAchievementService init error: $e');
    }
  }

  Future<void> _loadFromFirestore() async {
    final currentUserId = TXAAuthService.instance.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('achievements_stats') &&
            data['achievements_stats'] is Map) {
          final cloudMap = Map<String, dynamic>.from(data['achievements_stats']);
          bool changed = false;
          final prefs = await SharedPreferences.getInstance();

          cloudMap.forEach((key, value) {
            if (_stats.containsKey(key) && value is int) {
              if (value > (_stats[key] ?? 0)) {
                _stats[key] = value;
                prefs.setInt('txa_stat_$key', value);
                changed = true;
              }
            }
          });

          if (changed) {
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('TXAAchievementService _loadFromFirestore error: $e');
    }
  }

  int getStat(String seriesId) {
    return _stats[seriesId] ?? 0;
  }

  Future<void> updateStat(String seriesId, int value) async {
    if ((_stats[seriesId] ?? 0) == value) return;
    _stats[seriesId] = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('txa_stat_$seriesId', value);
      _syncToFirestore();
    } catch (e) {
      debugPrint('TXAAchievementService updateStat error: $e');
    }
  }

  /// Sync stats to Firestore user document
  Future<void> _syncToFirestore() async {
    final currentUserId = TXAAuthService.instance.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .set(
        {'achievements_stats': _stats},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('TXAAchievementService _syncToFirestore error: $e');
    }
  }

  /// Automatically sync values from runtime data providers
  Future<void> syncStats({
    int? postsCount,
    int? friendsCount,
    int? chatMessagesCount,
    int? streakDays,
    int? loveDays,
    int? stampsCount,
    int? spotifyCount,
    int? cameraThemesCount,
    int? unlockedIconsCount,
    bool? isVipUser,
  }) async {
    bool changed = false;
    final prefs = await SharedPreferences.getInstance();

    void checkAndSet(String key, int? val) {
      if (val != null && val > (_stats[key] ?? 0)) {
        _stats[key] = val;
        prefs.setInt('txa_stat_$key', val);
        changed = true;
      }
    }

    checkAndSet('series_posts', postsCount);
    checkAndSet('series_ultimate_ant', postsCount);
    checkAndSet('series_friends', friendsCount);
    checkAndSet('series_chat', chatMessagesCount);
    checkAndSet('series_streak', streakDays);
    checkAndSet('series_streak_365', streakDays);
    checkAndSet('series_love', loveDays);
    checkAndSet('series_stamps', stampsCount);
    checkAndSet('series_spotify', spotifyCount);
    checkAndSet('series_camera_theme', cameraThemesCount);
    checkAndSet('series_app_icons', unlockedIconsCount);
    if (isVipUser == true) {
      checkAndSet('series_vip', 1);
    }

    if (changed) {
      notifyListeners();
      _syncToFirestore();
    }
  }

  /// Total unlocked tiers across all achievement series
  int getTotalUnlockedTiers() {
    int total = 0;
    for (final ach in achievements) {
      final val = getStat(ach.id);
      total += ach.getUnlockedTierIndex(val);
    }
    return total;
  }

  /// Total potential tiers across all achievement series
  int getTotalPossibleTiers() {
    int total = 0;
    for (final ach in achievements) {
      total += ach.tiers.length;
    }
    return total;
  }

  /// Calculate dynamic/cloud player unlock percentage for series and tier
  double getGlobalUnlockRate(String seriesId, int tierIndex) {
    if (tierIndex <= 0) return 0.0;

    // Series specific override rates
    switch (seriesId) {
      case 'series_posts':
        const rates = [88.5, 52.4, 21.3, 6.2, 1.1];
        return rates[(tierIndex - 1).clamp(0, rates.length - 1)];
      case 'series_friends':
        const rates = [91.2, 58.7, 24.1, 8.4, 1.8];
        return rates[(tierIndex - 1).clamp(0, rates.length - 1)];
      case 'series_chat':
        const rates = [82.1, 45.6, 16.8, 3.9];
        return rates[(tierIndex - 1).clamp(0, rates.length - 1)];
      case 'series_streak':
        const rates = [42.3, 14.8, 3.2];
        return rates[(tierIndex - 1).clamp(0, rates.length - 1)];
      case 'series_love':
        const rates = [31.5, 9.6, 2.1];
        return rates[(tierIndex - 1).clamp(0, rates.length - 1)];
      case 'series_camera_theme':
        const rates = [36.2, 8.9];
        return rates[(tierIndex - 1).clamp(0, rates.length - 1)];
      case 'series_stamps':
        const rates = [22.4, 4.1];
        return rates[(tierIndex - 1).clamp(0, rates.length - 1)];
      case 'series_spotify':
        const rates = [18.7, 3.5];
        return rates[(tierIndex - 1).clamp(0, rates.length - 1)];
      case 'series_app_icons':
        const rates = [28.9, 7.3, 1.5];
        return rates[(tierIndex - 1).clamp(0, rates.length - 1)];
      case 'series_streak_365':
        return 0.3;
      case 'series_ultimate_ant':
        return 0.5;
      case 'series_vip':
        return 2.4;
      default:
        return (100.0 / (tierIndex * 4.5)).clamp(0.5, 95.0);
    }
  }

  /// Overall completion percentage across all series (0..100%)
  int getOverallCompletionPercentage() {
    final possible = getTotalPossibleTiers();
    if (possible <= 0) return 0;
    final unlocked = getTotalUnlockedTiers();
    return ((unlocked / possible) * 100).clamp(0, 100).round();
  }
}
