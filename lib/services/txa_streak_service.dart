import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'txa_feed_service.dart';
import 'txa_language.dart';
import 'txa_format.dart';
import 'txa_auth_service.dart';
import 'txa_iap_service.dart';
import 'txa_logger.dart';

/// Tier màu sắc cho khung Avatar tương ứng với 8 mốc Streak (3, 7, 14, 30, 45, 60, 75, 90 ngày)
class TXAStreakTheme {
  final Color borderColor;
  final Color badgeColor;
  final List<Color> gradientColors;

  const TXAStreakTheme({
    required this.borderColor,
    required this.badgeColor,
    required this.gradientColors,
  });

  // Mốc 3+: Mầm Kiến (Cam ấm)
  static const m3Theme = TXAStreakTheme(
    borderColor: Color(0xFFFF9800),
    badgeColor: Color(0xFFFF5722),
    gradientColors: [Color(0xFFFF9800), Color(0xFFFF5722)],
  );

  // Mốc 7+: Kiến Lính (Đỏ cam)
  static const m7Theme = TXAStreakTheme(
    borderColor: Color(0xFFFF3D00),
    badgeColor: Color(0xFFD50000),
    gradientColors: [Color(0xFFFF9100), Color(0xFFFF1744)],
  );

  // Mốc 14+: Kiến Thợ (Hồng tím)
  static const m14Theme = TXAStreakTheme(
    borderColor: Color(0xFFE91E63),
    badgeColor: Color(0xFFC2185B),
    gradientColors: [Color(0xFFEC407A), Color(0xFFC2185B)],
  );

  // Mốc 30+: Tổ Kiến (Vàng hoàng gia)
  static const m30Theme = TXAStreakTheme(
    borderColor: Color(0xFFFFD700),
    badgeColor: Color(0xFFFF8F00),
    gradientColors: [Color(0xFFFFD700), Color(0xFFFFAB00)],
  );

  // Mốc 45+: Kiến Vàng (Xanh lá tươi)
  static const m45Theme = TXAStreakTheme(
    borderColor: Color(0xFF00E676),
    badgeColor: Color(0xFF00C853),
    gradientColors: [Color(0xFF69F0AE), Color(0xFF00C853)],
  );

  // Mốc 60+: Chiến Sĩ (Tím huyền bí)
  static const m60Theme = TXAStreakTheme(
    borderColor: Color(0xFF9C27B0),
    badgeColor: Color(0xFF7B1FA2),
    gradientColors: [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
  );

  // Mốc 75+: Tướng Kiến (Đỏ lửa)
  static const m75Theme = TXAStreakTheme(
    borderColor: Color(0xFFFF5252),
    badgeColor: Color(0xFFD50000),
    gradientColors: [Color(0xFFFF8A80), Color(0xFFD50000)],
  );

  // Mốc 90+: Nữ Hoàng (Xanh ngọc phát sáng)
  static const m90Theme = TXAStreakTheme(
    borderColor: Color(0xFF00E5FF),
    badgeColor: Color(0xFF00B0FF),
    gradientColors: [Color(0xFF18FFFF), Color(0xFF00B0FF)],
  );

  static const defaultTheme = m3Theme;
}

class TXAStreakService extends ChangeNotifier {
  static final TXAStreakService instance = TXAStreakService._internal();
  TXAStreakService._internal() {
    _loadStreaks();
  }

  /// Map lưu trữ streak theo username/userId -> int (số ngày chuỗi)
  final Map<String, int> _userStreaks = {};

  /// Map lưu trữ mốc thời gian bài đăng cuối cùng (DateTime)
  final Map<String, DateTime> _lastPostDates = {};

  /// Lưu trữ streak trước đó khi bị đứt để hỗ trợ khôi phục
  final Map<String, int> _lastSavedStreaks = {};

  /// Lưu trạng thái lượt khôi phục miễn phí hàng tháng (user -> bool)
  final Map<String, bool> _isFreeMonthlyRestoreUsed = {};

