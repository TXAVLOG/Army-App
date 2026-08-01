import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'txa_language.dart';

class TXAFormat extends ChangeNotifier {
  static final TXAFormat instance = TXAFormat._internal();
  TXAFormat._internal();

  static const String _keyAspectRatio = 'txa_format_aspect_ratio';
  static const String _keyShowTimestamp = 'txa_format_show_timestamp';

  bool _showTimestamp = true;

  String get aspectRatio => '1:1';
  bool get showTimestamp => _showTimestamp;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _showTimestamp = prefs.getBool(_keyShowTimestamp) ?? true;
    notifyListeners();
  }

  Future<void> setAspectRatio(String ratio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAspectRatio, '1:1');
    notifyListeners();
  }

  Future<void> setShowTimestamp(bool value) async {
    _showTimestamp = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowTimestamp, value);
    notifyListeners();
  }

  // 1. Format File Size (B, KB, MB, GB, TB)
  static String formatSize(int bytes) {
    if (bytes < 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes < 1024 * 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024 * 1024 * 1024)).toStringAsFixed(1)} TB';
  }

  // 2. Format Date Time (H:i:s d/MM/yyyy)
  static String formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();

    return '$hour:$minute:$second $day/$month/$year';
  }

  // 3. Format Relative Activity Time (Hoạt động xx phút trước, giờ trước, ngày trước, Ngoại tuyến)
  static String formatActivity(DateTime? lastActive, {bool isOnline = false}) {
    final txaLang = TXALanguage.instance;

    if (isOnline) {
      return txaLang.getText('online');
    }

    if (lastActive == null) {
      return txaLang.getText('offline');
    }

    final now = DateTime.now();
    final difference = now.difference(lastActive);

    if (difference.isNegative || difference.inSeconds < 60) {
      return txaLang.getText('just_now');
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${txaLang.getText('mins_ago')}';
    }

    if (difference.inHours < 24) {
      final hours = difference.inHours;
      if (hours < 1) {
        return '${difference.inMinutes} ${txaLang.getText('mins_ago')}';
      }
      return '$hours ${txaLang.getText('hours_ago')}';
    }

    final days = difference.inDays;
    if (days < 1) {
      return '${difference.inHours} ${txaLang.getText('hours_ago')}';
    }

    if (difference.inDays < 30) {
      return '$days ${txaLang.getText('days_ago')}';
    }

    return txaLang.getText('offline');
  }

  // 4. Format Post Timestamp (Tự động chuyển thành: Vừa xong -> xx phút trước -> xx giờ trước -> HH:mm dd/MM/yyyy)
  static String formatPostTime(dynamic input) {
    if (input == null) return '';
    final txaLang = TXALanguage.instance;

    DateTime? dt;
    if (input is DateTime) {
      dt = input.toLocal();
    } else if (input is String) {
      if (input.isEmpty) return '';
      dt = DateTime.tryParse(input)?.toLocal();
      if (dt == null) {
        if (input.contains('0 ngày trước') || input.contains('0 days ago')) {
          return txaLang.getText('just_now');
        }
        return input;
      }
    }

    if (dt == null) return input.toString();

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.isNegative || diff.inSeconds < 60) {
      return txaLang.getText('just_now');
    }

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} ${txaLang.getText('mins_ago')}';
    }

    if (diff.inHours < 24) {
      final hours = diff.inHours;
      if (hours < 1) {
        return '${diff.inMinutes} ${txaLang.getText('mins_ago')}';
      }
      return '$hours ${txaLang.getText('hours_ago')}';
    }

    final days = diff.inDays;
    if (days < 1) {
      return '${diff.inHours} ${txaLang.getText('hours_ago')}';
    }

    if (days < 7) {
      return '$days ${txaLang.getText('days_ago')}';
    }

    final hour = formatNumber(dt.hour);
    final minute = formatNumber(dt.minute);
    final day = formatNumber(dt.day);
    final month = formatNumber(dt.month);
    final year = dt.year;

    return '$hour:$minute $day/$month/$year';
  }

  // 4. Format number to 2 digits (e.g. 02, 15)
  static String formatNumber(int val) {
    return val.toString().padLeft(2, '0');
  }
}
