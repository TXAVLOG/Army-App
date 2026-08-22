import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'txa_logger.dart';
import 'txa_supabase_service.dart';
import 'txa_auth_service.dart';

class TXARatingService extends ChangeNotifier {
  static final TXARatingService instance = TXARatingService._internal();
  TXARatingService._internal();

  static const String _keySessionCount = 'txa_session_count';
  static const String _keyLastSessionTime = 'txa_last_session_time';
  static const String _keyHasRated = 'txa_has_rated_app';
  static const String _keyDeclinedDate = 'txa_rating_declined_date';
  static const String _keyPromptCount = 'txa_rating_prompt_count';

  static const String playStoreMarketUri = 'market://details?id=vn.army.txa';
  static const String playStoreWebUri = 'https://play.google.com/store/apps/details?id=vn.army.txa';
  static const String appStoreWebUri = 'https://apps.apple.com/app/id6742512999';

  int _sessionCount = 0;
  int get sessionCount => _sessionCount;

  bool _hasRated = false;
  bool get hasRated => _hasRated;

  DateTime? _declinedDate;
  int _promptCount = 0;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _sessionCount = prefs.getInt(_keySessionCount) ?? 0;
      _hasRated = prefs.getBool(_keyHasRated) ?? false;
      _promptCount = prefs.getInt(_keyPromptCount) ?? 0;

      final declinedStr = prefs.getString(_keyDeclinedDate);
      if (declinedStr != null && declinedStr.isNotEmpty) {
        _declinedDate = DateTime.tryParse(declinedStr);
      }

      final lastSessionStr = prefs.getString(_keyLastSessionTime);
      final now = DateTime.now();

      bool isNewSession = true;
      if (lastSessionStr != null && lastSessionStr.isNotEmpty) {
        final lastTime = DateTime.tryParse(lastSessionStr);
        if (lastTime != null && now.difference(lastTime).inMinutes < 15) {
          isNewSession = false;
        }
      }

      if (isNewSession) {
        _sessionCount += 1;
        await prefs.setInt(_keySessionCount, _sessionCount);
        await prefs.setString(_keyLastSessionTime, now.toIso8601String());
        TXALogger.logInfo('Bắt đầu phiên sử dụng mới #$_sessionCount', extraInfo: {
          'service': 'TXARatingService',
          'sessionCount': _sessionCount,
        });
      }

      _initialized = true;
      notifyListeners();
    } catch (e, stack) {
      TXALogger.logError('Lỗi khởi tạo TXARatingService: $e', stackTrace: stack);
    }
  }

  bool shouldPromptRating() {
    if (_hasRated) return false;
    if (_promptCount >= 3) return false;
    if (_sessionCount < 3) return false;

    if (_declinedDate != null) {
      final daysSinceDeclined = DateTime.now().difference(_declinedDate!).inDays;
      if (daysSinceDeclined < 4) return false;
    }

    return true;
  }

  void incrementPromptCount() {
    _promptCount += 1;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(_keyPromptCount, _promptCount);
    });
  }

  Future<bool> openStoreListing() async {
    try {
      if (Platform.isAndroid) {
        final marketUri = Uri.parse(playStoreMarketUri);
        if (await canLaunchUrl(marketUri)) {
          await launchUrl(marketUri, mode: LaunchMode.externalApplication);
          await recordRated();
          return true;
        }

        final webUri = Uri.parse(playStoreWebUri);
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        await recordRated();
        return true;
      } else if (Platform.isIOS) {
        final appStoreUri = Uri.parse(appStoreWebUri);
        await launchUrl(appStoreUri, mode: LaunchMode.externalApplication);
        await recordRated();
        return true;
      } else {
        final webUri = Uri.parse(playStoreWebUri);
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        await recordRated();
        return true;
      }
    } catch (e, stack) {
      TXALogger.logError('Lỗi mở Store rating: $e', stackTrace: stack);
      return false;
    }
  }

  Future<void> recordRated() async {
    _hasRated = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasRated, true);
    TXALogger.logApp('Người dùng đã hoàn thành đánh giá Army 5 sao');
  }

  Future<void> recordRemindLater() async {
    _declinedDate = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeclinedDate, _declinedDate!.toIso8601String());
    TXALogger.logApp('Người dùng chọn Nhắc tôi sau khi đánh giá Army');
  }

  Future<void> recordNoThanks() async {
    _hasRated = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasRated, true);
    TXALogger.logApp('Người dùng chọn Không, cảm ơn khi hỏi đánh giá');
  }

  Future<bool> sendInternalFeedback({required int stars, required String feedback}) async {
    try {
      final user = TXAAuthService.instance.currentUser;
      final payload = {
        'user_id': user?.id ?? 'anonymous',
        'username': user?.username ?? 'anonymous',
        'stars': stars,
        'feedback': feedback.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'platform': Platform.operatingSystem,
      };

      try {
        await TXASupabaseService.instance.client.from('txa_feedback').insert(payload);
      } catch (_) {
        // Fallback local logging
      }

      await recordRated();
      TXALogger.logApp('Đã gửi góp ý nội bộ ($stars sao): $feedback');
      return true;
    } catch (e, stack) {
      TXALogger.logError('Lỗi gửi góp ý nội bộ: $e', stackTrace: stack);
      return false;
    }
  }
}