  /// Lưu số lượt khôi phục tích lũy được từ quảng cáo (user -> int)
  final Map<String, int> _restorationCredits = {};

  /// Số ads đã xem hôm nay cho streak restoration (user -> int)
  final Map<String, int> _dailyStreakAdCounts = {};

  /// Ngày reset số ad hàng ngày (user -> String 'YYYY-MM-DD')
  final Map<String, String> _lastAdResetDates = {};

  /// Tháng kiểm tra reset miễn phí (user -> String 'YYYY-MM')
  final Map<String, String> _lastFreeRestoreMonths = {};

  /// Tuần cuối cùng sử dụng lá chắn tự động (user -> String 'YYYY-MM-DD' ngày thứ 2 trong tuần)
  final Map<String, String> _lastShieldUsedWeeks = {};

  /// Ngưỡng tối thiểu để hiển thị Badge Chuỗi (chỉ hiện khi streak >= 3)
  static const int minStreakToShow = 3;

  /// Lấy số ngày chuỗi hiện tại của một user (Tự động tính toán thực tế từ danh sách bài đăng)
  int getStreak(String username) {
    final computed = calculateStreakFromPosts(username);
    final stored = _userStreaks[username] ?? 0;
    final maxStreak = computed > stored ? computed : stored;

    if (maxStreak > stored) {
      _userStreaks[username] = maxStreak;
      _saveStreaks();
    }
    return maxStreak;
  }

  /// Tính toán số ngày chuỗi streak liên tục thực tế từ danh sách bài đăng trong TXAFeedService
  int calculateStreakFromPosts(String username) {
    try {
      final posts = TXAFeedService.instance.posts;
      final userPosts = posts.where((p) => p.senderUsername == username);
      if (userPosts.isEmpty) return _userStreaks[username] ?? 0;

      // Lấy danh sách các ngày logic độc nhất mà user đã đăng bài
      final Set<DateTime> logicDays = {};
      for (var p in userPosts) {
        final dt = DateTime.tryParse(p.createdTime)?.toLocal();
        if (dt != null) {
          logicDays.add(_getLogicDay(dt));
        }
      }

      if (logicDays.isEmpty) return _userStreaks[username] ?? 0;

      final now = DateTime.now();
      final todayLogic = _getLogicDay(now);
      final yesterdayLogic = todayLogic.subtract(const Duration(days: 1));

      // Xác định ngày bắt đầu đếm chuỗi (Hôm nay nếu đã đăng, hoặc Hôm qua nếu chưa đăng hôm nay)
      DateTime currentCheck;
      if (logicDays.contains(todayLogic)) {
        currentCheck = todayLogic;
      } else if (logicDays.contains(yesterdayLogic)) {
        currentCheck = yesterdayLogic;
      } else {
        // Không đăng cả hôm nay lẫn hôm qua -> Đã đứt chuỗi
        return 0;
      }

      int streakCount = 0;
      while (logicDays.contains(currentCheck)) {
        streakCount++;
        currentCheck = currentCheck.subtract(const Duration(days: 1));
      }

      return streakCount;
    } catch (_) {
      return _userStreaks[username] ?? 0;
    }
  }

  /// Kiểm tra user có đủ điều kiện hiển thị Badge Chuỗi hay không (Streak >= 3)
  bool shouldShowStreak(String username) {
    return getStreak(username) >= minStreakToShow;
  }

  /// Lấy Theme màu sắc khung dựa trên số ngày streak (Đổi màu viền theo 8 mốc chuỗi)
  TXAStreakTheme getStreakTheme(String username) {
    return getStreakThemeForCount(getStreak(username));
  }

  /// Lấy Theme màu sắc khung dựa trực tiếp trên số lượng ngày streak cụ thể
  TXAStreakTheme getStreakThemeForCount(int count) {
    if (count >= 90) return TXAStreakTheme.m90Theme;
    if (count >= 75) return TXAStreakTheme.m75Theme;
    if (count >= 60) return TXAStreakTheme.m60Theme;
    if (count >= 45) return TXAStreakTheme.m45Theme;
    if (count >= 30) return TXAStreakTheme.m30Theme;
    if (count >= 14) return TXAStreakTheme.m14Theme;
    if (count >= 7) return TXAStreakTheme.m7Theme;
    if (count >= 3) return TXAStreakTheme.m3Theme;
    return TXAStreakTheme.defaultTheme;
  }

  /// Tính ngày logic theo quy tắc: Ngày mới bắt đầu từ 1h00 sáng hàng ngày (thay vì 0h00 đêm)
  static DateTime _getLogicDay(DateTime dt) {
    // Nếu trước 1h00 sáng (0h00 -> 0h59) thì tính thuộc ngày hôm trước
    final adjusted = dt.hour < 1 ? dt.subtract(const Duration(hours: 1)) : dt;
    return DateTime(adjusted.year, adjusted.month, adjusted.day);
  }

  /// Cập nhật/Ghi nhận bài đăng mới từ user và tính toán lại chuỗi streak
  Future<void> recordNewPost(String username) async {
    final now = DateTime.now();
    final todayLogic = _getLogicDay(now);
    final lastDate = _lastPostDates[username];

    if (lastDate == null) {
      _userStreaks[username] = 1;
    } else {
      final lastLogic = _getLogicDay(lastDate);
      final differenceInDays = todayLogic.difference(lastLogic).inDays;

      if (differenceInDays == 0) {
        // Nếu vừa đăng lại trong cùng ngày, vẫn kiểm tra xem streak thực tế có cao hơn không
        final realStreak = calculateStreakFromPosts(username);
        if (realStreak > (_userStreaks[username] ?? 0)) {
          _userStreaks[username] = realStreak;
        }
      } else if (differenceInDays == 1) {
        // Đăng bài ngày logic tiếp theo -> Tăng streak +1
        final realStreak = calculateStreakFromPosts(username);
        final current = _userStreaks[username] ?? 0;
        _userStreaks[username] = realStreak > (current + 1) ? realStreak : (current + 1);
      } else {
        final realStreak = calculateStreakFromPosts(username);
        _userStreaks[username] = realStreak > 0 ? realStreak : 1;
      }
    }

    _lastPostDates[username] = now;
    await _saveStreaks();
    notifyListeners();
  }

  /// Kiểm tra xem user đã đăng bài trong ngày logic hôm nay chưa
  bool hasPostedToday(String username) {
    final now = DateTime.now();
    final todayLogic = _getLogicDay(now);

    // 1. Kiểm tra danh sách bài đăng thực tế trong TXAFeedService
    try {
      final posts = TXAFeedService.instance.posts;
      final userPosts = posts.where((p) => p.senderUsername == username);
      for (var p in userPosts) {
        final dt = DateTime.tryParse(p.createdTime)?.toLocal();
        if (dt != null && _getLogicDay(dt) == todayLogic) {
          return true;
        }
      }
    } catch (_) {}

    // 2. Kiểm tra mốc ngày đăng bài cuối cùng đã lưu trong _lastPostDates
    final lastPost = _lastPostDates[username];
    if (lastPost == null) return false;
    return _getLogicDay(lastPost) == todayLogic;
  }

  /// Tính thời gian đếm ngược còn lại đến mốc reset 01:00 AM của ngày logic tiếp theo
  Duration getRemainingTimeToReset() {
    final now = DateTime.now();
    final todayOneAM = DateTime(now.year, now.month, now.day, 1, 0, 0);
    final nextReset = now.isBefore(todayOneAM)
        ? todayOneAM
        : todayOneAM.add(const Duration(days: 1));

    final diff = nextReset.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Trả về chuỗi đếm ngược thời gian thực đa ngôn ngữ hiển thị trên Tooltip Avatar
  String getStreakCountdownText(String username) {
    final txaLang = TXALanguage.instance;
    final streakCount = getStreak(username);

    if (hasPostedToday(username)) {
      return txaLang.getText('streak_active_msg').replaceAll('%count%', '$streakCount');
    }

    final diff = getRemainingTimeToReset();
    final h = TXAFormat.formatNumber(diff.inHours);
    final m = TXAFormat.formatNumber(diff.inMinutes % 60);
    final s = TXAFormat.formatNumber(diff.inSeconds % 60);

    final timeStr = diff.inHours >= 1 ? '$h:$m:$s' : '$m:$s';
    return txaLang.getText('streak_countdown').replaceAll('%time%', timeStr);
  }

  /// Kiểm tra và cập nhật đứt chuỗi cho tất cả các user khi mở app
  void checkAndCleanExpiredStreaks() {
    final now = DateTime.now();
    final todayLogic = _getLogicDay(now);
    bool changed = false;

    _lastPostDates.forEach((username, lastDate) {
      final lastLogic = _getLogicDay(lastDate);
      final differenceInDays = todayLogic.difference(lastLogic).inDays;

      // Nếu đã hơn 1 ngày logic chưa đăng bài -> Lưu streak cũ lại làm backup rồi reset
      if (differenceInDays > 1 && (_userStreaks[username] ?? 0) > 0) {
        _lastSavedStreaks[username] = _userStreaks[username] ?? 0;
        _userStreaks[username] = 0;
        changed = true;
      }
    });

    if (changed) {
      _saveStreaks();
      notifyListeners();
    }
  }

  /// Thiết lập cứng streak cho mục đích kiểm thử hoặc nạp từ Firestore
  void setStreakManually(String username, int count, DateTime? lastPostTime) {
    if (count < 0) count = 0;
    _userStreaks[username] = count;
    if (lastPostTime != null) {
      _lastPostDates[username] = lastPostTime;
    }
    _saveStreaks();
    notifyListeners();
  }

  // --- STREAK RESTORATION LOGIC ---

  bool canRestoreStreak(String username) {
    final lastSaved = _lastSavedStreaks[username] ?? 0;
    final current = getStreak(username);
    final postedToday = hasPostedToday(username);

    return lastSaved >= 3 && current == 0 && !postedToday;
  }

  int getLastSavedStreak(String username) {
    return _lastSavedStreaks[username] ?? 0;
  }

  bool isShieldUsedThisWeek(String username) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekKey = '${monday.year}-${monday.month}-${monday.day}';
    return _lastShieldUsedWeeks[username] == weekKey;
  }

  void useShield(String username) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekKey = '${monday.year}-${monday.month}-${monday.day}';
    _lastShieldUsedWeeks[username] = weekKey;
    _saveStreaks();
    notifyListeners();
  }

  bool isFreeMonthlyRestoreUsed(String username) {
    _checkMonthlyRestoreReset(username);
    return _isFreeMonthlyRestoreUsed[username] ?? false;
  }

  int getRestorationCredits(String username) {
    return _restorationCredits[username] ?? 0;
  }

  int getDailyStreakAdCount(String username) {
    _checkDailyAdCountReset(username);
    return _dailyStreakAdCounts[username] ?? 0;
  }

  void _checkDailyAdCountReset(String username) {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month}-${now.day}';
    if (_lastAdResetDates[username] != todayStr) {
      _dailyStreakAdCounts[username] = 0;
      _lastAdResetDates[username] = todayStr;
    }
  }

  void _checkMonthlyRestoreReset(String username) {
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month}';
    if (_lastFreeRestoreMonths[username] != currentMonth) {
      _isFreeMonthlyRestoreUsed[username] = false;
      _lastFreeRestoreMonths[username] = currentMonth;
    }
  }

  void incrementDailyStreakAdCount(String username) {
    _checkDailyAdCountReset(username);
    _dailyStreakAdCounts[username] = (_dailyStreakAdCounts[username] ?? 0) + 1;
    _saveStreaks();
    notifyListeners();
  }

  void incrementRestorationCredits(String username) {
    _restorationCredits[username] = (_restorationCredits[username] ?? 0) + 1;
    _saveStreaks();
    notifyListeners();
  }

  Future<bool> restoreStreak(String username) async {
    if (!canRestoreStreak(username)) return false;

    final isVip = TXAIAPService.instance.isVipActive;
    final isAdmin = TXAAuthService.instance.currentUser?.role == 'admin';
    final hasUnlimited = isVip || isAdmin;

    if (!hasUnlimited) {
      final freeUsed = isFreeMonthlyRestoreUsed(username);
      if (!freeUsed) {
        _isFreeMonthlyRestoreUsed[username] = true;
      } else {
        final credits = getRestorationCredits(username);
        if (credits > 0) {
          _restorationCredits[username] = credits - 1;
        } else {
          return false;
        }
      }
    }

    final saved = _lastSavedStreaks[username] ?? 0;
    _userStreaks[username] = saved;

    // Đặt ngày đăng cuối cùng là 12:00 trưa hôm qua logic
    final now = DateTime.now();
    final yesterdayLogic = _getLogicDay(now).subtract(const Duration(days: 1));
    _lastPostDates[username] = yesterdayLogic.add(const Duration(hours: 12));

    await _saveStreaks();
    notifyListeners();

    // Sync to Firestore
    try {
      final user = TXAAuthService.instance.currentUser;
      if (user != null && user.username == username) {
        await FirebaseFirestore.instance.collection('users').doc(user.id).update({
          'streak': saved,
          'lastPostTime': _lastPostDates[username]!.toIso8601String(),
          'isFreeMonthlyRestoreUsed': _isFreeMonthlyRestoreUsed[username] ?? false,
          'restorationCredits': _restorationCredits[username] ?? 0,
        });
        await TXAAuthService.instance.syncUserFromFirestore();
      }
    } catch (e, stack) {
      TXALogger.logError(e, stackTrace: stack, extraInfo: {'service': 'TXAStreakService', 'action': 'restoreStreak'});
    }

    return true;
  }

  /// Lưu dữ liệu vào SharedPreferences
  Future<void> _saveStreaks() async {
    final prefs = await SharedPreferences.getInstance();
    _userStreaks.forEach((user, streak) {
      prefs.setInt('txa_streak_$user', streak);
    });
    _lastPostDates.forEach((user, date) {
      prefs.setString('txa_streak_date_$user', date.toIso8601String());
    });
    _lastSavedStreaks.forEach((user, streak) {
      prefs.setInt('txa_last_saved_streak_$user', streak);
    });
    _isFreeMonthlyRestoreUsed.forEach((user, used) {
      prefs.setBool('txa_free_restore_used_$user', used);
    });
    _restorationCredits.forEach((user, credits) {
      prefs.setInt('txa_restoration_credits_$user', credits);
    });
    _dailyStreakAdCounts.forEach((user, adCount) {
      prefs.setInt('txa_daily_ad_count_$user', adCount);
    });
    _lastAdResetDates.forEach((user, dateStr) {
      prefs.setString('txa_last_ad_reset_$user', dateStr);
    });
    _lastFreeRestoreMonths.forEach((user, monthStr) {
      prefs.setString('txa_last_free_restore_month_$user', monthStr);
    });
    _lastShieldUsedWeeks.forEach((user, weekStr) {
      prefs.setString('txa_last_shield_used_week_$user', weekStr);
    });
  }

  /// Tải dữ liệu từ SharedPreferences
  Future<void> _loadStreaks() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith('txa_streak_') && !key.startsWith('txa_streak_date_')) {
        final username = key.replaceFirst('txa_streak_', '');
        final streak = prefs.getInt(key) ?? 0;
        _userStreaks[username] = streak;

        final dateStr = prefs.getString('txa_streak_date_$username');
        if (dateStr != null) {
          _lastPostDates[username] = DateTime.tryParse(dateStr) ?? DateTime.now();
        }
      } else if (key.startsWith('txa_last_saved_streak_')) {
        final username = key.replaceFirst('txa_last_saved_streak_', '');
        _lastSavedStreaks[username] = prefs.getInt(key) ?? 0;
      } else if (key.startsWith('txa_free_restore_used_')) {
        final username = key.replaceFirst('txa_free_restore_used_', '');
        _isFreeMonthlyRestoreUsed[username] = prefs.getBool(key) ?? false;
      } else if (key.startsWith('txa_restoration_credits_')) {
        final username = key.replaceFirst('txa_restoration_credits_', '');
        _restorationCredits[username] = prefs.getInt(key) ?? 0;
      } else if (key.startsWith('txa_daily_ad_count_')) {
        final username = key.replaceFirst('txa_daily_ad_count_', '');
        _dailyStreakAdCounts[username] = prefs.getInt(key) ?? 0;
      } else if (key.startsWith('txa_last_ad_reset_')) {
        final username = key.replaceFirst('txa_last_ad_reset_', '');
        _lastAdResetDates[username] = prefs.getString(key) ?? '';
      } else if (key.startsWith('txa_last_free_restore_month_')) {
        final username = key.replaceFirst('txa_last_free_restore_month_', '');
        _lastFreeRestoreMonths[username] = prefs.getString(key) ?? '';
      } else if (key.startsWith('txa_last_shield_used_week_')) {
        final username = key.replaceFirst('txa_last_shield_used_week_', '');
        _lastShieldUsedWeeks[username] = prefs.getString(key) ?? '';
      }
    }
    checkAndCleanExpiredStreaks();
    notifyListeners();
  }

  /// Đồng bộ streak thực từ Firestore cho một user cụ thể
  Future<void> syncStreakFromFirestore(String username) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        final streakVal = data['streak'];
        int streak = 0;
        if (streakVal is num) {
          streak = streakVal.toInt();
        } else if (streakVal is String) {
          streak = int.tryParse(streakVal) ?? 0;
        }

        _userStreaks[username] = streak;

        final lastPostStr = data['lastPostTime'] ?? data['lastPostDate'];
        if (lastPostStr is String) {
          final parsed = DateTime.tryParse(lastPostStr);
          if (parsed != null) _lastPostDates[username] = parsed;
        } else {
          _lastPostDates.remove(username);
        }

        // Đồng bộ thêm các trường khôi phục streak
        if (data.containsKey('lastSavedStreak')) {
          _lastSavedStreaks[username] = (data['lastSavedStreak'] as num).toInt();
        }
        if (data.containsKey('isFreeMonthlyRestoreUsed')) {
          _isFreeMonthlyRestoreUsed[username] = data['isFreeMonthlyRestoreUsed'] == true;
        }
        if (data.containsKey('restorationCredits')) {
          _restorationCredits[username] = (data['restorationCredits'] as num).toInt();
        }

        notifyListeners();

        // Ghi ngược xuống local cache làm fallback offline
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('txa_streak_$username', streak);
        if (_lastPostDates[username] != null) {
          await prefs.setString('txa_streak_date_$username', _lastPostDates[username]!.toIso8601String());
        }
        if (_lastSavedStreaks[username] != null) {
          await prefs.setInt('txa_last_saved_streak_$username', _lastSavedStreaks[username]!);
        }
        await prefs.setBool('txa_free_restore_used_$username', _isFreeMonthlyRestoreUsed[username] ?? false);
        await prefs.setInt('txa_restoration_credits_$username', _restorationCredits[username] ?? 0);
      }
    } catch (e, stack) {
      TXALogger.logError(e, stackTrace: stack, extraInfo: {'service': 'TXAStreakService', 'action': 'syncStreakFromFirestore'});
    }
  }
}
